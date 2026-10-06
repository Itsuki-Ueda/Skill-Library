#!/usr/bin/env bash
# agent-team: executor が SendMessage で差し戻した孫（coding-agent・reviewer）の完了を、番を終えずに待つ。
# 番を終えると自動催促で executor が終わってしまうため、ツール実行中のまま待つ（2026-10-06 実測）。
#
#   bash ~/.agents/skills/agent-team/scripts/wait-done.sh <done ファイル> [timeout秒=570] [grace秒=20]
#
# 出力: DONE（exit 0）/ TIMEOUT（exit 1）。DONE 後も grace 秒待ち、孫の正式報告（SubagentHandback）がこの間に届くようにする。
# Bash ツールの timeout は 600000 を指定する。TIMEOUT なら同じコマンドを再実行する。Windows（Git Bash）・Linux 共通。
done_file=${1:?done file}; timeout=${2:-570}; grace=${3:-20}
t=0
while [ ! -e "$done_file" ] && [ "$t" -lt "$timeout" ]; do sleep 5; t=$((t + 5)); done
[ -e "$done_file" ] || { echo TIMEOUT; exit 1; }
sleep "$grace"; echo DONE
