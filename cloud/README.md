# クラウド接続ガイド（Claude Code on the web / Cloud Environments）

ローカルの `~/.agents` に置いてあるスキル・エージェント定義・グローバルルール一式を、
**claude.ai/code のクラウドセッションでもそのまま使えるようにする**ための手順書です。

> **このリポジトリは public です（2026-09-07 公開）。** 書く前に skill-ops「公開範囲」節を読み、
> 勤務先の固有名詞は `{仕事用 org}` `{業務リポジトリA}` のように抽象化してください。

---

## 1. 目的と全体像

正本は GitHub の `Itsuki-Ueda/Skill-Library` リポジトリ 1 つだけです。
ローカルとクラウドで、そこへの届き方が違うだけ、と考えてください。

| 環境 | スキルの届き方 | Plugin |
|---|---|---|
| ローカル（このPC） | `~/.agents` がリポジトリの clone そのもの。`~/.claude/skills/*` は Junction、`~/.claude/CLAUDE.md` は `@import` で直読み | **入れない**（入れると同じスキルが二重に見え、反映も遅れる） |
| クラウド（claude.ai/code） | `~/.agents` が存在しないので、**Plugin** としてリポジトリを取得し、Plugin の SessionStart hook が `~/.agents` を用意する | **使う** |

### クラウドで Plugin が入る仕組み（2026-09-07 決定・実証済み）

導入経路は **環境（Environment）の Setup script だけ**です。作業リポジトリ側には何も置きません。

1. 環境の Setup script（`cloud/setup.sh` の中身）が、環境の初回起動時に
   `claude plugin marketplace add Itsuki-Ueda/Skill-Library` → `claude plugin install skill-library@ueda`
   （続けて Ponytail も）を実行する。**public リポジトリなので認証は不要**。
   結果は環境のファイルシステム・スナップショットに焼き込まれ、約 7 日間キャッシュされる。
2. 以後のセッションはそのスナップショットから起動するので、最初から Plugin が入っている。
   Plugin 自身の SessionStart hook（`hooks/bootstrap.sh`）がセッション開始時に走る
   （同じ経路の Ponytail で `PONYTAIL MODE ACTIVE` が出ることを実測済み）。
3. bootstrap は最初に `claude plugin update skill-library@ueda` を実行して Plugin を最新化する
   （反映は次セッションから。遅れは最大 1 セッション）。続けて `~/.agents` のリンク、Codex 側の配置、
   共通ルールの additionalContext 注入を行う。

この方式を選んだ理由（他の案は §5(a) で実測により否定）:

- **作業リポジトリを触らない**。会社のリポジトリに個人設定を持ち込まず、同僚のセッションに影響しない。
- **スキル更新時に各プロジェクトを更新して回らない**。`publish.sh` で push すれば、次のセッションから全環境に届く。
- Codex 側も同じ bootstrap が整えるので、CC・Codex 両方に届く。

---

## 2. 植田さんが手で行うこと（AI では代行できません）

### 手順 1: GitHub 連携でリポジトリへのアクセスを許可する

claude.ai/code の GitHub 連携設定で、今後クラウドで作業する**各プロジェクトのリポジトリ**にアクセス権を与えます。
`Skill-Library` 自体は public なので許可は不要です。

### 手順 2: 環境（Environment）に Setup script を設定する

claude.ai/code で環境を新規作成するか、既存の環境を編集して、次を設定します。

| 項目 | 設定値 |
|---|---|
| Network access | `Full`（または Custom network access で OpenAI のドメインを許可）。既定の `Trusted` には OpenAI が含まれず、Codex の認証が通りません |
| Setup script | `cloud/setup.sh` の**中身をそのまま貼り付け** |
| 環境変数 | **トークンを置かない**（この環境を使う全ユーザーに表示されるため）。秘密でない値のみ |
| API認証情報 | **不要**（public 化により GitHub の認証が要らなくなった。過去に登録した Skill-Library 用のエントリは削除してよい） |

Setup script の注意点:

- root ユーザー・Ubuntu 24.04 で実行されます。
- **初回だけ実行され、結果は約 7 日間キャッシュ**されます。スクリプトの内容を変える（コメント 1 行でも）と再実行されます。
- 制限時間は 5 分。**終了コードが 0 以外だとセッションの起動そのものが失敗**します。
  `cloud/setup.sh` は全コマンドを `|| true` で受け、最後に `exit 0` してあります。

### 手順 3: 検証用のクラウドセッションを開く

任意のリポジトリ（仕事用でよい）を対象にクラウドセッションを開き、次のプロンプトを貼り付けます。

```
`bash ~/.agents/cloud/selfcheck.sh` を実行し、出力をそのまま報告してください
```

`~/.agents` は bootstrap が用意するリンクです。無ければ bootstrap が動いていないので、
代わりに `ls ~/.claude/plugins/cache/ueda/skill-library/` の結果を報告してもらってください。

### 手順 4: 出力をローカルの Claude に貼り戻す

`selfcheck.sh` は各項目を `OK` / `NG` / `SKIP` の 1 行ずつで出力し、最後に NG 件数を表示します。
その出力をそのままローカルセッションに貼ってください。NG が出ていれば原因を切り分けます。

### 手順 5: セッション開始時に Codex の認証を承認する（毎セッション）

クラウドは毎回まっさらな VM なので `~/.codex/auth.json` が残らず、Codex は毎セッション未認証で始まります。
bootstrap が `codex login --device-auth` を自動で起動するので、
**Claude が最初の返答で提示する認証 URL とワンタイムコードを、ブラウザで開いて承認してください。**
ChatGPT アカウントによる**サブスク認証**です（API キーは使いません）。

---

## 3. 他のプロジェクトでクラウドを使うときの手順

**何もしません。** 同じ環境（Setup script 設定済み）を選んでセッションを開くだけです。
そのプロジェクトのリポジトリに `.claude/settings.json` を置く必要はありません（2026-09-07 に旧方式を廃止）。

---

## 3.5 Codex クラウドの環境を新しく作るときの手順（毎回・リポジトリごと）

Codex クラウドの環境はリポジトリ単位で、Secret も環境単位（Codex 公式仕様、2026-09-12 確認）。
環境を作るたびに次を行う。所要 5 分。

1. **環境を作成**: chatgpt.com/codex の Environments で対象リポジトリを選んで作成。
2. **Setup script** に [`cloud/codex-setup.sh`](codex-setup.sh) の全文を貼る。
3. **Maintenance script** に [`cloud/codex-maintenance.sh`](codex-maintenance.sh) の全文を貼る。
4. **Secret（任意）**: この環境から Claude Code を呼ばせたいときだけ `CC_SUBSCRIPTION_TOKEN` を登録する。
   値は手元の端末で `claude setup-token` を実行して最後に表示されるトークン（`sk-ant-oat01-` で始まる）。
   末尾改行なし。**同じトークンを全環境で使い回してよい**（1 年有効。期限は `codex-setup.sh` の `CLAUDE_TOKEN_ISSUED` が管理）。
   登録しない環境はスキル配置だけで正常に動く。
5. **エージェント実行中のネットワーク許可**（Secret を登録した環境のみ必要）: 次の 4 ドメインを POST 込みで許可する。
   `api.anthropic.com` / `claude.ai` / `claude.com` / `platform.claude.com`
6. **保存して初回セットアップを実行**し、ログ末尾を確認する:
   - `CODEX_CLOUD_SETUP_OK claude_linked=1` … Claude 連携あり
   - `CODEX_CLOUD_SETUP_OK claude_linked=0` … スキル配置のみ（Secret 未登録）
   - `codex cloud setup: ...` で止まる … メッセージのとおりに直す（Secret の形式・日付など）
7. **動作確認**（任意）: その環境でタスクを開き、次を貼る。
   ```
   ~/.agents/skills の一覧と、python3 ~/.agents/cloud/cc-subscription-call.py --check の結果をそのまま報告してください
   ```
   Secret ありなら `{"exit_code": 0, "ok_exact": true}`、なしなら `CLAUDE_SUBSCRIPTION_CALL_FAILED` が期待値。

**トークンの期限が来たら**（Setup / Maintenance が 30 日前から警告を出す）:
`claude setup-token` で再発行 → Secret を登録した**全環境**で値を差し替え → `codex-setup.sh` の `CLAUDE_TOKEN_ISSUED` を更新して publish。
Secret を変えるとその環境のキャッシュは無効化され、次回タスクで Setup が再実行される。

---

## 4. 期待される挙動（クラウドセッション開始時に何が起きるか）

1. スナップショットから VM が起動する。Plugin は `~/.claude/plugins/cache/ueda/skill-library/{commit SHA}/` に展開済み。
2. Plugin の SessionStart hook として `hooks/bootstrap.sh` が走り、次を行う。
   - `claude plugin update skill-library@ueda`（および Ponytail）で最新化（反映は次セッション）
   - `~/.agents` を Plugin 展開先へシンボリックリンク
     （既存スキル内の `~/.agents/skills/...` という絶対パス参照をそのまま動かすため）
   - `~/.codex/agents/` に Codex 用 Agent 定義（`*.toml`）をコピー、`~/.codex/skills/` にラッパーをリンク、`~/.codex/AGENTS.md` を作成
   - `codex` CLI があれば Codex 側にも marketplace 登録と Plugin 導入を試みる（skill-library・Ponytail。失敗しても続行）
   - Codex が未認証なら `codex login --device-auth` をバックグラウンド起動し、URL とコードを `additionalContext` に載せる
   - `AGENTS.md` と `claude/CLAUDE.md` を `additionalContext` として注入
3. Ponytail 自身の SessionStart hook も走り、`PONYTAIL MODE ACTIVE` が出る。
4. クラウドの Claude からはスキルが `skill-library:{スキル名}`、サブエージェントが `skill-library:{名前}` の名前空間付きで見える。

クラウドでは環境変数 `CLAUDE_CODE_REMOTE=true` が立ちます。bootstrap の Plugin 更新はこの変数が立つときだけ動きます。

---

## 5. 既知の制約 / 決着した事項

### (a) private のままではクラウドから取得できない — **public 化で決着（2026-09-07）**

private だった期間に実測で判明した制約（すべて 2026-09-07 の実機観測）:

- クラウドセッションの GitHub 到達範囲は**プロキシが持つセッション単位の許可リスト**で決まる。
  セッションに attach したリポジトリ以外は、所有者・コラボレーター権限・GitHub 連携の許可に関係なく
  `could not read Username` で失敗する。許可外は GitHub ではなく**プロキシが 403** を返す。
- セッションの GitHub 実体は claude.ai に接続したアカウント（`curl https://api.github.com/user` で確認可）。
- **API認証情報に PAT を登録しても github.com では効かない**（プロキシ自身の資格情報が優先される）。
- `add_repo` は v1 では**オーナーをまたぐ追加に非対応**（`cross-tier adds are not supported in v1`）。
  仕事用 org のセッションから個人アカウントのリポジトリは追加できない。
- Desktop アプリの「ローカルプラグインをアップロード」は**このPCにインストールするだけ**でアカウントには届かない
  （`known_marketplaces.json` に `source: directory` で登録される。公式: "plugins you install from the desktop app
  aren't available for cloud sessions" — code.claude.com/docs/en/desktop）。
  アカウント経由の「同期プラグイン」は Team / Enterprise の Organization settings からしか投入できない。
- アカウント経由の**スキル**（Customize → スキル）はクラウドに届くが、更新のたびに ZIP を手動アップロードする必要があり、
  Codex には届かない。

検討して**採らなかった**案: 仕事用 org へのミラー（毎セッション `add_repo` と承認が要る）、
作業リポジトリごとの `.claude/settings.json`（スキル更新のたびに全プロジェクトを更新して回る）、
アカウントスキルへの個別アップロード（手動更新・Codex 非対応）。

**採用: public 化。** 公開前に秘密情報（トークン・鍵）が皆無であることを全履歴で確認し、
勤務先の固有名詞・実メールを除去し、再混入を `skills/skill-ops/scripts/publish-guard.sh`（pre-commit と publish.sh）で機械的に止める。

### (b) Codex の認証は device-auth を hook が自動起動し、承認だけ人間が行う

インストールと Plugin 配置に加えて、**認証の開始まで hook が自動化済み**です。
未認証なら SessionStart hook が `codex login --device-auth` をバックグラウンド起動し、
認証 URL とワンタイムコードを Claude に渡します。植田さんは**ブラウザで承認するだけ**です
（サブスク認証。API キーは使いません）。

前提となる制約:

- ネットワーク設定は **`Full`**（または Custom network access で OpenAI のドメインを許可）が必要。
  既定の `Trusted` には **OpenAI のドメインが含まれない**ため、認証も Codex 実行も通りません。
- 認証は**毎セッション必要**です（新規 VM のため `~/.codex/auth.json` が残らない）。
- ワンタイムコードには有効期限があります。期限切れになったら Claude に
  `codex login --device-auth` を再実行させ、新しいコードを出してもらってください。

### (c) Codex 側の Ponytail hook は「信頼」がないと動かない

Codex は Plugin 由来の hook を、人間が `codex` の `/hooks` 画面で「信頼」するまで実行しません。
信頼した結果は `~/.codex/config.toml` に次の形で保存されます（キーは Plugin 名と相対パス、値は hook 定義内容のハッシュ）。

```toml
[hooks.state.'ponytail@ponytail:hooks/claude-codex-hooks.json:session_start:0:0']
trusted_hash = "sha256:{ハッシュ値}"
```

- ハッシュは **hook の定義内容（イベント・matcher・コマンド文字列・timeout・statusMessage）だけから計算され、
  インストール先のパスや OS に依存しません**（Codex ソース `codex-rs/hooks/src/engine/discovery.rs` の
  `hook_hash` と `codex-rs/config/src/fingerprint.rs` の `version_for_toml` を確認済み。
  ローカル既存 hook の値を同じ手順で再現できました）。
  つまり **ローカルで一度信頼した 3 エントリは、クラウドの `config.toml` にそのまま書けば有効**です。
- クラウドは毎セッション新規 VM なので、書かなければ毎回「未信頼」から始まります。
  未信頼でも `/ponytail`・`/ponytail-review` 等の**スキルは使えます**。動かないのは
  「毎ターン自動でルールを注入する常時モード」だけです。

**採用: 案 A**（植田さん承認 2026-09-05）。ローカルで `/hooks` から信頼した 3 エントリを
`codex/hooks-state.toml` に置き、bootstrap がクラウドの `~/.codex/config.toml` に未登録なら追記します。
ローカルの実値と、定義内容から独立に計算した値が 3 件とも一致することを確認済みです。
Ponytail が hook 定義を更新するとハッシュが変わり Codex 上で「Modified」になるため、
その時はローカルで再信頼して `codex/hooks-state.toml` を差し替えます。検討した選択肢:

| 案 | 内容 | 長所 / 短所 |
|---|---|---|
| A | ローカルで `/hooks` から信頼したあと、その 3 エントリを `codex/hooks-state.toml` として repo に置き、bootstrap が `~/.codex/config.toml` に追記する | 常時モードがクラウドでも動く / Codex の「人間が hook を確認する」安全確認を repo 側で肩代わりする |
| B | 何もしない（現状） | 安全確認をそのまま尊重 / クラウドの Codex では常時モードなし（スキル呼び出しは可） |
| C | `codex exec --dangerously-bypass-hook-trust` を毎回付ける | 名前どおり全 hook の確認を外すため**非推奨** |

Claude Code 側の Ponytail hook にはこの信頼確認はありません。Setup script でスナップショットに入れてあるので、
Ponytail 自身の SessionStart hook がセッション開始時に走ります（2026-09-07 実測: `PONYTAIL MODE ACTIVE`）。

### (d) Setup script のキャッシュ周期

Setup script の結果は約 7 日キャッシュされるため、**Codex CLI のバージョン更新もその周期**になります。
すぐ更新したい場合は、Setup script の内容を少し変えて（コメント追加など）保存し直すと再実行されます。

---

## 6. 変更をクラウドへ反映する流れ

```
ローカルで ~/.agents 配下を編集
  ↓
bash ~/.agents/skills/skill-ops/scripts/publish.sh "<type>: <変更内容>"
  （publish-guard が非公開情報を検査 → commit → push）
  ↓
次のクラウドセッション開始時に bootstrap が `claude plugin update` で取得
  ↓
そのさらに次のセッションから新しい版で動く（遅れは最大 1 セッション）
```

**push しない限りクラウドには何も届きません。** commit だけで終えないこと。
すぐに反映したい場合は、Setup script を少し変えて保存し直すとスナップショットが作り直されます。

---

## 7. ファイル一覧

| ファイル | 役割 |
|---|---|
| `cloud/setup.sh` | claude.ai/code の環境設定「Setup script」欄に貼る内容。**Plugin 導入の唯一の経路** |
| `cloud/codex-setup.sh` | Codex クラウド環境の「Setup script」欄に貼る内容。Skill-Library 配置・CLI 導入・（Secret があれば）Claude 認証ファイル生成と期限チェック |
| `cloud/codex-maintenance.sh` | Codex クラウド環境の「Maintenance script」欄に貼る内容。キャッシュ再開時に codex-setup.sh --maintenance を呼ぶ |
| `cloud/cc-subscription-call.py` | Codex クラウド（Linux）から Claude Code をサブスク認証で呼ぶ唯一の経路（`--check` / `<prompt-file>`） |
| `cloud/selfcheck.sh` | クラウドセッション内で走らせる自己診断（OK/NG/SKIP、常に exit 0） |
| `cloud/README.md` | このファイル |
| `hooks/bootstrap.sh` | Plugin の SessionStart hook。Plugin 更新と、クラウドで `~/.agents` 等を用意する本体 |
| `codex/hooks-state.toml` | Ponytail の Codex hook 信頼エントリ（ローカルで人間が信頼した結果の複製）。bootstrap が投入 |
| `codex/hook-hash.py` | Codex の hook 信頼ハッシュを hook 定義から計算（検知専用）。selfcheck [8] と `skill-ops/scripts/ponytail-sync.sh` が使う |
| `skills/skill-ops/scripts/publish-guard.sh` | 非公開情報の混入検査（public repo の防衛線）。pre-commit と publish.sh から呼ばれる |

廃止（2026-09-07）: `cloud/ensure-plugin.sh`・`cloud/render-settings.sh`・リポジトリの `.claude/settings.json`
（作業リポジトリ側に設定を置く旧方式）。

---

## 8. 検証ログ

- **2026-09-05 / クラウド Claude Code `2.1.261`（`/opt/claude-code/bin/claude`、Ubuntu、`CLAUDE_CODE_REMOTE=true`）で実機確認。**
- `.claude/settings.json` の `extraKnownMarketplaces` / `enabledPlugins` 宣言**だけでは Plugin は入らなかった**
  （公式記述と一致。Claude Code v2.1.195 以降、外部ソースの Plugin は宣言では install されない）。
- VM 内で `claude plugin marketplace add Itsuki-Ueda/Skill-Library` と
  `claude plugin install skill-library@ueda` を手動実行すると**両方成功**。private repo だが
  **トークン設定は不要**だった。
  ⚠️ **ただしこれは Skill-Library 自身を対象にしたセッションでの結果**であり、
  他リポジトリのセッションには一般化できない（2026-09-07 の再検証で判明。§5(a) 参照）。
- **2026-09-07 / 仕事用リポジトリ（`{仕事用 org}/{業務リポジトリA}`）を対象にしたクラウドセッションで再検証。**
  素の `git` に資格情報が渡るのは **attach 済みリポジトリだけ**と確定。
  同一 org・push 権限あり・連携許可済みの別リポジトリ（`{仕事用 org}/{業務リポジトリB}`）でも
  `could not read Username` で失敗した。`Itsuki-Ueda/Skill-Library` に read コラボレーターを
  追加しても結果は変わらず（コラボレーター方式・ミラー方式はいずれも無効と判明）。
  MCP 経由の GitHub ツールには org 全体の資格情報が通っており、シェルの `git` とは到達範囲が異なる。
- インストール後、**同一セッション内で Plugin が有効化**され（スキル 16 件・エージェント 4 件を認識）、
  Plugin の SessionStart hook（`hooks/bootstrap.sh`）も実行された。
- 環境の事実: リポジトリは `/home/user/{リポジトリ名}` に clone。`$CLAUDE_PROJECT_DIR` は
  **hook 実行時のみ設定**され通常シェルでは空。`jq` / `python3` / `node` はいずれも利用可能。
- **2026-09-05 / クラウドで `~/.claude/docs/codex-protocol.md` の欠落を検出**（ローカルの `~/.claude/docs/` にだけ存在しリポジトリ未収録だったため）。`docs/codex-protocol.md` としてリポジトリへ移設し、参照を全て `~/.agents/...` に統一して解消。
- **2026-09-07 / Desktop アプリの「ローカルプラグインをアップロード」で skill-library を登録 → 仕事用リポジトリのクラウドセッションで検証。**
  `~/.claude/plugins/synced/` は空のバケットのみで Plugin は届かず。ローカル側は `known_marketplaces.json` に
  `local-desktop-app-uploads`（`source: directory`）として登録されていた＝ローカルインストール。公式ドキュメントと一致。
  一方、同じ画面から登録したアカウント**スキル**（`git-ops`）は 2 回とも届いた。
- **2026-09-07 / Setup script 経由の Ponytail（public repo）は仕事用リポジトリのセッションでも動作**
  （`PONYTAIL MODE ACTIVE` が SessionStart で出力、`ponytail:` スキルが一覧に出た）。public なら Setup script で導入できる根拠。
- **2026-09-07 / public 化（履歴を 1 commit `d80f166` に squash）→ Setup script 貼り直し → 仕事用リポジトリのクラウドセッションで `selfcheck.sh` 全項目 OK。**
  Plugin 版 `d80f166477c3`、`~/.agents` は Plugin キャッシュへの symlink、スキル 15 件、Codex 側 7 件、Ponytail 常時モード。
  唯一の NG は Codex device-auth（人間のブラウザ承認が毎環境で必要。仕様どおり）。本方式の成立を確認。
