# agent-team: executor が SendMessage で差し戻した孫（coding-agent・reviewer）の完了を、番を終えずに待つ。
# 番を終えると自動催促で executor が終わってしまうため、ツール実行中のまま待つ（2026-10-06 実測）。
#
#   & ~/.agents/skills/agent-team/scripts/wait-done.ps1 <done ファイル> [-TimeoutSec 570] [-GraceSec 20]
#
# 出力: DONE / TIMEOUT。DONE 後も GraceSec 待ち、孫の正式報告（SubagentHandback）がこの間に届くようにする。
# PowerShell ツールの timeout は 600000 を指定する。TIMEOUT なら同じコマンドを再実行する。
param(
  [Parameter(Mandatory)][string]$Done,
  [int]$TimeoutSec = 570,
  [int]$GraceSec = 20
)
$t = 0
while (-not (Test-Path -LiteralPath $Done) -and $t -lt $TimeoutSec) { Start-Sleep 5; $t += 5 }
if (-not (Test-Path -LiteralPath $Done)) { 'TIMEOUT'; exit 1 }
Start-Sleep $GraceSec
'DONE'; exit 0
