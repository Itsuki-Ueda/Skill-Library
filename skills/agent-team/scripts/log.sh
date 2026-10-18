#!/usr/bin/env bash
# agent-team: ミッションの Log に、今の時刻を付けた1行を足す（時刻を見込みで書かないため）。
#   bash log.sh <M-ID> "<出来事・判断・根拠>" [<作業場所>]   # 作業場所 = ミッションの記録がある本体か worktree（省略時は今のフォルダ）
set -euo pipefail
mid=${1:?usage: log.sh <M-ID> "<text>" [<作業場所>]}; text=${2:?usage: log.sh <M-ID> "<text>" [<作業場所>]}
f="${3:-.}/.agents/state/missions/$mid.md"
[ -f "$f" ] || { echo "ミッションの記録が無い: $f" >&2; exit 1; }
grep -q '^## Log' "$f" || { echo "Log の節が無い: $f" >&2; exit 1; }
line="- $(date '+%F %H:%M') $text"
# Log 節の最後（次の見出しの前、無ければ末尾）に足す。節の後ろの空行は残す
awk -v line="$line" '
  function flush(){ print line; for(;blank>0;blank--) print ""; done=1 }
  /^## /{ if(inlog && !done) flush(); inlog=($0 ~ /^## Log/) }
  inlog && !done && /^$/ { blank++; next }
  { for(;blank>0;blank--) print ""; print }
  END{ if(!done) flush() }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
echo "$line"
