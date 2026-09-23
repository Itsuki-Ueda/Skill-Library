# Claude Codeタスク連携

Claude Codeを使うときだけ `~/.agents/skills/claude-code-subscription/SKILL.md` を読む。認証・OS別コマンド・利用不可判定・失敗報告・一時ファイルの扱いは同スキルに従う。本書はタスクの受け渡しを定める。

## モデル・推論強度の指定（Windowsのみ・任意）

ゲートウェイのコマンド末尾には `-Model {モデル}` `-Effort {low|medium|high|xhigh|max}` を付けられる。
省略時の挙動は従来どおり（Claude Code の既定に従う）。
agent-team の hard-worker・cc-worker（claude-opus-5-5 / high）やレビュー（claude-opus-5-5 / medium）はこれを使う。

## レビュー呼び出し

レビュー用プロンプトを作り、正本の必須フローと実行OSのレビュー手順で渡す。初回・再レビューの詳細は `~/.agents/codex/skills/autodev/references/workflow-details.md` を参照する。

```text
モード: 初回差分レビュー
比較元: {実行側が確定したbase-ref}
対象版: {コミットSHA、またはHEADと作業ツリーの識別情報}
未コミット変更: {タスク所有のstaged・unstaged・untrackedの範囲／なし}

対象の作成経緯を知らない第三者として、reviewer定義の規律で審査してください。
P0-P3タグ、根拠箇所、具体的な壊れ方、VERDICTを出してください。
```

## 実装呼び出し

承認済み計画・制約を一時プロンプトファイルへ書き、正本の必須フローと実行OSの実装手順で渡す。

Claude Codeに実装させる場合も、commit、push、PR、最終検証、レビュー集約はCodexが持つ。

## 利用不可時

利用可否とエラー報告は正本のOS別規則に従う。縮退が許される場合はCodex独立レビューへ移り、CC必須の場合は停止する。

## 非同期agmsg

agmsgは、既に起動済みのClaude Codeセッションが同じサブスクリプション認証で動いていることを確認できる場合だけ利用する。決定的な1回レビューはゲートウェイを優先する。
