# init — agent-team の敷設

`/agent-team init` で読む。

1. `~/.agents/skills/agent-team/references/templates/init/` からconfig/state/backlog/queueを敷設する。stateにはmissions/closed、queueにはtasks/reports/reviews/researchを作る。
2. 実在する検証コマンドを確認して `verify.post_change` / `verify.smoke` をユーザーと確定する。未確定で本流へ進まない。
3. `AGENTS-section.md` の最小ポインタをプロジェクトAGENTS.mdへ追加し、CLAUDE.mdが無ければ `@AGENTS.md` を置く。規則本文を複製しない。
4. `.agents/tmp/` をgitignoreへ追加し、状態本体は追跡する。
5. CI（`.github/workflows/`）があれば、`.agents/` だけの変更でビルド・テストを走らせない設定を提案し、ユーザーの承認後に敷設PRへ含める。方式は必須チェックの有無で選ぶ: 無い→起動条件に `paths-ignore: ['.agents/**']`。有る・確認できない→差分判定ジョブを置き、対象ジョブを `if` で飛ばす（条件で飛ばしたジョブは必須チェックでも成功扱い。差分の取得失敗・空の差分・判定ジョブの失敗では実行する）。CIが無い場合はその旨を伝えるだけにする（新設は本手順の対象外）。
6. 空repoの初回コミットはgit-setup、既存repoへの敷設はgit-opsに従う専用PR。開発ミッションに同乗させず先に統合する。
