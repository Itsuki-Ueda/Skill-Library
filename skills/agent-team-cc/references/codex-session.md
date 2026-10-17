# Codex 専用セッション — クラウド常駐のレビュアーと Git 経由の受け渡し

クラウドの Claude Code セッションに Codex CLI を常駐させ、コードレビューの依頼と結果を Git だけで受け渡す。
端末側のセッションはクラウドのセッションへ直接メッセージを送れず、クラウドのセッションも返信できないため、往復はすべて Git に載せる。
実測（2026-10-17、試験用リポジトリ）: 依頼の push から結果の検知まで 63〜84 秒（1 件ずつ処理していた版では、同時に出した 2 件目が 133 秒）。約 53 分放置した後も待ち受けと Codex の認証は残っていた。

## 置き場所（対象リポジトリの中のブランチ）

| ブランチ | 書く人 | 中身 |
|---|---|---|
| `review/<依頼ID>/head`・`review/<依頼ID>/base` | 依頼側 | レビュー対象のスナップショットと比較元 |
| `review-requests` | 依頼側 | `requests/<依頼ID>.txt`（1 行: `head=<ブランチ> base=<ブランチ>`） |
| 結果ブランチ（既定 `codex-reviewer`） | 常駐セッション | `reviews/READY.md`（準備完了の印）と `reviews/<依頼ID>.md`（結果） |

依頼側は `scripts/request-review.sh` と `scripts/wait-review.sh` を使い、手で組み立てない。

## 立ち上げ（人間が 1 回）

1. 対象リポジトリをクラウドから取り込めるようにする。クラウドの GitHub 接続が別アカウントなら、そのアカウントを共同編集者に追加する（2026-10-17 実例）。
2. Codex の Setup script を入れたクラウド環境で、対象リポジトリのセッションを起動し、最初の指示として「`~/.agents/skills/agent-team-cc/references/codex-session.md` の『常駐セッションの手順』に従う。結果ブランチは <result_branch>。」の 1 行を送る（agent-team-cc SKILL.md「立ち上げ」。起動できるセッションなら Claude が、できなければ人間が行う）。
3. セッションが出す Codex の device-auth の URL とコードをブラウザで承認する（セッションごとに 1 回）。

## 常駐セッションの手順（クラウドの Claude が行う）

起動時:
1. `codex --version` と `codex login status` を確かめる。未認証なら `codex login --device-auth` を起動し、URL とコードを返答に書いて承認を待つ。
2. 結果ブランチに `reviews/READY.md` を作り（中身: 結果ブランチ名・codex のバージョン・`codex login status` の結果・UTC 時刻）、commit・push する。**返答で知らせるだけで済ませない**（依頼側は Git しか見えない）。
3. 待ち受けを始める: `bash ~/.agents/skills/agent-team-cc/scripts/wait-request.sh <結果ブランチ>` を Bash の `run_in_background: true` で起動する（`&` で切り離さない）。

待ち受けが終わったら:
- `REQUEST id=<依頼ID> head=<...> base=<...>` の行（複数あり得る）ごとに、下の「依頼 1 件の処理」の 1〜3 を**すぐ**行う（Codex は並行で走らせる。1 件の完了を待ってから次を始めない）。
- 起動し終えたら、Codex の完了を待たずに同じコマンドで待ち受けを起動し直す。`NO_REQUEST` のときも起動し直す。これを続ける。
- Codex の完了通知が来たら、その依頼の 4〜6 を行う。PR は作らない。コードは直さない。

依頼 1 件の処理:
1. `git fetch origin <head> <base>`
2. `git worktree add --detach /tmp/review-<依頼ID> origin/<head>`（結果ブランチの作業ツリーを汚さない。このフォルダーが処理中の印になり、待ち受けが同じ依頼を二重に拾わない）
3. `bash ~/.agents/skills/agent-team/scripts/cx-run.sh review --cwd /tmp/review-<依頼ID> --target "--base origin/<base>" --out /tmp/<依頼ID>.md --model gpt-6.1-sol --effort medium` を `run_in_background: true` で起動する（完了通知が来たら 4 へ）。
4. 結果ブランチに `reviews/<依頼ID>.md` を作る:

   ```
   # Codex review <依頼ID>
   - head: <head> @ <head の commit SHA>
   - base: <base> @ <base の commit SHA>
   - codex: exit=<終了コード> session=<Codex の session id> model=gpt-6.1-sol effort=medium
   - reviewed_at: <UTC 時刻>

   ## Codex の出力
   <-o ファイルの中身をそのまま。書き換えない>
   ```

   Codex が失敗した（終了コード 0 以外・出力が空・認証切れ）ときも、`codex:` 行に実際の値を書き、「## Codex の出力」の代わりに「## 失敗」節へ `.err` の末尾 30 行を載せて push する（依頼側が待ち続けないように）。
5. `git add reviews/<依頼ID>.md && git commit -m "review: <依頼ID>" && git push origin <結果ブランチ>`
6. `git worktree remove --force /tmp/review-<依頼ID>`（push の後に消す。先に消すと待ち受けが同じ依頼を拾い直す）

複数の依頼の 4〜6 が重なったら 1 件ずつ順に行う（同じ結果ブランチへの commit・push がぶつからないように）。push が先行の push で拒否されたら `git pull --rebase origin <結果ブランチ>` してから push し直す。

## 既知の制約

- 常駐セッションが止まっている（コンテナ回収後に再開されない・認証切れ）と結果は来ない。依頼側は `timeout_min` で縮退する（agent-team-cc SKILL.md「Codex コードレビュー」5）。
- `review/<依頼ID>/*` ブランチはミッション完了時にまとめて消す（`git push origin --delete`）。
