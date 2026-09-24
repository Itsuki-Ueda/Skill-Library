# Codex CLI 呼び出しの正本プロトコル

`/cxplan`・`/cxloop`・`/autodev` から参照される、OpenAI Codex CLI 呼び出しの唯一の正本。
Codex コマンドの具体構文はこのファイルにだけ書く。各スキルは「プロトコルの◯◯形で」と参照する。

## 1. モデル / effort
- **決定権の優先順位（最重要）**: model / effort は**呼び出し側が決定する**。
  1. 呼び出し側に**ルーティング設定がある場合**（例: `/agent-team` の team.yaml → defaults.yaml）は
     **その値が正**であり、本節の既定・段階制は**一切適用しない**。model も effort も上書き対象。
     本節が効くのは、ルーティング設定でキーが未定義に落ちた場合の最終フォールバックだけ。
  2. 呼び出し側が値を持たない場合（`/autodev`・`/cxplan`・`/cxloop`）のみ、以下の既定を使う。
- 既定 `model=gpt-6-sol`（2026-09-23 更新。CLI 0.156.1 のカタログで slug 実在と呼び出し成功を確認済み）。
  **slug は完全一致**——`gpt-6` のような省略名はエラーになる。**採用した値**（呼び出し側設定 or 本節）を
  逐語コピーして使い、記憶から組み立てない。
- **effort は段階制**: 初回レビュー = `high`、再レビュー（resume）= `medium`。
- 実装形（3d）は**全ラウンド `medium`**（初回・修正差し戻しとも）。
- 呼び出し側スキルの引数・設定で `effort` が明示された場合は、全ラウンドその値で固定（段階制を無効化）。
- **値を持たない呼び出し側（autodev / cxplan / cxloop）は、本節の既定値をスキル側に重複記載しない**
  （更新漏れの温床）。ルーティング設定を持つ呼び出し側（agent-team 等）は自分の設定ファイルが値の正本。
- すべての呼び出しに `-c 'model=<model>' -c 'model_reasoning_effort=<effort>'` を必ず付与する
  （`~/.codex/config.toml` の設定に左右されないため）。PowerShell では `key=value` 全体をシングルクオートで囲む。

## 2. 実行シェル
- codex 呼び出しは**必ず PowerShell ツールで実行**する。
- stdin パイプ構文 `"<prompt>" | codex exec ...` は PowerShell 前提。Bash ツールでは文字列がコマンド解釈されて壊れる。
- 例外: `~/.agents/skills/agent-team/scripts/cx-run.sh` はプロンプトをファイルから stdin に渡し、§3 の各形と同じ引数を組み立てるので Bash ツールで実行してよい。

## 3. 呼び出し形
### (a) 文書レビュー（初回）
プロンプトは **stdin** で渡す（引数で渡すと stdin 待ちでハングする＝実証済み）。
```
"<プロンプト全文>" | codex exec -s read-only -o <out> -c 'model=<model>' -c 'model_reasoning_effort=<effort>'
```
- レビュー・調査の形（a〜c）は必ず `-s read-only` を付ける。指定しないと `~/.codex/config.toml` の既定（workspace-write＝書き込み可）で動き、レビュアーが対象を書き換えられる。

### (b) 差分レビュー（初回）
`review` は stdin 待ちなし。**カスタムプロンプト不可**（組み込みレビュー指示で動く）。
```
codex exec -s read-only -o <out> review <--uncommitted | --base origin/main | --commit <sha>> -c 'model=<model>' -c 'model_reasoning_effort=<effort>'
```
（トップレベル `codex review` には `-o` が無いので `exec` 配下を使う）

### (c) 再レビュー（resume）
`resume` はプロンプトを**引数で渡してよい**（stdin 待ちは起きない）。`-o` も併用する。
```
codex exec -s read-only resume <session id> -o <out> -c 'model=<model>' -c 'model_reasoning_effort=<effort>' "<プロンプト>"
```
- **`-s read-only` を必ず付ける**（`exec` と `resume` の間）。resume は元のセッションの sandbox を引き継がず、
  指定しないと `~/.codex/config.toml` の既定（workspace-write＝書き込み可）で動く（2026-09-24 実測、0.156.1）。
- 対象リポジトリの中から呼ぶ（git リポジトリの外では `Not inside a trusted directory` で拒否される）。

### (d) 実装（サンドボックス内で Codex に書かせる）
実装指示（§8c 雛形＋仕様全文）は **stdin** で渡す。sandbox は必ず `workspace-write`、対象 worktree に `-C` で固定。
```
"<実装指示全文>" | codex exec -s workspace-write -C <worktree絶対パス> -o <out> -c 'model=<model>' -c 'model_reasoning_effort=<effort>' 2><err>; echo $? > <out>.exit
```
- **禁止フラグ**: `--dangerously-bypass-approvals-and-sandbox` / `--ignore-rules` / `--add-dir`。
- 実装は 10 分（PowerShell ツール上限）を超え得る → **`run_in_background` で起動し、完了後に `<out>` を読む**。
  session id は `<err>`（stderr リダイレクト先）のヘッダから回収する。
- `<out>.exit` は起動元以外（交代後のexecutor等）が完了と終了コードを判定するためのファイル。`-o` は正常完了時にプロセス終了直前に1回だけ書かれ、起動直後の失敗では作られない（2026-09-22 実測、0.153.4）。PowerShellから起動する場合は `$?` ではなく `$LASTEXITCODE` を書く。
- **修正の差し戻しは (c) resume 形に sandbox 指定を付けて行う**（引き継がれる保証がないため毎回明示）。
  **フラグの位置に注意（2026-07-03 実測）**: `-s`/`-C` は `exec` と `resume` の**間**に置く。
  `codex exec -s workspace-write -C <worktree> resume <session id> -o <out> -c ... "<プロンプト>"`
  （`codex exec resume ... -s ...` は `error: unexpected argument '-s'` で失敗する）。
- 実装委託の規律は §13 を必ず併読。

### (e) restricted sandbox（workspace-write）の既知の制限（Windows・2026-09-24 実測、codex-cli 0.156.1）
症状 → 対処。準備（依存の取得・復元など通信やユーザー領域が要るもの）は親が dispatch 前に済ませる。
- 作業場所内の `.agents/`・`.git` への書き込みが拒否される → 成果物（撮影画像等）は `%TEMP%` 配下へ出す（`%TEMP%` は書込可）。
- 外部ネットワークに出られない（localhost は可）→ 依存の取得（`npm ci` / `dotnet restore` 等）は親が行う。外部サービスのデータが要る画面確認は親が行う。
- `%USERPROFILE%` 直下の一覧と、`%APPDATA%`・`%LOCALAPPDATA%`（Temp を除く）の読み取りが拒否される。その結果:
  - ユーザー単位インストールのツール（`%LOCALAPPDATA%\Programs` 配下の Python 等）が見つからない → Program Files 配下のツールを使うか、親が実行する。
  - 古い esbuild 系の設定読込（例: Vite 7）が親フォルダを辿って `Cannot read directory "../../..": Access is denied` で止まる → 依存をロックファイルどおりに入れ直す（Vite 8 系では再現しない）。
  - `dotnet test` / `dotnet build` の暗黙復元が `%APPDATA%\NuGet\NuGet.Config` を読めず失敗する → 親が `dotnet restore` を済ませ、worker は `--no-restore` を付ける。
  - WPF 等 Windows デスクトップのビルドが `%LOCALAPPDATA%\Microsoft SDKs` を読めず `MSB4184` で失敗する → そのビルドは親が実行する（ライブラリ・テストプロジェクト単体は `--no-restore` で通る）。
- sandbox 内で起動したプロセスは、sandbox 外の権限では止められない（アクセス拒否）。sandbox 内でも `taskkill /T` と WMI での子孫探索は効かない → 同じ sandbox から `Stop-Process -Id <PID>` で止める（PID は `netstat -ano`）。開発サーバは常駐させず、起動から停止まで行うスクリプト（agent-team の `capture.sh`）に任せる。
- sandbox 内で Chromium 系ブラウザを起動すると子プロセスが落ちる → `--no-sandbox` を付ける（開くのは localhost のみ）。

## 4. timeout
- 全呼び出し **600000ms**（PowerShell ツール上限）。高 effort のレビューは 1 回 2〜5 分が実測（gpt-5.5 xhigh 時）。300s では不足する。
- 実装形（3d）はこの上限を超え得るため timeout に依存せず `run_in_background` を使う（3d 参照）。

## 5. 出力の読み方
- 最終結論は **`-o <file>`（`--output-last-message`）のファイルだけを読む**。
- **session id はコンソール出力ヘッダ（ストリームとしては stderr 側）の `session id:` 行からのみ取得**する（`-o` には入らない）。
  stderr をファイルへリダイレクトした場合はそのファイルから回収する。
- `<out>` はそのセッションの scratchpad ディレクトリに置く。
- `<out>` は**ラウンド別のファイル名**にする（例 `review-r1.txt`, `review-r2.txt`）。上書きすると監査性が落ちる。
- 事実（2026-07-02 実測・3呼び出し形で確認）: codex は **stdout=最終メッセージのみ / stderr=ヘッダ＋作業ログ
  （session id 含む）** に分離して出力する。出力が巨大になるのは `2>&1` で両者を混ぜた場合だけ。
  それでも `-o` を正とするのは、**公式フラグとして最終メッセージの完全取得が保証される**ため（stdout の
  クリーンさは観察ベースの挙動で、将来変わりうる）。
- **混合ストリームの末尾切り（`tail` 等）で結論を取ってはならない**——VERDICT は最終メッセージの**先頭**に
  来るため、指摘が多い長い結論では VERDICT と上位指摘が切り落とされる（旧方式の実害リスク）。

## 6. 失敗時ハンドリング
- (a) exit≠0 または `-o` 未生成/空 → 標準出力末尾を確認し **1 回だけ再実行** → なお失敗なら**中断して人間に報告**。
- (b) session id が取得できない → 1 回再実行 → ダメなら以後 resume を諦め、再レビューは
  **新規セッション（文書レビュー形）＋前回指摘をプロンプトに含めて代替**する。
- (c) resume 対象セッション不存在エラー → 同じく**新規セッション代替**（前回指摘をプロンプトに含める）。
- (d) usage limit / quota 系エラー（Codex サブスク枠切れ）→ 再実行しても無駄なので、**リトライせず即中断して人間に報告**。
- (e) モデル不存在系エラー → 推測で別名を試さず、`codex debug models` でカタログの slug を確認して正す
  （§1 と食い違っていたら §1 が古い可能性——人間に報告して §1 を更新する）。

## 7. 重大度タグとマッピング規則
- **P0**=致命（セキュリティ / データ破壊 / 確実な障害）、**P1**=重大、**P2**=中、**P3**=軽微（対応任意）。
- 文書レビュー・再レビューのプロンプトでは次を課す:
  「先頭に `VERDICT: pass|fail`（P0〜P2 相当が 1 件でもあれば fail）。指摘は `[P0]`〜`[P3]` タグ＋箇所付きで。無ければ『指摘なし』と明記。」
- **差分レビュー（review）は組み込みプロンプトのためタグ体系を課せない** → タグ無し・別語彙（major/minor 等）の
  指摘が返ったら、内容から P0〜P3 を自分で判定して扱う。
  **「タグが無い＝指摘ゼロ＝合格」と誤読してはならない。**
- VERDICT とタグが矛盾する場合（例: fail だが P3 のみ）は**タグ（P0〜P2 の有無）を正**とする。

## 8. レビュープロンプト雛形

### 8a. 初回文書レビュー雛形
> 次のプラン文書をレビュー。観点: 実現可能性 / 抜け漏れ / 前提の誤り / リスク・副作用 / より良い代替案。
> 先頭に `VERDICT: pass|fail`（P0〜P2 相当が1件でもあれば fail）。指摘は `[P0]`/`[P1]`/`[P2]`/`[P3]` タグ＋
> 箇所（見出し/行）付きで簡潔に。無ければ『指摘なし』と明記。対象を読んで評価: `<abs path>`

### 8b. 再レビュー雛形（ファイル再読指示込み）
> 対象ファイルを**再読した上で**（差分レビューなら「現在の差分を見直した上で」）、次の2点を**独立に**評価:
> ① 前回指摘への対処が十分か。
> ② **修正によって新たに入り込んだ問題（新規バグ・リグレッション・副作用）が無いか**
> —— 前回指摘の追跡だけに引きずられず、修正箇所とその影響範囲を新しい目で点検すること。
> 残る問題を `[P0]`/`[P1]`/`[P2]`/`[P3]` と箇所付きで簡潔に。先頭に `VERDICT: pass|fail`。無ければ『指摘なし』と明記。

### 8c. 実装依頼雛形（実装形 3d の stdin に渡す）
> あなたは実装者。以下の仕様に従い、このリポジトリのコードを修正せよ。
> **仕様の「完了条件」（受け入れ条件）をすべて満たすまでやり切ること。**
> 満たせない条件が残る場合は、諦めた条件とその理由を残課題に明記して返す（黙って省略しない）。
> 制約: 仕様の対象ファイルに閉じる / git commit・push はするな（親の担当）/
> 所定のrestricted sandboxではネットワーク等が制限される。実行先の権限を迂回しない / 対象コードにメタコメントを入れない /
> テストを書くのは仕様に列挙されている場合だけ（勝手に追加しない。書き方は仕様内のテスト方針と、
> テスト方針正本 `~/.agents/docs/test-policy.md`（プロジェクトに `tests/README.md` 等があればそちら優先）に従う。
> 仕様に変異リストがあれば各変異を実際に当てて対応テストが落ちることを確認し、証跡を報告する）/
> 範囲内の命名・既存パターンは自分で選ぶ。要求・公開API・データ・セキュリティ・担当範囲など仕様の前提を変える判断では停止し、最終メッセージの先頭で
> `NEED-DECISION: <判断が必要な内容>` を返す。
> 完了したら最終メッセージに: 変更ファイル一覧（絶対パス）/ 変更概要 / 自己検証の結果（実行したコマンドと結果。実行不可なら理由）/ 残課題。
> ---
> <仕様書（プラン文書）全文。軽量パスではタスク内容＋対象ファイル＋完了条件>
- `NEED-DECISION` が返ったら呼び出し側が判断を解決し（プラン・既存決定から自答できない設計判断だけ人間に確認）、
  resume（sandbox 指定込み＝3d）で回答を差し戻す。

## 9. base 基準
- git worktree 運用ではローカル `main` が stale（別 worktree / 未 fetch）になる。
  差分レビューは `--base origin/main` を基準にする。

## 10. 信頼境界
- ベンダーを問わず、passedという自己申告だけを実行保証としない。親が対象版・作業場所・コマンド・終了コード・必要な出力の元記録を確認できる場合だけ実行証拠とする。
- レビュー判定と実行検証は別物。終了コードだけでテスト内容の適切さを保証しない。観測できない検証は親が実行するか未検証として扱う。

## 11. 履歴
- 非対話セッションは `~/.codex/sessions/rollout-*.jsonl` に保存されるが `session_index.jsonl`
  （picker/GUI 履歴）には非登録 → 後から辿るには session id（`codex resume <id>` /
  `codex resume --include-non-interactive`）。だから呼び出し側は session id を最終報告に必ず残す。

## 12. メタコメント注意
- レビュー対象に「デモ用」「削除予定」等と書くと Codex が深掘りを避ける。対象コードにメタコメントを入れない。

## 13. 実装委託の規律（実装形 3d を使うとき必読）
- **実測済みの安全境界（2026-07-02、Windows restricted token sandbox）**:
  `workspace-write` はネットワーク遮断（本番 DB・デプロイ・`npm install`・`git push` すべて到達不能）・
  workspace 外書込不可・**`.git` も読み取り専用で、この条件下ではcommit不可**。別の実行経路・native agent全般へ一般化しない。
- **分担の固定**: Codex は worktree にコードを書くだけ。**環境準備（`node_modules` 等）・ビルドゲート実行・
  commit・push・PR 作成はすべて呼び出し側**の仕事。この分担は本CLI経路に適用し、権限のある親の操作を禁止するものではない。
- **レビュー独立性**: 実装セッションを resume してレビューさせない——レビューは必ず**新規セッション**
  （(a)(b) 形）で行い、レビューアに「Codex が書いた」という作者情報を明かさない。
- **修正差し戻し**: レビュー指摘・ビルドゲート red の修正は**実装セッションへの resume**（(c) 形＋ sandbox 指定）が基本。
  **2ラウンド進展が無ければ呼び出し側へ返す**。再割当・上限は呼び出し側のワークフローに従う。
- **失敗時の例外**: 実装形での usage limit・実装未完走は §6(d) の「即中断」ではなく**呼び出し側に返す**
  （呼び出し側は別の実装者へのフォールバックを選べる。レビュー用途の §6(d) はそのまま＝即中断）。
- execpolicy `.rules` は補助防御にすぎない（`powershell -Command`・`bash -c`・`cmd /c` ラッパー越しと
  パス表記ゆれで全すり抜け＝実測）。**安全の主防壁は sandbox**。`.rules` の有無に安全判断を依存させない。
