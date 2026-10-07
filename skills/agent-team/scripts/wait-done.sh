#!/usr/bin/env bash
# agent-team: executor が SendMessage で差し戻した孫（coding-agent・reviewer）の完了を、番を終えずに待つ。
# 番を終えると自動催促で executor が終わってしまうため、ツール実行中のまま待つ（2026-10-06 実測）。
#
#   bash ~/.agents/skills/agent-team/scripts/wait-done.sh <done ファイル>...
#
# 複数渡すと、どれか1つでも出た時点で返る（出たものを DONE 行に列挙。残りは同じコマンドで待ち直す）。
# 出力: DONE <出たファイル>...（exit 0）/ TIMEOUT（exit 1）。DONE 後も grace 秒待ち、孫の正式報告（SubagentHandback）がこの間に届くようにする。
# 待ち時間は環境変数 WAIT_TIMEOUT（既定570秒）・WAIT_GRACE（既定20秒）。
# Bash ツールの timeout は 600000 を指定する。TIMEOUT なら同じコマンドを再実行する。Windows（Git Bash）・Linux 共通。
[ $# -gt 0 ] || { echo "usage: wait-done.sh <done file>..." >&2; exit 2; }
timeout=${WAIT_TIMEOUT:-570}; grace=${WAIT_GRACE:-20}
t=0
while :; do
  done_files=(); for f in "$@"; do [ -e "$f" ] && done_files+=("$f"); done
  [ ${#done_files[@]} -gt 0 ] && break
  [ "$t" -ge "$timeout" ] && { echo TIMEOUT; exit 1; }
  sleep 5; t=$((t + 5))
done
sleep "$grace"; echo "DONE ${done_files[*]}"
