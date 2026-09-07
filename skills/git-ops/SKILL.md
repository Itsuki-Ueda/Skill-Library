---
name: git-ops
description: Git運用の正本（全プロジェクト共通）。ブランチ命名・寿命・PR・スカッシュマージ・「一時worktreeのライフサイクル（作成→役目終了で即closeout）」・「マージ後の即後片付け（ローカル/リモートのブランチ削除＋worktree削除）」・定期棚卸しの手順を規定する。ブランチ作成/PR作成/マージ/ブランチ削除/worktree作成/調査用・レビュー用worktree/worktree操作/「gitを掃除」「ブランチが多い」「worktreeが残る」「後片付け」等、Git のブランチ・PR・worktree を触るあらゆる操作の前に必ず読む。
---

# git-ops — Git運用の正本

このスキルは、Claude / Codex / 人間の誰が作業しても、プロのエンジニアチームと同等の
Git状態（`main` ＋ 進行中の作業だけが存在する状態）を維持するための **手順の正本** である。
判断の余地を残さないよう、規約と具体コマンドを固定化する。迷ったらこの文書に従う。

> **このスキルの守備範囲は「日常運用」。** リポジトリを作る／クローンして開発できる状態にする
> までの**初期セットアップ**（`git init` / `gh repo create` / `.gitignore`・`.gitattributes` の初期配置 /
> 初回コミット / author・gh認証の確認）は `git-setup`（`~/.agents/skills/git-setup/SKILL.md`）が正本。

## 0. 不変条件（絶対に破らない）

1. **`main` に直接コミット・直接pushしない。** 変更は必ずブランチ→PR経由で入れる。
2. **1ブランチ = 1目的。** 1つの機能/修正に対応させ、肥大化させない。
3. **ブランチは短命。** 作ったら数日以内にマージして消す。長期間放置しない。
4. **worktree・ブランチは役目を終えたら即・後片付け（§2.5 / §3）。** マージはその一契機にすぎない。
   省略しないことが散らかりの唯一の根本対策。
5. **削除は fail-closed。** 「マージ済みPRがある」または「`origin/main` に未反映コミットが0」を
   確認できたブランチだけ消す。未確認・未マージのものは残す。

## 1. ブランチ命名規約（1つに統一）

形式は **`<type>/<短いスラッグ>`**。`type` は下表のみ。`feature/` は使わず `feat/` に寄せる。

| type | 用途 |
|---|---|
| `feat/` | 新機能 |
| `fix/` | バグ修正 |
| `refactor/` | 動作を変えない内部改善 |
| `perf/` | 性能改善 |
| `sec/` | セキュリティ対応 |
| `chore/` | 設定・依存・雑務 |
| `docs/` | ドキュメントのみ |
| `test/` | テストのみ |

- **例外（ツール自動生成）**: Claude Code は `claude/<セッション名>`、Codex は `codex/<名>` の
  作業ブランチ・worktree を自動生成する。これは止められないので許容するが、**そのブランチも
  §3 の後片付け対象**であり、タスク完了後に必ず消す。PRのヘッドは可能なら `<type>/<slug>` にする。

## 1.5 ハーネス固有設定

ネットワーク・承認機構・一時worktree置き場は各ハーネスの固有ルールで定義する。
この正本は完了条件を規定し、実行できない工程は確認済みの正式な経路へ委譲する。利用可否が不明な経路を推測で使わない。

- Claude Codeの一時/自動生成worktree置き場は `.claude/worktrees/`。
- Codexは `~/.codex/skills/git-ops/SKILL.md` の固有ルールを併読する。

## 1.6 他スキルとの優先順位と公開前確認

- ブランチ命名・PR状態・マージ方式・closeoutは本スキルを優先し、汎用GitHubスキルの既定値で上書きしない。
- 「PR作成」までなら draft を既定とし、「マージまで」の明示依頼では ready PR としてCI・保護ルールを満たしてからマージする。
- push前に `HEAD`、stage対象、`origin`、送信先owner/repository、base/headを確認する。送信先が依頼内容から特定できなければpushしない。

## 2. ブランチのライフサイクル

```
作成 → 作業（1目的・小さく） → PR作成 → レビュー → CIグリーン → スカッシュマージ → §3 後片付け
```

- **マージ方式はスカッシュに統一**（作業中の細かいコミットを1つに潰す）。`main` の履歴を機能単位の
  一本道に保つ。マージコミット/リベースマージは使わない。
- **コミットメッセージは Conventional Commits**（`feat: ...` `fix: ...`）を推奨。PRタイトルが
  スカッシュ後のコミットメッセージになるので、PRタイトルを規約に沿わせる。

## 2.5 一時Worktreeのライフサイクル（レビュー/実装/調査/検証すべて対象）

worktree は寿命を持つ資源。PRレビュー用だけでなく、実装・調査・検証・再現・証跡作成など
**すべての用途の worktree** が対象。

### 分類は"場所"で決める（常時の記録は不要）
- **`一時用`（このタスクが作った使い捨て）**: ハーネス指定の一時/自動生成置き場（§1.5）にある worktree。
  作成時点で「削除条件成立後の自動 closeout まで承認済み」とみなす。
- **`ユーザー保有`（ユーザー/別タスクの資産）**: 上記以外の場所（ユーザーが選んだパス）にある worktree。
  削除には**明示の許可**が必要。勝手に消さない（未コミット差分・未完作業の保全）。
- 削除条件（マージ済み・clean 等）は記録せず**機械的に導出**する（§4 スクリプトが実施）。

### 残したい例外だけマーカーを置く
`一時用` の場所にあっても消したくない worktree は、その worktree の
`.git/worktrees/<name>/KEEP`（理由を1行）に置く。closeout は KEEP があれば残す。
＝忘れても「一時用として片付く」安全側に倒れる。

### 新規作成の前に棚卸し（増殖防止）
「旧worktreeは触らず新しく作る(fresh)」の繰り返しが増殖の原因。新規作成の前に同一タスクの
既存 worktree を確認し、再利用できないか / 旧分の削除条件が既に成立していないかを見る。
保全が必要（KEEP対象）なときだけ新規作成する。

### node_modules を junction/symlink で親と共有している worktree
worktree に親リポジトリの `node_modules` への junction（Windows）/symlink を張って共有するのは可
（npm install の時間・ディスク節約、オフラインサンドボックス対応）。ただし **closeout 時は
必ずリンクを先に外す**（§3 step 0）。外さずに削除すると親の node_modules が破壊される。

### closeout（役目を終えたら即片付け・マージ限定ではない）
削除条件が成立し KEEP が無ければ、その場で closeout（手順 §3 / スクリプト §4）。契機:
review→レビュー終了 / investigate・verify→調査・検証完了 / implement→対応PRのマージ。
fail-closed（§0-5）は不変。

### 自動closeoutの安全ガード（§4スクリプトが機械適用）
一括棚卸し（§4）で自動削除する際、稼働中/未完のものを誤って消さないため次を機械適用する:
- **稼働中ガード**: worktree の HEAD が直近12時間以内に動いていれば触らない（別セッションが作業中の可能性）。
- **セッションブランチ厳格化**: `claude/* codex/*` は「main内包」だけでは消さず、**マージ済みPRがあるときのみ**削除。
  （セッション開始直後は常に main内包＝ahead0 のため、これだけでは"完了"と区別できない）
- 対象は自分で作った一時用worktree。ユーザー保有・KEEP付き・未マージは元々対象外。

## 3. マージ後の後片付け手順 ★最重要★

PRがマージされたら **その場で** 次を実行する。順序を守る（worktreeを先に外さないとブランチを消せない）。
このタスクで作成した既知の単一ブランチは本節で即時closeoutし、過去・複数・所有者不明の対象は §4 の棚卸しを使う。

> 既知の不具合（このマシン）: `gh pr merge --delete-branch` は worktree 多用環境で後処理に失敗する。
> 依存せず、下記コマンドを明示的に叩く。

> ⚠️ **junction/symlink 破壊注意（2026-08-03 実害あり）**: worktree 内に親リポジトリの
> `node_modules` 等へ張った junction/symlink がある場合、それを残したまま
> `git worktree remove --force` や `rmdir /s`・`Remove-Item -Recurse` を実行すると、
> **リンクを辿ってリンク先の実体（親の node_modules）が破壊される**。
> しかも worktree 自体はロック等で削除失敗と報告されることがあり、ログからは破壊に気づけない。
> 必ず下記 step 0 で「通路」を先に外してから worktree を消す。

```bash
# 0) worktree 内の junction/symlink（node_modules 共有等）を先に外す（ある場合のみ）
#    cmd の rmdir（/s を付けない！）は junction の「通路」だけ外し、リンク先には触れない
cmd /c rmdir "<worktree_path>\node_modules"
#    Unix の symlink なら: rm <worktree_path>/node_modules
#    禁止: rmdir /s・Remove-Item -Recurse（junction を辿って実体を破壊する）

# 1) その作業を載せていた worktree を外す（worktree で作業していた場合）
#    ※ その worktree の中にいるなら先にリポジトリルートへ cd out する
#    ※ step 0 実施後は --force が不要なことも多いが、付けても安全
git worktree remove --force <worktree_path>

# 2) リモートのブランチを削除（GitHub側の自動削除がONなら不要。§5参照）
git push origin --delete <branch>

# 3) ローカルのブランチを削除（スカッシュマージ済みは -d では消せないので -D）
git branch -D <branch>

# 4) 後始末
git worktree prune
git remote prune origin
```

完了後は、PRがMERGED、`main`が最新、対象のローカル/リモートブランチと一時worktreeが不存在であることを確認する。

## 4. 定期棚卸し（スクリプト） — 誰が使っても同じ結果

過去・複数・所有者不明の対象には、判定ロジック（スカッシュマージ対応・場所分類・稼働中ガード・KEEP尊重・未コミット退避・fail-closed）を固定化した棚卸しスクリプトを使う。

```bash
# まずドライラン（消す対象を一覧するだけ。破壊しない）
bash ~/.agents/skills/git-ops/scripts/git-hygiene.sh

# 問題なければローカルを片付け（worktree＋ローカルブランチ）
bash ~/.agents/skills/git-ops/scripts/git-hygiene.sh --apply

# リモートのマージ済みブランチも消す場合
bash ~/.agents/skills/git-ops/scripts/git-hygiene.sh --apply --remote
```

- 既定はドライラン。`--apply` のときだけ実際に削除する。
- `main` と現在チェックアウト中のブランチ/worktree は絶対に触らない。
- worktree は場所で分類（§1.5）: 一時用置き場のものだけ自動 closeout、ユーザー保有(OWNED)は検出のみ、KEEP付きは常に残す。
- 稼働中ガード（HEAD直近12h）・セッションブランチはPR必須（§2.5）を機械適用。孤立フォルダは検出のみ（削除しない）。
- worktree 削除前に内部の junction/symlink（node_modules 共有等）を自動検出し「通路だけ」外す（§3 の警告参照）。
- 未コミット変更のある worktree は差分をパッチ退避してから削除する。
- **実行タイミング**: 過去・複数・所有者不明の対象を扱うとき、およびセッション開始時 or 週次。

### worktree削除が「使用中」で失敗したら
稼働中の node/dev-server/別セッションがフォルダをロックしている。**推測でプロセスをkillしない**
（自分のMCPサーバや動作中のdev serverを巻き添えにする）。該当セッションを閉じるか再起動後に再実行する。
Git登録からは既に外れていれば無害なので、急がず後で消してよい。

## 5. リポジトリ側の設定（サーバー側で全員に強制する前提）

ローカル手順だけに頼らず、GitHub側の設定で機械的に強制する。これが最も確実。

- **`delete_branch_on_merge = true`**（マージ時にヘッドブランチを自動削除）。リモートの抜け殻を根絶する。
- **`main` のブランチ保護**: PR必須・直接push禁止・CIグリーン必須・（可能なら）レビュー必須。
- **マージ方式をスカッシュのみに制限**（merge commit / rebase を無効化）して履歴を統一。

確認コマンド:
```bash
gh api repos/<owner>/<repo> --jq '{auto_delete:.delete_branch_on_merge, squash:.allow_squash_merge, merge:.allow_merge_commit, rebase:.allow_rebase_merge}'
gh api repos/<owner>/<repo>/branches/main/protection   # 404なら保護なし
```
※ これらの変更はリポジトリ設定の変更なので、**適用前に必ず人間の承認を得る**。

## 6. チェックリスト（PRを出す/マージするたびに）

- [ ] ブランチ名は `<type>/<slug>` 規約に沿っているか（`feature/` になっていないか）
- [ ] 1ブランチ1目的に収まっているか
- [ ] `main` に直接コミットしていないか
- [ ] スカッシュマージしたか
- [ ] マージ直後に §3 の後片付け（worktree→リモート→ローカル→prune）を実行したか
- [ ] 一時worktreeは役目を終えたら closeout したか（§2.5。残すなら KEEP マーカー）
- [ ] 迷ったら手作業で消さず §4 のスクリプトをドライラン→apply で回したか
