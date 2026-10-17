---
name: claude-code-subscription
description: "CodexからClaude Code reviewer/coding-agentを呼ぶ際に、Claude setup-tokenのサブスクリプション認証だけを使い、APIキー課金へのフォールバックを防ぐ。Claude Code、CCレビュー、CC実装、Codex→CC連携を依頼されたときに使う。"
---

# Claude Code subscription bridge

CodexからClaude Codeを呼ぶすべてのタスク・スキル・臨時作業に適用する。認証・起動コマンド・禁止事項・OS別の失敗報告は本書を正本とする。

## 共通規律

- `claude`、`claude.exe`、実体の絶対パスを直接実行しない。実行OSに対応する本書の経路だけを使う。
- `--bare`を使わない。`ANTHROPIC_API_KEY`や`ANTHROPIC_AUTH_TOKEN`をゲートウェイへ渡さず、APIキー課金・Claude Console認証・別の接続先へフォールバックしない。
- ゲートウェイ失敗時に直接CLI、curl、Node.js、Python等でAnthropicへ迂回しない。
- `.env`、秘密鍵、アクセストークン、パスワード、本番データ、不要な個人情報はClaude Codeへ送信しない。秘密情報の出力・プロンプトへの混入を禁止する。
- 利用不能時の継続・停止、独立レビューの要否は利用側の規則に従う。CC必須などの停止条件を本書で解除しない。

### 必須フロー

1. 作業ディレクトリはtool call側のcwd/workdirで対象リポジトリのルートにする。
2. 別のtool callで、プロンプト本文をリポジトリ内の一時UTF-8（BOMなし）ファイルへ書く。例: `.codex-cc-prompt-{guid}.txt`。
3. 本書のOS別コマンドだけを、単独のshell tool callで実行する。`cd`、`Set-Location`、`Get-Content`、git、ファイル生成・削除、パイプ、リダイレクトを同じtool callへ混在させない。
4. 結果取得後、一時プロンプトファイルを別のtool callで削除する。失敗時の報告と認証ファイルの扱いはOS別規則に従う。

## Windows

### 固定パス

```text
コアラッパー:
C:\Users\iueda\.codex\bin\invoke-claude-subscription.ps1

ゲートウェイ:
C:\Users\iueda\.codex\bin\cc-subscription-gateway.ps1

暗号化トークン:
C:\Users\iueda\.codex\secrets\claude-code-oauth.dpapi

Claude Code実体:
C:\Users\iueda\.local\bin\claude.exe
```

Claude Code実体はゲートウェイ内部からだけ使用する。Codexは直接実行しない。

### 呼び出し

疎通・認証確認:

```powershell
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\iueda\.codex\bin\cc-subscription-gateway.ps1 check
```

期待結果:

```text
OK: DPAPI token decrypted and higher-priority API credentials are blocked.
```

レビュー:

```powershell
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\iueda\.codex\bin\cc-subscription-gateway.ps1 reviewer "{プロンプトファイルの絶対パス}"
```

実装:

```powershell
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\iueda\.codex\bin\cc-subscription-gateway.ps1 coding-agent "{プロンプトファイルの絶対パス}"
```

### 認証・利用不可判定

コアラッパーは、Claude Code起動中だけ次を行う。

- `ANTHROPIC_API_KEY`、`ANTHROPIC_AUTH_TOKEN`、クラウドプロバイダー指定、ゲートウェイURLを子プロセスから除外する。
- DPAPI暗号化ファイルを現在のWindowsユーザーで復号する。
- 復号したsetup-tokenを`CLAUDE_CODE_OAUTH_TOKEN`として子プロセスへ設定する。
- 条件を満たせない場合は停止し、APIキーへフォールバックしない。

次のいずれかを生のエラーで確認した場合だけ利用不可と判定する。

- DPAPIトークンの不存在・復号失敗
- setup-token失効・認証失敗
- Claude Code quota上限
- ネットワーク障害
- reviewer/coding-agentが存在しない
- Codex rulesがゲートウェイを許可しない

ゲートウェイが失敗した場合は直接`claude`へ迂回せず、生のエラーを報告する。この報告方法はWindowsに限り、Linuxでは次節の固定メッセージの規則に従う。

## Linux / Codex クラウド

[確認 2026-09-12] 通常タスクと独立した次タスクで、Setup Secret → 0600ファイル → Claude子プロセスのOAuth認証による `OK` 応答を確認した（キャッシュ無効）。Linuxでは次の経路を使う。Windowsの経路・規律は上節に従う。

- 環境のSetup scriptに `~/.agents/cloud/codex-setup.sh`、Maintenance scriptに `~/.agents/cloud/codex-maintenance.sh` の内容を貼る。
- Secret `CC_SUBSCRIPTION_TOKEN` の値は**人間が登録する**。取得は人間の端末で `claude setup-token` を実行する。値を会話・コード・通常の環境変数設定へ貼らない。
- **Secret は任意**。登録した環境だけ Claude 連携が有効。未登録の環境では `cc-subscription-call.py` は認証ファイル無しで失敗する（`CLAUDE_SUBSCRIPTION_CALL_FAILED`）。その場合は Claude を呼ばず、人間に「この環境は Claude 連携なし」と報告する。Codex単独での継続は利用側の規則に従い、CC必須の場合は停止する。
- 認証ファイルは `/root/.config/claude-subscription/oauth-token`。内容の表示・プロンプトへの挿入は禁止。`cc-subscription-call.py` の内部だけで読み、子プロセスへ渡す。
- Claude 呼び出しは `~/.agents/cloud/cc-subscription-call.py` が唯一の経路。確認は `python3 ~/.agents/cloud/cc-subscription-call.py --check`。
- レビュー・実装は、プロンプト本文を UTF-8 の一時ファイルへ書き、`python3 ~/.agents/cloud/cc-subscription-call.py "{プロンプトファイルの絶対パス}"` を**別の shell tool call** で呼ぶ（Windows 節と同じ規律）。
- `--check` は実測済み。プロンプトファイル経由のレビュー・実装呼び出しは 2026-09-12 時点で未検証。
- APIキー、Console認証、`--bare`、別の接続先へのフォールバックは禁止。失敗時は終了コードと固定メッセージだけを報告し、認証情報を含み得る生の出力を表示しない。
- 同一タスク中に再利用する認証ファイルは呼び出しごとに削除せず、タスク終了時に削除する。キャッシュを有効にした場合、セットアップ時の認証ファイルが最大12時間のスナップショットに残り得る。タスク内での削除はキャッシュの失効操作ではない。
- 認証を撤去するときはSecretを削除し、Setup / Maintenanceの認証設定を外して環境を保存する。Secret変更でキャッシュが無効になる。発行元トークンの失効とは別の操作である。
- キャッシュ再開時の配置・認証ファイル確認はMaintenanceに任せる。Claude 連携を有効にしたい環境では、人間が Secret を登録して Setup を再実行する。12時間のキャッシュ保持と実際のレビュー・実装のE2Eは未実測。
