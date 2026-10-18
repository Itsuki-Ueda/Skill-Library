# Codex CLI 呼び出しの正本プロトコル

agent-team（`cx-run.sh`）から参照する、OpenAI Codex CLI 呼び出しの正本。
起動の形は `bash ~/.agents/skills/agent-team/scripts/cx-run.sh`（impl / ask / review / resume）の中にある。コマンドを手で組み立てない。
このファイルを読むのは、起動に失敗したとき、sandbox の制限に当たったとき、`cx-run.sh` で足りない形が要るときだけ。

## 1. モデル / effort
- model / effort は呼び出し側の設定（agent-team の `references/defaults.yaml` とプロジェクトの team.yaml）が正本。ここに既定値を置かない。
- slug は完全一致で使う（`gpt-6` のような省略名はエラーになる）。設定の値を逐語でコピーし、記憶から組み立てない。
- `cx-run.sh` は毎回 `-c model=… -c model_reasoning_effort=…` を付けるので、`~/.codex/config.toml` の設定に左右されない。

## 2. 実行シェル
- `cx-run.sh` は Bash ツールで `run_in_background: true` で起動する。プロンプトはファイルに書いて渡す。
- 手で組み立てる場合だけ PowerShell ツールを使う（stdin パイプ `"<prompt>" | codex exec ...` は PowerShell 前提。Bash では文字列がコマンドとして解釈されて壊れる）。

## 3. 呼び出し形

### (a)〜(d) 起動の形（`cx-run.sh` が組み立てる）
| 形 | 用途 | sandbox | 要点 |
| --- | --- | --- | --- |
| ask | 調査・計画/文書レビュー | read-only | プロンプトは stdin（引数で渡すと stdin 待ちでハングする） |
| review | 差分レビュー | read-only | 組み込みの指示で動き、カスタムプロンプトを渡せない。基準は `--base origin/main`（ローカルの main は古いことがある） |
| impl | 実装 | workspace-write、対象 worktree に `-C` で固定 | 10分を超え得るので必ずバックグラウンドで起動する |
| resume | 再レビュー・修正の差し戻し | 毎回明示（元のセッションの sandbox は引き継がれず、指定しないと config.toml の既定＝書き込み可で動く。2026-09-24 実測） | `-s`/`-C` は `exec` と `resume` の間に置く（後ろに置くと `unexpected argument '-s'`） |

- 生成物: `<out>`（最終メッセージ）、`<out>.err`（ヘッダと作業ログ。session id はここ）、`<out>.exit`（終了コード）。`-o` は正常完了の直前に1回だけ書かれ、起動直後の失敗では作られない（2026-09-22 実測）。
- 対象リポジトリの中から呼ぶ（git リポジトリの外では `Not inside a trusted directory` で拒否される）。
- 使わないフラグ: `--dangerously-bypass-approvals-and-sandbox` / `--ignore-rules` / `--add-dir`。

### (e) restricted sandbox（workspace-write）の既知の制限（Windows・2026-09-24 実測、codex-cli 0.156.1）
症状 → 対処。準備（依存の取得・復元など通信やユーザー領域が要るもの）は親が dispatch 前に済ませる。
- 作業場所内の `.agents/`・`.git` への書き込みが拒否される → 成果物（撮影画像等）は `%TEMP%` 配下へ出す（`%TEMP%` は書込可）。
- 外部ネットワークに出られない（localhost は可）→ 依存の取得（`npm ci` / `dotnet restore` 等）は親が行う。外部サービスのデータが要る画面確認は親が行う。
- `%USERPROFILE%` 直下の一覧と、`%APPDATA%`・`%LOCALAPPDATA%`（Temp を除く）の読み取りが拒否される。その結果:
  - ユーザー単位インストールのツール（`%LOCALAPPDATA%\Programs` 配下の Python 等）が見つからない → Program Files 配下のツールを使うか、親が実行する。
  - 古い esbuild 系の設定読込（例: Vite 7）が親フォルダを辿って `Cannot read directory "../../..": Access is denied` で止まる → 依存をロックファイルどおりに入れ直す（Vite 8 系では再現しない）。
  - `dotnet test` / `dotnet build` の暗黙復元が `%APPDATA%\NuGet\NuGet.Config` を読めず失敗する → 親が `dotnet restore` を済ませ、worker は `--no-restore` を付ける。
  - WPF 等 Windows デスクトップのビルドが `%LOCALAPPDATA%\Microsoft SDKs` を読めず `MSB4184` で失敗する → このフォルダだけ権限の継承が切れていて `CodexSandboxUsers` に権限が無いのが原因（2026-10-09、0.159.1）。`icacls "%LOCALAPPDATA%\Microsoft SDKs" /grant "<PC名>\CodexSandboxUsers:(OI)(CI)RX"` で読み取りだけ足すと、WPF のビルドと見えない作業スペースでの画面確認が通る（PC ごとに1回。人間の承認を得て行う）。`%APPDATA%\NuGet` も同じく継承が切れている（上の `--no-restore` で避ける）。
- 別の作業場所で起動した Codex のビルドが残した常駐プロセス（MSBuild のノード・コンパイラーのサーバー）を次のビルドが使い回し、その作業場所に書けず `CS2012`・`MSB3191` で失敗する → `~/.codex/config.toml` の `[shell_environment_policy.set]` に `MSBUILDDISABLENODEREUSE = "1"`・`UseSharedCompilation = "false"` を置く（2026-10-09 実測）。
- sandbox 内のプロセスは前面を取れない（`SetForegroundWindow` が効かない）→ 本物の前面・入力が要る確認は親が sandbox の外で流す。
- sandbox 内で例外を受け止めずに落ちたプロセスは、Windows のエラーのウィンドウを人の画面に出し、OK を押すまで残る → worker が流す確認用のプログラムは、失敗を例外で落とさず終了コードで返す。
- sandbox 内で起動したプロセスは、sandbox 外の権限では止められない（アクセス拒否）。sandbox 内でも `taskkill /T` と WMI での子孫探索は効かない → 同じ sandbox から `Stop-Process -Id <PID>` で止める（PID は `netstat -ano`）。開発サーバは常駐させず、起動から停止まで行うスクリプト（agent-team の `capture.sh`）に任せる。
- sandbox 内で Chromium 系ブラウザを起動すると子プロセスが落ちる → `--no-sandbox` を付ける（開くのは localhost のみ）。

### (f) restricted sandbox（workspace-write）の既知の制限（Linux・クラウド環境・2026-10-09 実測）
- ネットワークを禁じていると 127.0.0.1 の待ち受けも拒否される（`listen EPERM`）。開発サーバー・ブラウザのテスト（Vitest のブラウザモード等）・E2E・撮影が起動前に止まる → その確認を worker に流させる契約でだけ `cx-run.sh` に `--net` を付ける（`sandbox_workspace_write.network_access=true`）。クラウドの環境はネットワークが Full なので、付けると外部にも出られる。必要の無い契約には付けない。
- コマンドが終わると、そのコマンドの中で起動したプロセス（バックグラウンドで起動した開発サーバー等）も消える（2026-10-15 実測）→ 起動と操作を別のコマンドに分けない。起動 → 確認 → 停止を1回のコマンドで行う入口を用意して、それを流させる（verify-ops「実行場所」）。
- worktree の `node_modules` が本体へのリンクだと、vite・tsc のキャッシュの書き込みが作業場所の外への書き込みになり `EROFS`（Windows では `EPERM`）で失敗する → Codex に渡す worktree は `node_modules` をリンクにせず、親が `npm ci` してから渡す（git-ops）。

## 4. timeout
- 全呼び出し 600000ms。高 effort のレビューは1回2〜5分かかる（実測）。実装はこれを超え得るので timeout に頼らずバックグラウンドで起動する。

## 5. 出力の読み方
- 最終結論は `-o <file>` のファイルだけを読む。stdout と stderr を混ぜた出力の末尾を切って結論を取らない（VERDICT は最終メッセージの先頭にあり、長い結論では切り落とされる）。
- `<out>` はラウンド別の名前にする（例 `review-r1.txt`）。上書きすると後から追えない。
- 差分レビュー（review）は組み込みの指示なので P0〜P3 のタグが付かない。返った指摘の内容から重大度を自分で決める（基準は `~/.agents/docs/review-severity.md`）。タグが無いことを指摘ゼロと読まない。VERDICT とタグが食い違ったら、タグ（P0〜P2 の有無）を正とする。

## 6. 失敗時ハンドリング
- (a) exit≠0 または `-o` が無い・空 → `<out>.err` の末尾を確認し、1回だけ再実行する。なお失敗なら中断して人間に報告する。
- (b) session id が取れない → 1回再実行する。だめなら以後 resume を諦め、再レビューは新しいセッションで前回の指摘をプロンプトに含めて行う。
- (c) resume の対象セッションが無い → (b) と同じく新しいセッションで代える。
- (d) usage limit / quota 系エラー → 再実行しても無駄なので、すぐ中断して人間に報告する。ただし実装（impl）では呼び出し側に返す（別の実装者へ切り替えられる）。
- (e) モデルが無いエラー → 推測で別名を試さず、`codex debug models` でカタログの slug を確かめ、設定が古ければ人間に報告して直す。

## 7. 実装を任せるときの規律
- 実測した安全の境界（2026-07-02、Windows restricted token sandbox）: workspace-write はネットワーク遮断（本番 DB・デプロイ・`npm install`・`git push` に届かない）、workspace の外に書けない、`.git` も読み取り専用で commit できない。別の実行経路へ一般化しない。
- 分担: Codex は worktree にコードを書くだけ。環境準備（`node_modules` 等）・ビルドゲートの実行・commit・push・PR は呼び出し側の仕事。
- レビューは実装セッションを resume せず、必ず新しいセッションで行う。レビュアーに作者（Codex が書いた等）を明かさない。
- レビュー指摘・ゲート失敗の修正は、実装セッションへの resume（sandbox 指定つき）が基本。
- execpolicy の `.rules` は補助にすぎない（`powershell -Command`・`bash -c` 越しやパスの表記ゆれですり抜ける。実測）。安全の主防壁は sandbox。
- 実行の自己申告は実行の保証にしない（原則「本物で確かめる」）。worker の検証は `cx_evidence.py` でセッションの元記録から確かめる。

## 8. 記録とコメント
- 非対話セッションは `~/.codex/sessions/rollout-*.jsonl` に残るが、履歴の一覧には載らない。後から辿れるよう、呼び出し側は session id をミッションと最終報告に残す。
- レビュー対象に「デモ用」「削除予定」等のメタコメントを書くと、Codex が深掘りを避ける。対象コードにメタコメントを入れない。
