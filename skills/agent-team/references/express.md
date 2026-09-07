# express.md — expressレーン（S判定タスク）の実施手順

原型のExpress Workerの移植。軽いのはレビュー体制と工程であって、検証ではない。

## 制約（原型踏襲）

- **同時1件のみ**。進行中のexpressがあれば完了を待つか、ミッションに切り替える。
- governanceパス（`.agents/`, `AGENTS.md`, `CLAUDE.md`, スキル定義）は変更対象にできない。
- 分解・cxplanレビュー・人間承認・reviewerサブエージェントは使わない（軽さの根拠）。
  その代わりレビューは**Orchestrator自身のdiff直読**で行う。

## 手順

1. **契約作成**: `templates/EXPRESS_TEMPLATE.md` から `queue/tasks/T-E-xxx.md` を作成。
   最小4項目（Goal / Acceptance / Allowed paths / Verification）を必ず埋める。
   Allowed pathsが書けない＝S判定が誤り。M判定に切り替える。
2. **dispatch**: dispatch.mdのCodexワーカー起動手順と同じ（実装形・バックグラウンド・
   session id記録）。モデルはteam.yaml `routing.express`。
3. **レビュー**: 完了通知後、`git diff -- <Allowed paths>` をOrchestratorが直読。
   観点: Acceptance充足 / 契約外変更の有無 / 明白なバグ・退行。
   `git status` でAllowed paths外の変更が無いことも確認。
4. **修正**: resume形で差し戻し。上限 team.yaml `limits.fix_rounds_express`（既定2）。
   超えたらM判定に昇格: 契約をGENERAL_TEMPLATEで書き直し、ミッションフローの[4]以降で回す。
5. **完了ゲート**: (a)契約外変更なし (b)verify.post_change (c)verify.smoke。**省略しない**。
6. **commit**: Orchestratorが `git add <Allowed paths> && git commit -m "T-E-xxx: <summary>"`。
7. **記帳**: STATE.mdのLogに1行（`T-E-xxx done: <summary>`）。ミッションファイルは作らない。
8. 人間へ結果報告（変更ファイル・検証結果・commit）。

## S判定を維持できなくなったら

実装途中で対象ファイルが増える・設計判断が出る・修正が2ラウンドで収束しない——
いずれかが起きた時点でexpressに固執しない。M判定に昇格して契約を書き直すのが正しい対応
（原型の「expressに収まらないと分かった時点で通常taskへ引き継ぐ」の移植）。
