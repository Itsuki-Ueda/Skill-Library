# init — agent-team の敷設

1. `templates/init/` からconfig/state/backlog/queueを敷設する。stateにはmissions/closed、queueにはtasks/reports/reviews/researchを作る。
2. 実在する検証コマンドを確認して `verify.post_change` / `verify.smoke` をユーザーと確定する。未確定で本流へ進まない。
3. `AGENTS-section.md` をプロジェクトAGENTS.mdへ追加し（規則本文は複製しない）、CLAUDE.mdが無ければ `@AGENTS.md` を置く。
4. `.agents/tmp/` をgitignoreへ追加し、状態本体は追跡する。
5. CI（`.github/workflows/`）があれば、`.agents/` だけの変更でビルド・テストを走らせない設定を提案し、承認後に敷設PRへ含める。必須チェックが無い→ `paths-ignore: ['.agents/**']`。有る・不明→差分判定ジョブを置き対象ジョブを `if` で飛ばす（差分の取得失敗・空の差分・判定ジョブの失敗では実行する）。CIが無ければ伝えるだけで新設しない。
6. 空repoの初回コミットはgit-setup、既存repoへの敷設はgit-opsに従う専用PR。開発ミッションに同乗させず先に統合する。
