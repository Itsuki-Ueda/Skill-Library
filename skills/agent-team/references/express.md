# express — S判定の軽量工程

## 条件
- 対象ファイル確定、設計判断不要、diff一読でレビュー可能。同時1件だけ。
- governance（.agents/、AGENTS.md、CLAUDE.md、スキル定義）は対象外。
- 分解・計画レビュー・人間承認・独立reviewer・plan-probeは使わない。
- **親のdiff直読で合格可能。同一ベンダーでも可。クロスベンダー未達の警告は不要。**
- 共通本体[0]の前提確認は行う。簡略化するのは契約と記帳であり、必要な実行検証は省略しない。

## 手順
1. `templates/EXPRESS_TEMPLATE.md` のGoal / Acceptance / Allowed paths / Verificationを埋め、queue/tasks/T-E-xxx.mdへ保存する。
2. ハーネスのexpress担当へ契約とteam-worker規約を渡す。session IDと成果物を記録する。
3. 親が報告をqueue/reportsへ保存し、差分・新規ファイル・契約外変更・要件・退行を直読する。版と判定はdispatchの形式でqueue/reviewsへ残す。
4. 修正は同じworkerへ戻し、親が対処と退行を確認する。上限はlimits.fix_rounds_express。
5. 契約外変更なしを確認し、verify.post_changeとverify.smokeを実行する。テスト契約に変異があれば適用・失敗・復元を確認する。
6. 親がレビュー・検証した内容だけをcommitする。変更が入ったら影響するレビューと検証を更新する。
7. STATEのLogにT-E-xxxの結果を1行記録し、状態変更をcommitする。ミッションファイルは作らない。
8. 変更・検証・commitを報告し、資源を作った場合はgit-opsに従って後片付けする。

対象ファイルの増加、設計判断の発生、修正上限超過ならMへ昇格する。
GENERAL_TEMPLATEで契約を更新し、必要な調査・計画レビュー（初回probeを含む）・人間承認を行ってからミッション工程を続ける。
