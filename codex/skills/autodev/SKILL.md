---
name: autodev
description: "Codexを司令塔にし、カスタムAgent researcher/coding/reviewerを明示起動して、調査、計画、実装、検証、独立レビュー、必要時のClaude Code連携、PR・mergeまで進める自動開発ワークフロー。"
---

# Autodev — Codex ハーネス固有設定

**正本ワークフロー `~/.agents/skills/autodev/SKILL.md` を最初に読み、全フェーズに従うこと。**
このファイルは Codex 固有の動作のみを定義する。正本側の【ハーネス固有】を以下で埋める。

## 必須のカスタムAgent

| Agent名 | 主責務 | 期待プロファイル |
|---|---|---|
| `researcher` | 読み取り専用の調査・影響分析・根拠収集 | GPT-5.6 Luna / Max |
| `coding` | 承認済み仕様の実装と限定的な検証 | GPT-5.6 Sol / Medium |
| `reviewer` | 計画・差分・PRの独立レビュー | GPT-5.6 Sol / Extra High |

モデル・推論・sandbox・Agent固有規律は各TOML（`~/.codex/agents/`）を正本とする。このSkillからモデルを上書きしない。実行ログやUIで確認できない限り、期待プロファイルが実際に適用されたと断定しない。

## 実装者の解決
既定実装者 = Codex の `coding` Agent。ユーザーが CC 実装を明示した場合のみ CC。

## 人間との対話
- 設計判断は `NEED-DECISION: <判断が必要な内容と選択肢>` で止める。
- 明示されていない製品仕様、公開API、認可、データ形状、migration、不可逆操作の判断は勝手に埋めず `NEED-DECISION:` で止める。

## 実行ポリシー

### 実装権限
- ユーザーが「実装」「修正」「対応」「PRまで」等を依頼 → 依頼範囲の書き込みは許可済み。
- 「計画だけ」「調査だけ」「レビューだけ」→ 書き込まない。
- 「計画承認後に実装」→ Phase 4 レビュー後に停止して承認を待つ。

### Claude Code モード
- **CCなし**: 既定。Claude Code を呼ばない。
- **CC推奨**: ユーザーが「CCあり」「Claude Codeも使う」等を指定。利用不能なら Codex 単独へ縮退し報告。
- **CC必須**: ユーザー明示。利用不能なら停止。
- CC 推奨/必須の場合、`references/claude-code-bridge.md` を読む。

### Agentフォールバック
- 既定は `strict`。名前付きカスタムAgent を起動できない場合、組み込みAgent へ黙って置換しない。
- ユーザーが「Agentフォールバック可」と明示した場合だけ `degraded` を許可。
  - `researcher` → 組み込み `explorer`
  - `coding` → 組み込み `worker`
  - `reviewer` → 新規の組み込み `default` を読み取り専用レビュアーとして使う
- `degraded` では TOML のモデル・推論・sandbox が適用されたとは報告しない。
- 親自身の自己レビューは、フォールバック後も独立レビューの代替にしない。

## 開始時の確認
1. プロジェクト指示を読む（AGENTS.md / AGENTS.override.md / CLAUDE.md / README / CONTRIBUTING / package scripts / Makefile / CI設定）。
2. Git 状態を記録: `START_HEAD = git rev-parse HEAD` / 現在 branch / base branch / `git status --short`。
3. base ref はプロジェクト規約、PR の base、`origin/HEAD` の順で決める。根拠なしに `origin/main` と決め打ちしない。
4. 既存変更があれば依頼対象との重なりを確認。同一ファイル/hunk に重なる場合は専用 worktree へ移すか `NEED-DECISION:`。
5. full または PR 作成を伴う変更は、可能なら clean な専用 branch/worktree を使う。
6. レビュー規則とプロンプト詳細が必要な場合は `references/workflow-details.md` を読む。

## エージェント起動

### 調査
カスタムAgent `researcher` を新規起動。調査目的・具体的な質問・対象パス・除外範囲・読み取り専用・`path:line` 根拠付きで返すことを渡す。

### レビュー（プラン: Phase 4 / 差分: Phase 8）
- **Codex**: 新しいカスタムAgent `reviewer` を起動。計画ファイルまたは差分範囲、対象範囲、関連調査根拠を渡す。作者情報や誘導を渡さない。
- **CC（CC推奨/必須時のみ）**: `references/claude-code-bridge.md` の手順で CC `reviewer` を呼ぶ。レビュープロンプトは `references/workflow-details.md` 参照。

### 差分レビューの対象（Phase 8 補足）
commit 前は: タスク所有の staged/unstaged 差分 + 新規 untracked + 周辺コード + `START_HEAD` 以降の commit。
PR レビューは: `<base-ref>...HEAD` + push 後に残る変更 + PR 要件・関連 issue・migration・生成物。

### 実装（Codex 既定）
新しいカスタムAgent `coding` を起動。承認済み計画または軽量仕様・担当ファイル・変更してよい/いけない範囲・完了条件・最小検証・commit/push/PR/merge を行わないこと・他者変更を戻さないことを渡す。
1つの worktree で同時に複数の `coding` を動かさない。

### 実装（CC 指定時）
`references/claude-code-bridge.md` の手順で `coding-agent` を1プロセスだけ起動。
Codex の `coding` と CC `coding-agent` を同じ worktree で並列実行しない。

## light パスの省略
計画文書、計画レビュー、実装前承認を省略できる。**差分レビュー・検証・最終報告のレビュー証跡は省略しない。**

## NEED-DECISION の差し戻し
- Codex 実装者 → 既存規約で解消できる明白な局所判断だけ親が処理。それ以外はユーザーへエスカレーション。
- CC 実装者 → `references/claude-code-bridge.md` の手順で差し戻し。

## フォールバック
- Codex 実装: 同じブロッカーで2回止まったら推測で続けず停止。
- CC 実装: 同じ問題で2回止まったら、リスクに応じて Codex が引き取るかユーザーに確認。

## 計画レビュー上限到達時
3ラウンドで未収束 → 実装へ進まず停止する。

## PR 作成
- commit・push・PR 作成・merge はユーザーが明示的に依頼した範囲だけ行う。
- 計画ファイルはユーザーが求めない限り commit 対象にしない。
- PR 本文には目的・変更概要・検証・リスク・未検証事項・レビュー結果を書く。
- pre-commit hook/formatter/generator がファイルを変えた場合、再検証と再レビューを行う。

## マージ
merge はユーザーが明示的に求めた場合だけ行う。
merge 条件: 必須 CI green / P0-P2 ゼロ / 未解決の設計判断なし / working tree clean / base との競合なし / ユーザー指定の承認条件。

## 追加の停止条件
- 必須カスタムAgent を起動できず、フォールバック許可もない。
- CC 必須モードで Claude Code を利用できない。
- merge 条件を満たさない。
停止時は `BLOCKED:` または `NEED-DECISION:` を先頭に置き、必要な判断・選択肢・影響を明示する。

## 最終報告（Codex 固有追加項目）
- 実装権限: 実装済み / 計画のみ / 承認待ち
- Agent ポリシー: strict / degraded
- 使用 Agent: researcher（使用数、カスタム/フォールバック）/ coding（カスタム/CC/親実装/未使用）/ reviewer（各ラウンド）
- 期待プロファイルが実ログで確認できたか
- CC モード: なし / 推奨 / 必須
- CC ブリッジ結果: 直接CLI / agmsg / 利用不可 / 未使用

## 参照資料
- Claude Code CLI、PermissionRequest Hook、agmsg: `references/claude-code-bridge.md`
- Agent 起動プロンプト、計画テンプレート、レビュー対象の詳細: `references/workflow-details.md`
