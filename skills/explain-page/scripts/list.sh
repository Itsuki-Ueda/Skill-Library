#!/usr/bin/env bash
# explain-page: プロジェクトの解説ページの記録（.agents/explain/E-xxx.md）を1行ずつ一覧にする。
#   bash list.sh [<リポジトリ>] [<絞り込み語>]   # 絞り込み語は種類・状態・題名のどれかに含まれる語（例: 設計判断、判断待ち）
# 各記録の冒頭の固定行（# 題名・種類・状態・結論・ページ）だけを読む。本文は読まない。
set -euo pipefail
dir="${1:-.}/.agents/explain"; q="${2:-}"
[ -d "$dir" ] || { echo "記録が無い: $dir" >&2; exit 1; }
for f in "$dir"/E-*.md; do
  [ -e "$f" ] || continue
  awk -v q="$q" '
    NR==1 && /^# / { sub(/^# /, ""); t=$0; next }
    /^種類: / { sub(/^種類: /, ""); k=$0 }
    /^状態: / { sub(/^状態: /, ""); s=$0 }
    /^結論: / { sub(/^結論: /, ""); c=$0 }
    /^ページ: / { sub(/^ページ: /, ""); p=$0 }
    /^## / { exit }
    END { line=t " | " k " | " s " | " c " | " p; if (q=="" || index(t k s, q)) print line }
  ' "$f"
done
