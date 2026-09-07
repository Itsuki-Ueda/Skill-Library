---
name: claude-code-subscription
description: "CodexからClaude Code reviewer/coding-agentを呼ぶ際に、Claude setup-tokenのサブスクリプション認証だけを使い、APIキー課金へのフォールバックを防ぐ。Claude Code、CCレビュー、CC実装、Codex→CC連携を依頼されたときに使う。"
---

# Claude Code subscription bridge

Claude Codeを直接実行せず、次のゲートウェイだけを使う。

```text
C:\Users\iueda\.codex\bin\cc-subscription-gateway.ps1
```

## 必須フロー

1. 作業ディレクトリを対象リポジトリのルートにする。
2. プロンプト本文をリポジトリ内の一時UTF-8ファイルへ書く。例: `.codex-cc-prompt-<guid>.txt`。
3. 次のゲートウェイ呼び出しを、他のコマンドと混在させず単独のshell tool callで実行する。
4. 結果取得後、一時プロンプトファイルを別のtool callで削除する。

疎通・認証確認:

```powershell
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\iueda\.codex\bin\cc-subscription-gateway.ps1 check
```

レビュー:

```powershell
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\iueda\.codex\bin\cc-subscription-gateway.ps1 reviewer "C:\absolute\path\to\prompt.txt"
```

実装:

```powershell
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\iueda\.codex\bin\cc-subscription-gateway.ps1 coding-agent "C:\absolute\path\to\prompt.txt"
```

## 禁止事項

- `claude`、`claude.exe`、実体の絶対パスを直接実行しない。
- `--bare`を使わない。
- `ANTHROPIC_API_KEY`や`ANTHROPIC_AUTH_TOKEN`をゲートウェイへ渡さない。
- ゲートウェイ失敗時に直接CLI、curl、Node.js、Python等でAnthropicへ迂回しない。
- ゲートウェイ呼び出しと、`cd`、git、ファイル生成、削除、パイプ、リダイレクトを同じshell tool callへ混在させない。

## 認証上の意味

ゲートウェイは`invoke-claude-subscription.ps1`を通じて、上位のAPI認証情報を子プロセスから除外し、DPAPI暗号化された`CLAUDE_CODE_OAUTH_TOKEN`だけをClaude Codeへ渡す。条件を満たせない場合はAPIキーへフォールバックせず失敗する。
