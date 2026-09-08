---
name: skill-ops
description: "skills/agents/global rules の構造管理と編集手順（CC・Codex 共通の正本）。~/.agents/skills/*、~/.claude/skills/*、~/.codex/skills/*、~/.claude/agents/*、~/.codex/agents/*、~/.agents/AGENTS.md、~/.claude/CLAUDE.md、~/.codex/AGENTS.md のいずれかを編集・作成・削除・移動・移設・リネームする前に必ず読む。Junction 判定、ラッパー vs 実体の見分け方、新規スキル追加手順、編集後の公開（publish）手順（scripts/publish.sh による commit・push・gh アカウント切替と復帰）、公開範囲（public リポジトリに載せてよい情報・載せてはいけない情報の境界と publish-guard.sh による機械検査）、Junction 修復、典型的な壊し方の例を含む。「スキル運用」「skills 整理」「agents 定義変更」「グローバルルール変更」「スキルを公開」「.agents を push」でも必ず使う。"
---

# skill-ops — スキル・エージェント定義・グローバルルールの構造管理正本

CC × Codex 共通で運用しているスキル/エージェント/グローバルルールは、
すべて **GitHub リポジトリ `Itsuki-Ueda/Skill-Library` に正本を一本化**し、
その clone である `~/.agents/` をローカルの作業ツリーとして直接使っている。
ツール側ディレクトリ（`~/.claude/`・`~/.codex/`）は
**リンク（Junction）または薄いラッパー**だけを置く。
「1つの修正で2か所直す」を避けるための構造。**この構造を壊さないこと。**

このスキルは、その構造を維持するための検出・編集・追加・修復手順の正本。

## アーキテクチャ全体像

正本 = `https://github.com/Itsuki-Ueda/Skill-Library`（ローカルの clone が `~/.agents/`）。
`~/.agents/` の中身は**リポジトリの中身そのもの**であり、ツール側は下表のとおり参照するだけ。

| 種別 | 正本の場所（リポジトリ内） | ツール側 |
|---|---|---|
| 共通ルール | `AGENTS.md` | CC: `~/.claude/CLAUDE.md` から `@import` / Codex: `~/.codex/AGENTS.md` の参照指示 |
| 汎用スキル（git-ops, agent-team, handoff, autodev, agmsg, claude-code-subscription, skill-ops 等） | `skills/<name>/` | CC: `~/.claude/skills/<name>` Junction（agent-teamは下記CCラッパー経由） / Codex: `~/.agents/skills/` をネイティブ読取 |
| 役割規律（team-worker, team-researcher, team-code-reviewer, team-plan-reviewer, team-plan-probe） | `skills/team-*/` | CC: `agents/*.md` ラッパー / Codex: `codex/agents/*.toml` ラッパー + `codex/skills/*` ラッパー |
| CC サブエージェント定義 | `agents/*.md` | `~/.claude/agents` ディレクトリ自体が Junction |
| CC スラッシュコマンド | `commands/*.md` | `~/.claude/commands` ディレクトリ自体が Junction |
| CC 固有ルール | `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` は `@import` 2 行だけ |
| Codex カスタム Agent 定義 | `codex/agents/*.toml` | `~/.codex/agents` ディレクトリ自体が Junction |
| CC 用スキルラッパー | `claude/skills/<name>/` | agent-team: `~/.claude/skills/agent-team` をこのラッパーへ個別Junction。descriptionにトリガーを持たせ、共通本体を参照 |
| Codex 用スキルラッパー | `codex/skills/<name>/` | `~/.codex/skills/<name>` を**個別に** Junction（`.system/` は Codex 管理なので触らない） |
| Codex 固有ルール | `codex/AGENTS.md` | `~/.codex/AGENTS.md` は参照指示だけの短いファイル |
| 共通ドキュメント（codex-protocol, test-policy） | `docs/` | `~/.claude/docs` ディレクトリ自体が Junction |

`~/.claude/CLAUDE.md` の中身はこの 2 行だけであるべき:

```
@~/.agents/AGENTS.md
@~/.agents/claude/CLAUDE.md
```

## 編集前の検出（必ず実施）

`~/.claude/` `~/.codex/` 配下（skills / agents / commands のいずれも）を編集しようとする前に、
それが **Junction・ラッパー・実体のどれか**を必ず判定する。
現在は `~/.claude/skills/<X>`・`~/.claude/agents`・`~/.claude/commands`・`~/.codex/agents`・
`~/.codex/skills/<X>` が**すべて Junction**であり、実体はリポジトリ側にある。

1. **Junction 判定**（PowerShell）:
   ```powershell
   (Get-Item "$env:USERPROFILE\.claude\skills\<X>").Attributes -band [IO.FileAttributes]::ReparsePoint
   ```
   → 非ゼロならJunction。Targetを確認し、その正本を編集する。汎用は `~/.agents/skills/<X>`、agent-teamのCC側は `~/.agents/claude/skills/agent-team`、Codex側は `~/.agents/codex/skills/agent-team`。
2. **ラッパー判定**: ファイル冒頭を読み「正本を読め」「行動規律の正本」等の参照指示があればラッパー。
   → 本文は正本ファイル（`~/.agents/skills/team-*/SKILL.md` 等）にある。編集はそちらへ。
3. **実体判定**: 上記どちらでもなければ CC/Codex 専用の実体。そのまま編集してよい。
   ただし現在この扱いになるのは Codex 管理の `~/.codex/skills/.system/` くらいで、
   自分たちの定義ファイルはすべてリポジトリ側にある。
   （`~/.claude/commands/cxloop.md` は Junction 経由で実体は `~/.agents/commands/cxloop.md`）

## 編集ルール

- **Junction 経由のファイルを編集した場合、diff は `~/.agents/` 側に出る**（実体だから）。想定内。慌ててロールバックしない。
- **ラッパーに本文を書き足さない**。CC agents md / Codex toml / Codex skills wrapper は「参照 + ハーネス固有差分」だけ。
  行動規律・ワークフローの本文追加は正本（`~/.agents/skills/team-*/` や `~/.agents/skills/autodev/SKILL.md`）に書く。
- CC agents の frontmatter（`tools:`, `model:`）と Codex toml の `model`/`model_reasoning_effort`/`sandbox_mode` は
  **各形式が要求するメタデータ**なのでラッパー側に残す。これは重複ではない。
- 「ラッパーが薄いから充実させよう」と本文を書き始めない。**薄いのが正しい設計**（重複回避の主目的）。

### パス記述ルール（クラウド互換の生命線）

リポジトリ内のファイルから他のファイルを参照するときは、**必ず `~/.agents/...` で書く**。
`~/.claude/...`・`~/.codex/...`・`C:\Users\...` 等のツール側・PC 固有パスは書かない。

理由: クラウドでは `~/.agents` が Plugin 展開先へのシンボリックリンクとして用意されるので
`~/.agents/...` はローカル・クラウド両方で解決するが、`~/.claude/docs` や `~/.claude/agents`
（ローカルでは Junction、クラウドでは存在しない）や Windows 絶対パスはクラウドで必ず解決に失敗する。

例外は 2 つだけ:
- bootstrap がクラウド側に実際に作る `~/.codex/agents` / `~/.codex/skills` / `~/.codex/AGENTS.md`。
- Junction 構造そのものを説明している記述（このスキルのアーキテクチャ表・修復手順など）。

## Git 運用（この repo だけの例外）

`~/.agents/` は git リポジトリ（remote: `https://github.com/Itsuki-Ueda/Skill-Library.git`）である。
**public リポジトリ**（2026-09-07 公開。クラウドセッションが認証なしで取得するため）。書く前に「公開範囲」節を読む。
グローバルの git-ops は「main 直接コミット禁止・必ずブランチ→PR」だが、
**この repo はその例外**とし、`main` を直接編集・commit・push してよい。

理由: CC と Codex は**作業ツリーそのもの**（`~/.agents/`）を実行時に読んでいる。
ブランチを切って作業すると「ローカルで動いている内容」と「GitHub 上の main」が食い違い、
どちらが正本なのか分からなくなる。main 直編集にすることで
「ローカルの状態 = GitHub の状態」を常に一致させる。

- 編集 → `git add` → `git commit` → `git push` まで行って初めて**正本の更新が完了**する。
  commit しただけ・push し忘れは「クラウド側には反映されていない」状態なので、必ず push まで行う。
- author はリポジトリ local 設定（`Itsuki-Ueda`）。グローバル git 設定は触らない。
  gh のアクティブアカウントは publish.sh が一時的に切り替えて必ず元に戻す（手で切り替えない。後述）。

### 公開手順（publish）

**ルール: `~/.agents/` 配下（`~/.claude/skills/*` 等の Junction 経由を含む）を
1 ファイルでも編集したセッションは、作業の最後に必ず publish.sh を実行して同期済みにする。
commit だけで終わらない。**

```bash
# 公開（commit + push まで）
bash ~/.agents/skills/skill-ops/scripts/publish.sh "<type>: <日本語で変更内容>"

# 何がコミット・push されるか確認するだけ
bash ~/.agents/skills/skill-ops/scripts/publish.sh --dry-run

# 同期状態（未コミット差分 / 未 push コミット / origin との ahead-behind）だけ表示
bash ~/.agents/skills/skill-ops/scripts/publish.sh --status
```

スクリプトが自動でやること（手で組み立てない）:

1. remote が `Itsuki-Ueda/Skill-Library`、ブランチが `main`、author（local 設定）が
   `Itsuki-Ueda` であることを確認（違えば中断して案内）。
2. `core.hooksPath=.githooks` を確認し、未設定なら自動設定（clone 直後の初期化を兼ねる）。
3. gh のアクティブアカウントを `Itsuki-Ueda` に切替（push に私用 credential が要る。既定の active は仕事用）。
4. 秘密ファイル（`.env` / `*.pem` / `*.key`）の混入チェックと、`scripts/publish-guard.sh` による
   非公開情報の全文検査（「公開範囲」節。ヒットしたら中断）。
5. `git add -A` → `git commit`（pre-commit が `.codex-plugin/plugin.json` の version を自動更新）。
6. `git fetch` → `origin/main` が先行していれば `pull --rebase`（競合したら中断して案内）→ `git push`。
7. `git status -sb` で ahead/behind ゼロを確認し「公開完了: `<短縮 SHA> <メッセージ>`」を表示。
8. **終了時（成功・失敗・中断いずれでも）`trap` で gh のアカウントを元に戻す。**

`gh auth switch` を手で叩かないこと。戻し忘れると以降の**仕事用リポジトリへの push が私用名義**に
なる（あとから気づきにくい）。publish.sh は `trap` で必ず戻すので、この失敗が構造的に起きない。

差分が無い場合は commit をスキップし、未 push コミットがあれば push だけ行う。
差分も未 push も無ければ「同期済み」と表示して何もしない。

### clone 直後の初期化（一度きり）

新しいマシンや Codespaces で clone したら、次を 1 回実行する:

```bash
git -C ~/.agents config core.hooksPath .githooks
```

これで `.githooks/pre-commit`（Codex 用 version の自動更新。後述）が有効になる。
author の local 設定は `git-setup` スキルを参照。

## 公開範囲（非公開情報の境界。2026-09-07 公開化に伴い制定）

`Itsuki-Ueda/Skill-Library` は **public リポジトリ**である。push した内容は全世界に見える。
以下の境界を、機械検査（`scripts/publish-guard.sh`）と書く側の判断の両方で守る。

| 区分 | 具体例 | 扱い |
|---|---|---|
| **載せない（BLOCK）** | 実在するメールアドレス（noreply 以外）/ トークン・API キー・パスワード・秘密鍵 / 勤務先の GitHub org 名・業務リポジトリ名・案件名・顧客名・業務コードの抜粋 / 業務リポジトリのローカルパス / 個人情報 | guard がヒットしたら commit も publish も止まる。書くなら `{仕事用 org}` `{業務リポジトリA}` のように抽象化する |
| **避ける（WARN）** | この PC 固有の絶対パス（`C:\Users\...` `/c/Users/...`） | 表示のみで通す。見つけ次第 `~/.agents/...` に書き直す（パス記述ルール） |
| **載せてよい** | GitHub ユーザー名（`Itsuki-Ueda` / `itsukiueda-ourai`。プロフィールで誰でも見える）/ `users.noreply.github.com` アドレス / 汎用の手順・規律・スクリプト / ツールのバージョン・公開ドキュメントの引用 | — |

迷ったら「その 1 行を、勤務先の同僚と見知らぬ第三者の両方が読んで困るか」で決め、困るなら載せない。
**業務に固有の知見（案件名・重点確認項目・案件の癖）はこの repo ではなく、そのプロジェクトの `AGENTS.md` に書く**
（memory-ops の書き先判定。2026-09-07 に autodev の references から 1 件を実際に移した）。

### 機械検査の仕組み

- 正本: `scripts/publish-guard.sh`。`.githooks/pre-commit` が **stage 済みファイル**を、
  `scripts/publish.sh` が **追跡済み＋未追跡の全ファイル**を検査する。手動: `bash ~/.agents/skills/skill-ops/scripts/publish-guard.sh`
- 汎用パターン（メール・トークン・秘密鍵の形）はスクリプト内に持つ。
- **固有名詞のパターンは repo に置けない**（置いた瞬間に公開される）ので、
  `~/.config/skill-library/denylist.txt`（1 行 1 パターン・ERE・`#` コメント可）から読む。repo 外・PC ローカル。
- denylist が無いマシンでは警告を出して汎用検査だけ行う。新しいマシンで clone したら denylist も作る
  （中身は人間が決める。AI は他マシンの内容をチャットに転記しない）。
- **新しい固有名詞（新しい業務案件・顧客名など）が出たら、書く前に denylist に足す。** guard は
  denylist に無い新語を止められない。これが唯一の穴なので、人間側の習慣で塞ぐ。
- 誤検知（例: URL 例の `user:token@github.com/...`）はスクリプト内の許可条件で個別に外す。denylist を緩めない。

## Plugin 包装（クラウド用）

このリポジトリは Claude Code / Codex の **Plugin** としても包装してある。
ただし**ローカルには Plugin を入れない**。

- ローカルでは Junction と `@import` で `~/.agents/` を直接読んでいる。編集が即反映される。
- ここに Plugin も入れると、同じスキルが素の名前と `skill-library:<name>` の
  **二重に見える**うえ、Plugin 側は展開先キャッシュを読むので**反映が遅れる**。
- Plugin はあくまで**クラウド環境用**。クラウドには `~/.agents` が無いので、
  Plugin の SessionStart hook がそれを用意する。

### マニフェスト 4 ファイルの役割

| ファイル | 誰が読むか | 役割 |
|---|---|---|
| `.claude-plugin/plugin.json` | Claude Code | Plugin 本体の宣言。`hooks` の場所を指す。**`version` は書かない**（git source では commit SHA が version になる） |
| `.claude-plugin/marketplace.json` | Claude Code | marketplace `ueda` の定義。この repo 自身を `skill-library` として並べる |
| `.codex-plugin/plugin.json` | Codex | Codex 側の Plugin 宣言。`skills: "./skills/"` を指す。hook は付けない（Codex の hook は trust が必要なため、クラウドでの Codex 導入は CC 側 hook が代行する） |
| `.agents/plugins/marketplace.json` | Codex | Codex が git marketplace として読む場所（リポジトリ内のネストした `.agents/`） |

`skills/`・`agents/`・`commands/` はいずれも Plugin の既定ディレクトリ名なので、
**新規スキルを足してもマニフェストの編集は不要**（ディレクトリごと丸ごと含まれる）。

### `hooks/bootstrap.sh` の役割

SessionStart で走り、次を行う:

1. **ローカル判定** — `~/.agents/skills/skill-ops/SKILL.md` が実在し `~/.agents` がリンクでなければ
   ローカルと判断し、**何も出力せず終了**する（CLAUDE.md の `@import` が既に効いているので二重注入しない）。
2. クラウドなら `claude plugin update skill-library@ueda` で Plugin を最新化する（Setup script のスナップショットは
   約 7 日キャッシュされるため。反映は次セッションから）。続けて `~/.agents` を Plugin 展開先へシンボリックリンクする。
   これにより既存スキル内の `~/.agents/skills/...` という**絶対パス参照を書き換えずに済む**。
3. `~/.codex/agents/` に Agent 定義をコピーし（Codex Plugin は Agent 定義を同梱できない）、
   `~/.codex/skills/` にラッパーをリンクし、`~/.codex/AGENTS.md` を用意する。
4. `codex` CLI があれば marketplace 登録と `codex plugin add` を試みる（失敗しても続行）。
5. `AGENTS.md` + `claude/CLAUDE.md` を `additionalContext` として注入する。

### Codex 用 version の自動更新

Codex は Plugin キャッシュを `<version>` ディレクトリに持つため、
version を据え置くと内容を更新してもキャッシュの古い版が使われ続ける（openai/codex#21138）。
そこで `.githooks/pre-commit` が、コミットのたびに
`.codex-plugin/plugin.json` の `version` を `1.<YYYYMMDD(UTC)>.<UTC 0時からの経過秒>` に書き換える。
**この version を手で編集しない**（コミット時に上書きされる）。
CC 側は git source の commit SHA が version になるのでこの処理は不要。

### クラウド接続（正本: `cloud/README.md`）

クラウドでこの Plugin を使うための手順・環境設定・既知の制約は
**`~/.agents/cloud/README.md` が正本**。ここには要点だけ置く（本文を複製しない）。

- 導入経路は **環境の Setup script（`cloud/setup.sh` を貼る）だけ**。public repo なので認証なしで
  `claude plugin marketplace add` / `install` が通り、結果は環境のスナップショットに焼き込まれる
  （同じ経路の Ponytail で実証、2026-09-07）。
- **作業リポジトリ側（`.claude/settings.json`）には何も置かない。** 会社のリポジトリを触らず、同僚のセッションにも影響しない。
  スキル更新時に各プロジェクトを更新して回る必要もない（旧方式 `cloud/ensure-plugin.sh` は 2026-09-07 に廃止）。
- スナップショットは約 7 日キャッシュされるため、Plugin 自身の SessionStart hook（`hooks/bootstrap.sh`）が
  毎セッション `claude plugin update` を実行する。反映は次セッションから（遅れは最大 1 セッション）。
- Codex の認証（サブスク認証）は bootstrap が `codex login --device-auth` を自動起動し、
  認証 URL とコードを additionalContext で Claude に渡す。**人間はブラウザで承認するだけ**（毎セッション必要）。
- 導入結果の検証は `bash ~/.agents/cloud/selfcheck.sh`（OK/NG/SKIP で報告、常に exit 0）。

### 外部 Plugin: Ponytail（`DietrichGebert/ponytail`）

- **ローカル**（導入済み・2026-09-05）: CC は `claude plugin marketplace add DietrichGebert/ponytail` →
  `claude plugin install ponytail@ponytail`。Codex は `codex plugin marketplace add DietrichGebert/ponytail` →
  `codex plugin add ponytail@ponytail`。Codex 側は加えて **`codex` の `/hooks` で 3 つの hook を人間が信頼**しないと
  常時モードが動かない（スキル呼び出しは信頼なしでも可）。
- **クラウド**: `cloud/setup.sh`（CC。Setup script）と `hooks/bootstrap.sh`（Codex）が skill-library に続けて Ponytail も導入する。
  Codex hook の信頼は `codex/hooks-state.toml`（ローカルで人間が信頼した 3 エントリの複製）を bootstrap が
  `~/.codex/config.toml` に追記して再現する（案 A、承認 2026-09-05。詳細 `cloud/README.md` 5(c)）。
- 既定モードは `full`。切替は `/ponytail lite|full|ultra|off`、恒久変更は環境変数 `PONYTAIL_DEFAULT_MODE`。
- Ponytail 自体はこの repo に**取り込まない**（外部 marketplace からの install で済ませる。更新は marketplace 側に追従）。

#### Ponytail の更新と hook 信頼の同期（AI が実行。人間の手順は「/hooks で信頼」だけ）

クラウドは毎セッション新規 VM に最新の Ponytail が入る（＝更新は自動）。危ないのは、更新で hook 定義が変わり
`codex/hooks-state.toml` のハッシュと食い違うと、**クラウドの Codex 側 hook が黙って止まる**こと
（Codex 上では「Modified」扱い。スキル呼び出しは動くので気づきにくい）。検知は 2 か所で自動化してある。

- クラウド: `cloud/selfcheck.sh` [8] が導入版の hook 定義からハッシュを計算して照合（不一致 = NG）。
- ローカル: `bash ~/.agents/skills/skill-ops/scripts/ponytail-sync.sh`（不一致なら exit 1）。

| 場面 | AI がやること |
|---|---|
| 「Ponytail を更新して」と言われた / selfcheck [8] が NG | `bash ~/.agents/skills/skill-ops/scripts/ponytail-sync.sh --update`（CC: `marketplace update`＋`plugin update`、Codex: `marketplace upgrade`＋再 `add`）→ 末尾の check 結果を見る |
| check が不一致 | 人間に **「`codex` を起動して `/hooks` で Ponytail の 3 hook を信頼してください」** と依頼して待つ（ハッシュを AI が書いてはいけない。信頼の判断は人間） |
| 人間が信頼した | `ponytail-sync.sh --sync-trust`（`~/.codex/config.toml` の 3 エントリを `codex/hooks-state.toml` に複製）→ check 一致を確認 → `publish.sh` |

ハッシュ計算の正本は `~/.agents/codex/hook-hash.py`（Codex の `hook_hash` / `version_for_toml` の再現。
ローカル実値と一致確認済み 2026-09-05）。検知専用で、信頼状態の書き込みには使わない。

## 新規スキル追加の手順（厳守）

1. `~/.agents/skills/<name>/` に実体を作る（`SKILL.md` は frontmatter 付き）。
2. CC で使う場合のみ、`~/.claude/skills/<name>` から Junction を張る:
   ```powershell
   New-Item -ItemType Junction -Path "$env:USERPROFILE\.claude\skills\<name>" -Target "$env:USERPROFILE\.agents\skills\<name>"
   ```
   （管理者権限不要。ハーネス用ラッパーがあるagent-teamは対応する `~/.agents/claude/skills/agent-team` をTargetにする。共通本体も直接ロード時にラッパーを選ぶのでPlugin経路で欠落しない）
3. Codex は `~/.agents/skills/` をネイティブ読取するため Junction 不要。
4. `~/.claude/skills/<name>` / `~/.codex/skills/<name>` に**実体を直接作らない**。
   過去に発生した「知らぬ間に .agents と .claude の 2 か所に別内容ができる」問題の再発防止。
5. 編集が終わったら上記「公開手順（publish）」を実行する:
   ```bash
   bash ~/.agents/skills/skill-ops/scripts/publish.sh "feat(<name>): <日本語で変更内容>"
   ```
   push しない限りクラウド側（Plugin 経由）には反映されない。
   Plugin マニフェストの編集は不要（`skills/` ディレクトリごと Plugin に含まれる）。

## Junction 破損時の修復

`.claude/skills/<X>` を開いたら `.agents/skills/<X>` の中身が読めない場合、Junction が壊れているか消えている。
1. Junction を削除:
   ```powershell
   (Get-Item "$env:USERPROFILE\.claude\skills\<X>").Delete()
   ```
   （`Remove-Item -Recurse` を使わない。実体を消してしまう）
2. Junction を張り直す（上記「新規追加」の step 2 と同じコマンド）。

## この構造を破る典型パターン（やらないこと）

- `~/.claude/skills/git-ops/SKILL.md` を Junction と気づかず「独立ファイル」として編集する
  （実際は `~/.agents/skills/git-ops/SKILL.md` を編集している）→ 混乱の元ではないが、diff の場所を把握しておくこと。
- `~/.claude/agents/researcher.md` の本文が短いのを見て「規律が不足している」と誤解し、
  `~/.agents/skills/team-researcher/SKILL.md` の内容を CC 側 md へコピペする → **禁止**。二重管理の再来。
- 「ラッパーの参照先ファイルが存在するか確認せずに書き換える」
  → **必ず先に参照先を Read してから編集方針を決める**。
- グローバルルールを `~/.claude/CLAUDE.md` や `~/.codex/AGENTS.md` に直接書き足す
  → **どちらも参照指示だけのファイル**。共通ルールは `~/.agents/AGENTS.md`、
  ツール固有ルールは `~/.agents/claude/CLAUDE.md` / `~/.agents/codex/AGENTS.md` が正本。
- リポジトリ内の参照を `~/.claude/docs/...` や Windows 絶対パス（`C:\Users\...`）で書く
  → ローカルでは Junction で読めてもクラウドでは欠落し、参照先が読めない
  （2026-09-05 に `codex-protocol.md` で実際に発生）。参照は必ず `~/.agents/...`。
- 編集して commit だけして push を忘れる
  → ローカルは動くがクラウド（Plugin 経由）は古いまま。**push まで行って初めて完了**。
- 編集したのに publish せずセッションを終える
  → クラウド側も別マシンも古いまま。編集したセッションは必ず `scripts/publish.sh` を実行する。
- `gh auth switch` を手で叩いて仕事用アカウントに戻し忘れる
  → 以降の仕事用リポジトリへの push が私用名義になる。`scripts/publish.sh` 経由なら `trap` で必ず戻る。
- `.codex-plugin/plugin.json` の `version` を手で書き換える
  → `.githooks/pre-commit` がコミット時に上書きする。手編集は無意味。
- ローカルに `skill-library` Plugin を入れる（CLI の install も、Desktop アプリの「ローカルプラグインをアップロード」も同じ）
  → スキルが二重に見え、反映も遅れる。Plugin はクラウド専用。Desktop のアップロードは**アカウントには届かず**このPCに入るだけ（2026-09-07 実測）。
- 勤務先の固有名詞・実メールを repo に書く
  → public なので即公開。`publish-guard.sh` が止めるが、denylist に無い新語は通る。書く前に「公開範囲」を確認し denylist に足す。
- `~/.codex/skills` をディレクトリごと Junction にする
  → 中に Codex 管理の `.system/` があるため壊れる。**サブディレクトリを個別に** Junction する。
- Junction を `Remove-Item -Recurse` で消す
  → 実体（`~/.agents/` 側）まで消える。削除は `(Get-Item <path>).Delete()`。

## 大きな構造変更時のバックアップ

スキル・agents・グローバルルールの構造を変えるとき（新規スキル追加や役割規律の再編等）は、
`~/.claude/backups/skill-consolidation-<yyyymmdd>/` に対象ディレクトリ丸ごとバックアップを取る。
過去バックアップ例:
- `~/.claude/backups/skill-consolidation-20260720/`（`~/.agents` への統合実施時、155 ファイル）
- `~/.claude/backups/skill-consolidation-20260905/`（リポジトリ化・Plugin 包装時、26 ファイル）
