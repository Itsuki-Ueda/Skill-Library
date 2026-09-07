# グローバル共通ルール（CC・Codex 共通の正本）

このファイルは Claude Code / Codex CLI / その他ツールの共通ルールの正本である。
各ツール固有の設定は `~/.claude/CLAUDE.md` または `~/.codex/AGENTS.md` に記載される。

## 基本ルール
- 技術的な内容は初心者向けに分かりやすく解説すること。
- 人間向けの出力は必ず日本語で行うこと。
- **ユーザーに「ここを置き換えて」と案内する箇所は必ず `{}` で囲む**（2026-09-05 指示）。
  例: `ALTER ROLE ec_analysis_runtime PASSWORD '{パスワード}';` / `postgresql://{ユーザー名}:{パスワード}@host:6543/postgres`
  - `()` `【】` `〜〜〜` 等を場当たりで使い分けない。**同じ回答内でも表記を揺らさない**。
  - 引用符・角かっこなど**構文上必要な記号の内側**に `{}` を置く（`'{値}'`）。
    ユーザーが `{}` ごと消したときに構文が壊れないようにするため。
  - 置換すべきでない箇所（キーワード・固定文字列）は `{}` で囲まない。囲まれていない＝そのまま残す、と読める状態を保つ。

## APIキー・シークレットの取り扱い
- **ローカルに保存されている APIキー（ユーザースコープ環境変数の ANTHROPIC_API_KEY 等）を勝手に使わないこと**。
  テストや動作確認で実APIキーが必要になったら、使用してよいか必ず事前にユーザーへ確認する（2026-07-15 指示）。

## エラー修正ルール
- エラー原因を調査する際、原因を推測することは絶対に禁止です。
- ファクトベースで原因を特定すること。
- 原因が特定できない場合は、調査用コードを入れてプレビュー環境で調査すること。
- 場当たり的な修正を繰り返すことは禁止します。根本原因を特定して根本治療を原則とします。
- 対処療法的な修正が最善と判断した場合は、その旨をユーザーに伝えて判断を仰ぐこと。

## Git運用（全プロジェクト適用・正本は git-ops / git-setup スキル）

Git 操作の前に、下表のどちらのスキルを読むかを判定し、その手順に従う。
運用ルールの正本はスキル側にあり、ここには複製しない。

| 局面 | 正本スキル |
|---|---|
| **初期セットアップ（一度きり）**: リポジトリ新規作成 / クローンして開発できる状態にする / `git init` / `gh repo create` / `.gitignore`・`.gitattributes` 初期配置 / 初回コミット | `git-setup`（`~/.agents/skills/git-setup/SKILL.md`） |
| **日常運用（毎回）**: ブランチ・PR・マージ・worktree・後片付け | `git-ops`（`~/.agents/skills/git-ops/SKILL.md`） |

git-ops の要点だけ再掲（詳細と具体コマンドはスキル参照）:

- `main` に直接コミット/pushしない。変更は必ずブランチ→PR→スカッシュマージ。
- ブランチ名は `<type>/<slug>`（`feat/ fix/ refactor/ perf/ sec/ chore/ docs/ test/`）に統一。`feature/` は使わない。
- **マージしたら即・後片付け**（worktree削除→リモートブランチ削除→ローカルブランチ削除→prune）。散らかりの根本原因はこの省略。
- 手作業で消さず、棚卸しは `bash ~/.agents/skills/git-ops/scripts/git-hygiene.sh`（ドライラン既定→`--apply`）を使う。
- リポジトリ設定（`delete_branch_on_merge`・main保護・スカッシュ限定）はサーバー側の強制策。変更前に人間の承認を得る。

## Git author 設定 (2026-09-07 再定義・自動切替)

author は**ディレクトリで自動的に決まる**。手で切り替えない。

| 用途 | user.name | user.email | 適用範囲 |
|---|---|---|---|
| 仕事用（既定） | `itsukiueda-ourai` | 仕事用メール（`~/.gitconfig` の `[user]` に設定済み。実アドレスはこの文書に書かない） | 上記以外すべて |
| プライベート | `Itsuki-Ueda` | `73779819+Itsuki-Ueda@users.noreply.github.com` | `Documents/個人開発/` 配下 と `~/.agents` |

仕組み: `~/.gitconfig` の `[user]` が仕事用の既定で、末尾の `includeIf "gitdir/i:..."` が
プライベート対象ディレクトリでだけ `~/.gitconfig-private` を読み込んで上書きする。
git 標準機能なので、リポジトリごとの local 設定も、作業前後の切替も不要。

⚠️ **グローバル author を手で切り替えない**（切替運用は 2026-09-07 に廃止。戻し忘れ事故の根本原因だった）。
名義がおかしいと感じたら、まず実効値を見る:

```bash
git config user.name && git config user.email    # 対象リポジトリの中で実行
```

注意点:
- **新しいプライベート案件は `Documents/個人開発/` 配下に置く**。この外に置くと仕事用名義になる。
  やむを得ず外に置く場合だけ、そのリポジトリに local 設定で上書きする（git-setup §1-1 手順4）。
- author（コミット名義）と push 認証（gh のアクティブアカウント）は**別物**。
  author が自動でも、push する資格情報は gh 側が決める。
- 旧設定（共有アカウント `engineer01`）は廃止。
  切替前の `~/.gitconfig` は `~/.gitconfig.bak-20260907` にある。

## スキル・agents・グローバルルールの構造管理（正本は skill-ops スキル）

このマシンの skills / agents / グローバルルールは `~/.agents/` に正本を一本化し、
ツール側（`~/.claude/`・`~/.codex/`）は Junction または薄いラッパーだけを置く構造で管理している。

**`~/.claude/skills/*`・`~/.codex/skills/*`・`~/.agents/*`・`~/.claude/agents/*`・`~/.codex/agents/*`・
`~/.claude/CLAUDE.md`・`~/.codex/AGENTS.md`・`~/.agents/AGENTS.md` のいずれかを
編集・作成・削除・移動する前に、必ず `skill-ops` スキル
（`~/.agents/skills/skill-ops/SKILL.md`）を読み、その手順に従うこと。**

**編集後は skill-ops の公開手順（`bash ~/.agents/skills/skill-ops/scripts/publish.sh "<メッセージ>"`）で
GitHub への push まで完了させること。push 前は正本の更新が未完了。**

運用ルールの正本はスキル側にあり、ここには複製しない
（正本の場所判定・Junction 検出・ラッパー編集ルール・新規スキル追加手順・公開手順・修復手順は skill-ops 側）。

⚠️ **`~/.agents` は public リポジトリ**（2026-09-07 公開）。実メール・認証情報・勤務先の org 名・業務リポジトリ名・案件名は
書かない。境界の正本は skill-ops「公開範囲」節。業務固有の知見はそのプロジェクトの `AGENTS.md` へ。

## 記憶ファイルの書き込み規約（全プロジェクト・全ツール共通。正本は memory-ops スキル）

リポジトリの `AGENTS.md`、`.agents/state/MEMORY.md`、`.agents/state/INBOX.md` に何かを書き足す前に、
必ず `memory-ops` スキル（`~/.agents/skills/memory-ops/SKILL.md`）を読み、その規約に従う。要点だけ再掲:

- 書き先は「誰が読む必要があるか」で1つに決める（全員→AGENTS.md / agent-team の Orchestrator だけ→MEMORY.md）。
- 教訓・罠の初出は `INBOX.md` に1行（候補）。同じ主題の3回目で正式記憶へ昇格。人間の明示指示だけ直行。
- 書式は「症状・条件 → 対処」＋確認日＋根拠（file:line）。根拠の無い項目は refresh で削除される。
- SessionStart hook が閾値超過（AGENTS.md>200行等）を報告したら: agent-team 起動時は作業前に実施、
  それ以外のセッションでは着手前に人間へ一言告げて判断を仰ぐ。黙って無視しない。
