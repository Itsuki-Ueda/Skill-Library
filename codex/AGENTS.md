# Codex 固有設定

**最初に `~/.agents/AGENTS.md` を読み、記載の全ルールに従うこと。**
このファイル単体では不完全であり、共通ルール（基本ルール・エラー修正ルール・APIキー取り扱い・
Git運用・Git author設定・スキル統合運用ルール）は正本側にある。

## オーバーエンジニアリングを避ける
現在の要件を、既存のアーキテクチャに沿って、確実に満たせる最もシンプルな方法を選択してください。

以下の方針を守ってください。

* 現在の要件に必要な範囲だけを実装する
* 変更は小さく、直接的で、理解しやすいものにする
* 既存の設計、実装方針、依存関係を可能な限り活用する
* 実際に発生し得る、または発生可能性が高いエッジケースには対応する
* 将来使うかもしれないという理由だけで、抽象化、共通化、拡張機能を追加しない
* 不要なレイヤー、クラス、インターフェース、設定項目、フォールバック処理を増やさない
* 現在求められていない機能を先回りして実装しない
* 仮説上の問題や、可能性が極めて低いケースのために複雑性を増やさない

複雑な設計や実装を採用するのは、現在の具体的な要件を満たすために本当に必要な場合だけにしてください。

複数の方法が要件を同程度に満たせる場合は、コード量、変更範囲、依存関係、認知負荷が最も小さい方法を優先してください。


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
- 承認済み仕様に基づく実装は、カスタムAgent `coding` を名前指定して起動する。
- 計画、差分、commit、PRの独立レビューは、新しいカスタムAgent `reviewer` を名前指定して起動する。
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

## Git運用

Git のブランチ・PR・マージ・worktree を触る前に、git-ops スキルを読む
（正本 `~/.agents/skills/git-ops/SKILL.md` ＋ Codex固有 `~/.codex/skills/git-ops/SKILL.md`）。
Codex はサンドボックス制約（`network_access=false`）でローカルの後片付けまでを担当し、
リモートブランチ削除・GitHub設定変更は非サンドボックス（Claude）側に委ねる。詳細は Codex ラッパー参照。
