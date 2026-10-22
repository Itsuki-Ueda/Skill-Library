#!/usr/bin/env bash
# explain-page: 解説ページの記録（.agents/state/explain/E-xxx.md）を1行ずつ一覧にする。
#   bash list.sh [<リポジトリ>] [<絞り込み語>]   # 絞り込み語は題名・Status・種類・Mission のどれかに含まれる語（例: 設計判断、open、M-012）
# 各記録の冒頭の固定行だけを読む。本文は読まない。
set -euo pipefail
dir="${1:-.}/.agents/state/explain"; q="${2:-}"
[ -d "$dir" ] || { echo "記録が無い: $dir" >&2; exit 0; }
for f in "$dir"/E-*.md; do
  [ -e "$f" ] || continue
  awk -v q="$q" '
    NR==1 && /^# / { sub(/^# /, ""); t=$0; next }
    /^Status: / { sub(/^Status: /, ""); s=$0 }
    /^種類: / { sub(/^種類: /, ""); k=$0 }
    /^Mission: / { sub(/^Mission: /, ""); m=$0 }
    /^結論: / { sub(/^結論: /, ""); c=$0 }
    /^Page: / { sub(/^Page: /, ""); p=$0 }
    /^## / { exit }
    END { if (q=="" || index(t "|" s "|" k "|" m, q)) print t " | " k " | " s " | " m " | " c " | " p }
  ' "$f"
done
