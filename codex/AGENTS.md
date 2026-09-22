# Codex 固有設定

**最初に `~/.agents/AGENTS.md` を読み、記載の全ルールに従うこと。**
このファイル単体では不完全であり、共通ルール（基本ルール・エラー修正ルール・APIキー取り扱い・
Git運用・Git author設定・スキル統合運用ルール）は正本側にある。

## オーバーエンジニアリングを避ける
現在の要件を確実に満たす最も簡潔な実装を選ぶ。既存設計・依存を活用し、現実的な境界条件を守り、要求外の機能・抽象化・設定を増やさない。

## PR Review Worktrees
- Do not reuse old review worktrees by default.
- Before reviewing a PR, run a fresh fetch/prune and create a fresh temporary worktree from the latest target state: the target PR's confirmed base ref plus its latest head or merge ref.
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

- CodexからClaude Codeを呼ぶ直前に `~/.agents/skills/claude-code-subscription/SKILL.md` を読み、実行環境に対応する手順を使う。
- 直接実行、APIキー課金へのフォールバック、秘密情報の出力・プロンプトへの混入を禁止する。
- 認証・利用可否・エラー報告・一時ファイルの扱いは同スキルに従う。

## Git運用

Git のブランチ・PR・マージ・worktree を触る前に、git-ops スキルを読む
（正本 `~/.agents/skills/git-ops/SKILL.md` ＋ Codex固有 `~/.codex/skills/git-ops/SKILL.md`）。
操作の可否は実行先の権限による。承認付き実行・GitHub操作・後片付けの正式な経路はCodexラッパーに従い、制限を迂回しない。
