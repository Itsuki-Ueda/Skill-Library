---
name: agent-team
description: "Codex を Orchestrator として agent-team（Claude×Codex チーム開発）を回すためのハーネス固有設定。正本は ~/.agents/skills/agent-team/SKILL.md。「/agent-team」「チームで開発」「ミッション」で正本と併せて必ず読む。"
---

# agent-team — Codex ハーネス固有設定

**正本 `~/.agents/skills/agent-team/SKILL.md` と `references/dispatch.md` `references/defaults.yaml` を最初に読み、全工程に従うこと。**
このファイルは Codex 固有の読み替えだけを定義する。正本の本文は複製しない。

ルーティングは `defaults.yaml` の **`codex_routing`** を `routing` の代わりに使う。

## 読み替え表（正本の記述 → Codex での実行）

| 正本の記述 | Codex での実行 |
| --- | --- |
| Agent ツールで coding-agent / reviewer / researcher / plan-probe を起動 | 対応する custom agent を**名前指定で spawn**（`codex_routing` の `agent:`）。組み込み `worker` / `explorer` / `default` へ黙って置換しない（`~/.agents/codex/AGENTS.md`「Named subagent routing」） |
| codex exec 実装形(3d)・文書レビュー形(3a)・resume 形(3c) | 使わない。custom agent spawn ＋同一エージェントへの追加入力で置き換える。**入れ子 `codex exec` は禁止**（sandbox はネットワーク遮断。codex-protocol.md §13） |
| cc-worker / hard-worker（coding-agent） | CC ゲートウェイの `coding-agent` モード（下記）。プロンプト冒頭に「`team-worker` スキル（正本 `~/.agents/skills/team-worker/SKILL.md`）を読み従え」＋契約全文を置く |
| reviewer サブエージェント / codex-review | Codex(team-worker) 実装分 → CC ゲートウェイ `reviewer` モード（正本 `~/.agents/skills/team-code-reviewer/SKILL.md` を名指し）。CC(coding-agent) 実装分 → custom agent `reviewer` |
| 分解文書のプランレビュー | CC ゲートウェイ `reviewer` モード（正本 `~/.agents/skills/team-plan-reviewer/SKILL.md` を名指し）。並走する plan-probe は custom agent `plan-probe` |
| SendMessage で差し戻し | custom agent → **同一エージェントへ追加入力**（send_input 等、ハーネスが提供する継続手段）。CC ゲートウェイ → **新規呼び出し**（契約＋前回指摘＋現在の diff 範囲を同梱。文脈は引き継がれない前提で書く） |
| AskUserQuestion | `NEED-DECISION: <判断が必要な内容と選択肢>` を先頭に置いて停止 |
| [3.5] executor 委譲 | 発動しない。常に**直接実行モード**（[4]〜[6] を Orchestrator 自身が実行） |
| cc-chore（完了ゲート実行） | Orchestrator 自身が実行。各コマンドの **exit code をミッションファイルに記録**する |
| バックグラウンド起動と完了通知 | custom agent の並列 spawn ＋ wait。Allowed paths 非交差の契約だけ並列（正本 `references/dispatch.md` §並列実行の規律をそのまま適用） |
| task commit | Orchestrator(Codex) が `git add <そのタスクの Allowed paths>` → `git commit`。sandbox の `.git` 保護で拒否されたら**承認要求（approval on-request）で実行**。`--dangerously-bypass-approvals-and-sandbox` 等の禁止フラグは使わない |
| Windows 実行の注意（PowerShell） | Codex のシェルは PowerShell。正本の注意書きをそのまま適用 |

## CC ゲートウェイの呼び方

手順・認証境界・禁止事項の正本は `~/.agents/codex/skills/autodev/references/claude-code-bridge.md`。ここには差分だけ置く。

1. 別の tool call でプロンプトを UTF-8（BOM なし）の一時ファイルへ書く。
2. ゲートウェイだけを単独の tool call で実行する（他コマンドを混ぜない）。
3. 別の tool call で一時ファイルを削除する。

コマンド（1 行。`{}` が置換箇所）:

```
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\iueda\.codex\bin\cc-subscription-gateway.ps1 coding-agent "{プロンプトファイルの絶対パス}" -Model opus -Effort xhigh
```

レビューは第1引数と effort だけ変える: `reviewer "{プロンプトファイルの絶対パス}" -Model opus -Effort high`

### 利用不可のときの縮退

利用不可の判定は bridge 文書の「利用不可判定」に従う（生のエラーを確認できた場合だけ）。縮退先:

- **hard-worker / cc-worker 行きのタスク**: `team-worker` に落とさず **`BLOCKED:` で停止**する（複雑タスクを量産モデルへ黙って落とさない）。
- **レビュー**: custom agent `reviewer` へ縮退し、**「クロスベンダーレビュー未達」を最終報告に明記**する。

## 状態レイヤー

正本どおり（`.agents/` への書き込みは Orchestrator のみ、worker の成果物は `queue/` へ）。
ミッションファイルの `Active session` には **Codex のセッション ID** を書く。

## 最終報告（Codex 固有追加項目）

- 使用 custom agent の起動数: team-worker / researcher / reviewer / plan-probe
- CC ゲートウェイ結果: 成功 / 利用不可（生エラー） / 未使用
- クロスベンダーレビュー達成の有無
- 完了ゲート（`verify.post_change` / `verify.smoke`）の exit code
