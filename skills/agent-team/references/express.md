# express — S判定の軽量工程

## 条件
- 対象ファイル確定、設計判断不要、diff一読でレビュー可能。同時1件だけ。
- governance（.agents/、AGENTS.md、CLAUDE.md、スキル定義）は対象外。
- 分解・計画レビュー・人間承認・独立reviewer・plan-probeは使わない。
- 親のdiff直読で合格可能（同一ベンダー可・警告不要）。
- [0]前提確認と実行検証は省略しない。簡略化するのは契約と記帳だけ。

## 手順
1. 作業の型を `references/types/README.md` の表で中身から選び（当たるものは全部）、その型の[3]と[6]の欄を契約と検証に入れる。
   `templates/EXPRESS_TEMPLATE.md` を埋めて queue/tasks/T-E-xxx.md へ保存する。この手順と雛形は、既読でもT-E-xxxを始めるたびに読み直す（R8）。
   「画面確認」欄は dispatch「画面確認（前倒し）」に従って埋める（expressでも省略しない）。
2. ハーネスのexpress担当へ契約とteam-worker規約を渡す。session IDと成果物を記録する。
3. 親が報告をqueue/reportsへ保存し、差分・新規ファイル・契約外変更・要件・退行を直読する。版と判定はdispatchの形式でqueue/reviewsへ残す。画面確認はdispatchの手順で行い、記録が揃うまでcommitしない。
4. 修正は同じworkerへ戻し、親が対処と退行を確認する。上限はlimits.fix_rounds_express。
5. 契約外変更なしを確認し、verify.post_changeとverify.smokeを実行する。差分に `.github/workflows/` が含まれる場合は execute.md [6] の zizmor 検査も実行する。テスト契約に変異があれば適用・失敗・復元を確認する。
6. 親がレビュー・検証した内容だけをcommitする。
7. STATEのLogにT-E-xxxの結果を1行記録し、状態変更をcommitする。ミッションファイルは作らない。
8. `templates/REPORT_TEMPLATE.md` の順番で報告し（台帳の1行は無い）、資源を作った場合はgit-opsに従って後片付けする。

対象ファイルの増加、設計判断の発生、修正上限超過ならMへ昇格する。
GENERAL_TEMPLATEで契約を更新し、[2]〜[3]（初回probe・人間承認を含む）を経てミッション工程を続ける。
