#!/usr/bin/env bash
# プロジェクトの記憶ファイルの行数（INBOX は件数）を測り、閾値超過を1行で報告する。
# 使い方: check-size.sh [--json]
#   --json : SessionStart hook 用。systemMessage と additionalContext を持つ JSON を出す。
# 対象: AGENTS.md（cwd か1階層下）と .agents/state/{STATE,MEMORY,INBOX}.md。
# どちらも見つからなければ何も出さず exit 0（記憶ファイルを持たないプロジェクトでは無音）。

root="${CLAUDE_PROJECT_DIR:-$PWD}"
proj=""
for c in "$root" "$root"/*/; do
  c="${c%/}"
  if [ -f "$c/AGENTS.md" ] || [ -d "$c/.agents/state" ]; then proj="$c"; break; fi
done
[ -z "$proj" ] && exit 0

count() { if [ -f "$1" ]; then wc -l < "$1" | tr -d ' '; else echo "-"; fi; }
# INBOX は件数で測る: 表の行（| YYYY-MM-DD |）と書式違反の箇条書き（- ）を1件と数える
count_items() { if [ -f "$1" ]; then grep -cE '^(\| *[0-9]{4}-[0-9]{2}-[0-9]{2} *\||- )' "$1"; else echo "-"; fi; }
over_if() { # $1=label $2=count $3=limit $4=action $5=単位(既定: 行)
  if [ "$2" != "-" ] && [ "$2" -gt "$3" ]; then over="$over $1=${2}${5:-行}(>$3)→$4"; fi
}

state="$proj/.agents/state"
a=$(count "$proj/AGENTS.md")
s=$(count "$state/STATE.md")
m=$(count "$state/MEMORY.md")
i=$(count_items "$state/INBOX.md")

over=""
over_if AGENTS.md "$a" 200 refresh
over_if STATE.md  "$s" 100 distill
over_if MEMORY.md "$m" 150 refresh
over_if INBOX.md  "$i" 100 promote 件

# STATE.md の中身: Log の長すぎる行（120字超）と、Missions に残った完了行（正本: memory-ops distill）
if [ -f "$state/STATE.md" ]; then
  long=0; done_rows=0; sec=""
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in "## "*) sec="${line#\#\# }"; continue ;; esac
    case "$sec" in
      Log*) line="${line%$'\r'}"; [ -n "$line" ] && [ "$(LC_ALL=C.UTF-8 bash -c 'printf %s "${#1}"' _ "$line")" -gt 120 ] && long=$((long+1)) ;;
      Missions*) st=$(printf '%s' "$line" | awk -F'|' '/^\|/{gsub(/[ *]/,"",$4); print $4}')
        case "$st" in done*|完了*|closed*) done_rows=$((done_rows+1)) ;; esac ;;
    esac
  done < "$state/STATE.md"
  over_if "STATE.md(Logの120字超)" "$long" 0 distill 件
  over_if "STATE.md(Missionsの完了行)" "$done_rows" 0 distill 件
fi

msg="[memory-ops] AGENTS.md=${a} STATE.md=${s} MEMORY.md=${m} INBOX.md=${i}件（ほかは行。- は無し）"
if [ -n "$over" ]; then
  msg="$msg | 閾値超過:$over | agent-team起動時は作業前に /memory-ops を実施、それ以外は人間に告げて判断を仰ぐ"
fi

if [ "$1" = "--json" ]; then
  printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$msg" "$msg"
else
  echo "$msg"
fi
exit 0
