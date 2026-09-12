# Codex 固有設定

**最初に `~/.agents/AGENTS.md` を読み、記載の全ルールに従うこと。**
このファイル単体では不完全であり、共通ルール（基本ルール・エラー修正ルール・APIキー取り扱い・
Git運用・Git author設定・スキル統合運用ルール）は正本側にある。

## オーバーエンジニアリングを避ける
現在の要件を確実に満たす最も簡潔な実装を選ぶ。既存設計・依存を活用し、現実的な境界条件を守り、要求外の機能・抽象化・設定を増やさない。

## PR Review Worktrees
- Do not reuse old review worktrees by default.
- Before reviewing a PR, run a fresh fetch/prune and create a fresh temporary worktree from the latest target state: latest `origin/main` plus the PR's latest head or merge ref.
- Verify the worktree HEAD matches the intended PR/ref before reviewing.
- Prefer temporary locations such as `C:\tmp` for review worktrees, and clean them up after the review.
- Before removing any worktree, verify the exact path, worktree registration, branch/detached state, `git status`, and meaningful `git diff`.
- Remove worktrees with `git worktree remove <path>`, not by deleting folders directly.
- Do not remove feature/development worktrees unless the user explicitly asks and they are confirmed clean and no longer needed.

## Named subagent routing

- サブエージェントは、ユーザーが委譲を求めた場合、選択中のSkillが委譲を要求する場合、または独立実行が品質・速度を明確に改善する場合だけ使う。小さな単純作業で機械的に起動しない。
- 読み取り専用のコードベース調査、影響分析、依存経路追跡は、カスタムAgent `researcher` を名前指定して起動する。
- 承認済み仕様に基づく実装は、カスタムAgent `coding` を名前指定して起動する。agent-team中の担当は同スキルの事前定義を優先する。
- 計画、差分、commit、PRの独立レビューは、新しいカスタムAgent `reviewer` を名前指定して起動する。agent-team中は同スキルのレビュー経路（expressの親レビューを含む）を優先する。
- `task_name`、表示ラベル、nicknameだけでAgentを選んだことにしない。利用可能な起動インターフェースでcustom agent type/nameを指定する。
- `default`、`worker`、`explorer` を名前付きカスタムAgentの代替として黙って使わない。代替した場合は親の最終報告で明示する。
- 親オーケストレーターは、スコープ、設計判断、Agentへの入力、結果集約、検証、commit、push、PR、mergeを管理する。
- 子Agentには必要最小限の文脈を渡し、原則として会話履歴を丸ごと継承させない。
- 子Agentから孫Agentを起動させない。

## Claude Code subscription bridge

CodexからClaude Codeを呼ぶすべてのタスク・スキル・臨時作業に、次を適用する。

- `claude`、`claude.exe`、`C:\Users\iueda\.local\bin\claude.exe`を直接実行しない。
- Claude Codeの呼び出しは、必ず次のゲートウェイだけを使用する。
  - 確認: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\iueda\.codex\bin\cc-subscription-gateway.ps1 check`
  - レビュー: 同ゲートウェイを `reviewer <absolute-prompt-file>` で呼ぶ。
  - 実装: 同ゲートウェイを `coding-agent <absolute-prompt-file>` で呼ぶ。
- プロンプト本文はUTF-8の一時ファイルへ書き、ゲートウェイ呼び出しとは別のshell tool callにする。ゲートウェイ呼び出しのtool callには、`cd`、ファイル作成、削除、git、パイプ、リダイレクト等を混在させない。
- 作業ディレクトリはCodexのtool call側のcwd/workdirでリポジトリルートに設定する。
- ゲートウェイ実行後、一時プロンプトファイルを別のtool callで削除する。
- `--bare`、`ANTHROPIC_API_KEY`、`ANTHROPIC_AUTH_TOKEN`、Claude Console認証へフォールバックしない。
- ゲートウェイが失敗した場合、直接`claude`へ迂回せず、生のエラーを報告する。
- `.env`、秘密鍵、アクセストークン、パスワード、本番データ、不要な個人情報はClaude Codeへ送信しない。

このルールはAutodev以外のClaude Code呼び出しにも適用する。

### Linux / Codex クラウド

[確認 2026-09-12] 通常タスクと独立した次タスクで、Setup Secret → 0600ファイル → Claude子プロセスのOAuth認証による `OK` 応答を確認した（キャッシュ無効）。Linuxでは次の経路を上記Windows専用ゲートウェイの代わりに使う。Windowsの経路・規律は変更しない。`claude-code-subscription` スキルのWindows専用パスにも、このLinux限定の例外を適用する。

- 環境のSetup scriptに `cloud/codex-setup.sh`、Maintenance scriptに `cloud/codex-maintenance.sh` の内容を貼る。
- Secret `CC_SUBSCRIPTION_TEST_TOKEN` の値は**人間が登録する**。取得は人間の端末で `claude setup-token` を実行する。値を会話・コード・通常の環境変数設定へ貼らない。
- 認証ファイルは `/root/.config/claude-subscription/oauth-token`。内容の表示・プロンプトへの挿入は禁止。次のPython処理の内部だけで読み、子プロセスへ渡す。
- 以下は疎通確認用の実測済み呼び出し。任意のレビュー・実装、ツール有効化、長時間実行は未検証で、この例の成功をそのまま適用しない。
- APIキー、Console認証、`--bare`、別の接続先へのフォールバックは禁止。失敗時は終了コードと固定メッセージだけを報告し、認証情報を含み得る生の出力を表示しない。

```bash
python3 - <<'PY'
import json, os, re, shutil, subprocess, tempfile
from pathlib import Path

try:
    token_path = Path('/root/.config/claude-subscription/oauth-token')
    if not token_path.is_file() or token_path.is_symlink():
        raise ValueError('Invalid authentication file')
    if token_path.stat().st_mode & 0o777 != 0o600:
        raise ValueError('Invalid authentication file mode')
    if token_path.parent.is_symlink() or token_path.parent.stat().st_mode & 0o777 != 0o700:
        raise ValueError('Invalid authentication directory')
    token = token_path.read_text()
    if not token.startswith('sk-ant-oat01-') or re.search(r'\s', token):
        raise ValueError('Invalid authentication token')
    allowed = {'PATH', 'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'NO_PROXY',
               'http_proxy', 'https_proxy', 'all_proxy', 'no_proxy',
               'SSL_CERT_FILE', 'SSL_CERT_DIR', 'NODE_EXTRA_CA_CERTS', 'LANG'}
    with tempfile.TemporaryDirectory(dir='/root') as home:
        env = {k: os.environ[k] for k in allowed if k in os.environ}
        env.update(HOME=home, CLAUDE_CONFIG_DIR=home,
                   CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1',
                   ENABLE_CLAUDEAI_MCP_SERVERS='false',
                   CLAUDE_CODE_OAUTH_TOKEN=token)
        cli = shutil.which('claude')
        if not cli:
            raise ValueError('Claude CLI unavailable')
        run = subprocess.run(
            [cli, '-p', 'Reply with exactly OK', '--tools', '', '--max-turns', '1',
             '--no-session-persistence', '--setting-sources', '',
             '--strict-mcp-config', '--mcp-config', '{"mcpServers":{}}'],
            cwd=home, env=env, stdin=subprocess.DEVNULL, capture_output=True,
            text=True, timeout=90)
    ok = run.returncode == 0 and run.stdout.strip() == 'OK'
    print(json.dumps({'exit_code': run.returncode, 'ok_exact': ok}))
    raise SystemExit(0 if ok else 1)
except Exception:
    print('CLAUDE_SUBSCRIPTION_CHECK_FAILED')
    raise SystemExit(1)
PY
```

- 同一タスク中に再利用する認証ファイルは呼び出しごとに削除せず、タスク終了時に削除する。キャッシュを有効にした場合、セットアップ時の認証ファイルが最大12時間のスナップショットに残り得る。タスク内での削除はキャッシュの失効操作ではない。
- 認証を撤去するときはSecretを削除し、Setup / Maintenanceの認証設定を外して環境を保存する。Secret変更でキャッシュが無効になる。発行元トークンの失効とは別の操作である。
- キャッシュ再開時の配置・認証ファイル確認はMaintenanceに任せる。認証ファイルが無い場合は人間がSecretを登録してセットアップを再実行する。12時間のキャッシュ保持と実際のレビュー・実装のE2Eは未実測。

## Git運用

Git のブランチ・PR・マージ・worktree を触る前に、git-ops スキルを読む
（正本 `~/.agents/skills/git-ops/SKILL.md` ＋ Codex固有 `~/.codex/skills/git-ops/SKILL.md`）。
操作の可否は実行先の権限による。承認付き実行・GitHub操作・後片付けの正式な経路はCodexラッパーに従い、制限を迂回しない。
