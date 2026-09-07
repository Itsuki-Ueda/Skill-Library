# Claude Codeサブスクリプションブリッジ

CodexはClaude Codeを直接呼ばず、Claude setup-tokenを使用するサブスクリプション専用ゲートウェイを介して呼ぶ。

## 固定パス

```text
コアラッパー:
C:\Users\iueda\.codex\bin\invoke-claude-subscription.ps1

ゲートウェイ:
C:\Users\iueda\.codex\bin\cc-subscription-gateway.ps1

暗号化トークン:
C:\Users\iueda\.codex\secrets\claude-code-oauth.dpapi

Claude Code実体:
C:\Users\iueda\.local\bin\claude.exe
```

Claude Code実体はゲートウェイ内部からだけ使用する。Codexは直接実行しない。

## 認証・課金境界

コアラッパーは、Claude Code起動中だけ次を行う。

- `ANTHROPIC_API_KEY`、`ANTHROPIC_AUTH_TOKEN`、クラウドプロバイダー指定、ゲートウェイURLを子プロセスから除外する。
- DPAPI暗号化ファイルを現在のWindowsユーザーで復号する。
- 復号したsetup-tokenを`CLAUDE_CODE_OAUTH_TOKEN`として子プロセスへ設定する。
- 条件を満たせない場合は停止し、APIキーへフォールバックしない。
- `--bare`は使わない。

## 呼び出し規律

ゲートウェイ呼び出しは、他のコマンドを混在させない単独のshell tool callにする。

正しい順序:

1. 別のtool callでUTF-8の一時プロンプトファイルを作る。
2. tool callのcwd/workdirを対象リポジトリのルートにする。
3. ゲートウェイだけを実行する。
4. 別のtool callで一時プロンプトファイルを削除する。

禁止:

- 同じtool callで`Set-Location`、`git`、`Get-Content`、ファイル生成・削除、パイプ、リダイレクトを併用する。
- `claude`、`claude.exe`、Claude Code実体の絶対パスを直接実行する。
- ゲートウェイ失敗時に直接CLIへ切り替える。

## 疎通・認証確認

```powershell
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\iueda\.codex\bin\cc-subscription-gateway.ps1 check
```

期待結果:

```text
OK: DPAPI token decrypted and higher-priority API credentials are blocked.
```

## モデル・推論強度の指定（任意）

ゲートウェイのコマンド末尾には `-Model {モデル}` `-Effort {low|medium|high|xhigh|max}` を付けられる。
省略時の挙動は従来どおり（Claude Code の既定に従う）。
agent-team の hard-worker（opus / xhigh）やレビュー（opus / high）はこれを使う。

## レビュー呼び出し

まず、別のshell tool callで一時ファイルを作る。

```powershell
$promptPath = Join-Path (Get-Location) ('.codex-cc-prompt-' + [Guid]::NewGuid().ToString('N') + '.txt')
$prompt = @"
モード=差分レビュー
対象 diff 範囲=origin/main...HEAD

対象の作成経緯を知らない第三者として、reviewer定義の規律で審査してください。
P0-P3タグ、根拠箇所、具体的な壊れ方、VERDICTを出してください。
"@
[System.IO.File]::WriteAllText($promptPath, $prompt, [System.Text.UTF8Encoding]::new($false))
Write-Output $promptPath
```

出力された絶対パスを使い、次を単独のshell tool callで実行する。

```powershell
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\iueda\.codex\bin\cc-subscription-gateway.ps1 reviewer "<absolute-prompt-file>"
```

結果取得後、別のtool callで削除する。

```powershell
Remove-Item -LiteralPath '<absolute-prompt-file>' -Force -ErrorAction SilentlyContinue
```

## 実装呼び出し

承認済み計画・制約を一時プロンプトファイルへ書き、次を単独で実行する。

```powershell
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\iueda\.codex\bin\cc-subscription-gateway.ps1 coding-agent "<absolute-prompt-file>"
```

Claude Codeに実装させる場合も、commit、push、PR、最終検証、レビュー集約はCodexが持つ。

## 利用不可判定

次のいずれかを生のエラーで確認した場合だけ利用不可と判定する。

- DPAPIトークンの不存在・復号失敗
- setup-token失効・認証失敗
- Claude Code quota上限
- ネットワーク障害
- reviewer/coding-agentが存在しない
- Codex rulesがゲートウェイを許可しない

直接`claude`へ迂回しない。エラーをそのまま記録し、Codex独立レビューへ縮退する。

## 非同期agmsg

agmsgは、既に起動済みのClaude Codeセッションが同じサブスクリプション認証で動いていることを確認できる場合だけ利用する。決定的な1回レビューはゲートウェイを優先する。
