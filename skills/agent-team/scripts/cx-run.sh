#!/usr/bin/env bash
# agent-team: codex exec を ~/.agents/docs/codex-protocol.md §3 の形で起動する。
# プロンプトはファイルで渡す（引用符・変数名の書き間違いを構造的に防ぐ）。
#
#   cx-run.sh impl   --cwd <worktree> --prompt <file> --out <file> --model <m> --effort <e>   # §3d 実装
#   cx-run.sh ask    --prompt <file> --out <file> --model <m> --effort <e> [--cwd <dir>]      # §3a 調査・文書レビュー（read-only）
#   cx-run.sh review --cwd <repo> --target "--base origin/main" --out <file> --model <m> --effort <e>  # §3b 差分レビュー
#   cx-run.sh resume --session <id> --prompt <file> --out <file> --model <m> --effort <e> [--cwd <worktree>]  # §3c（--cwd で実装の差し戻し）
#
# 生成物: <out>（最終メッセージ）/ <out>.err（ヘッダ・作業ログ）/ <out>.exit（終了コード）。
# 完了時に1行サマリ（exit / session / out サイズ）を出す。長時間になり得るので run_in_background で起動する。
set -u
kind=${1:?kind: impl|ask|review|resume}; shift
cwd= prompt= out= model= effort= target= session=
while [ $# -gt 0 ]; do
  case $1 in
    --cwd) cwd=$2 ;; --prompt) prompt=$2 ;; --out) out=$2 ;; --model) model=$2 ;;
    --effort) effort=$2 ;; --target) target=$2 ;; --session) session=$2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift 2
done
need() { [ -n "$1" ] || { echo "$2 is required for $kind" >&2; exit 2; }; }
need "$out" --out; need "$model" --model; need "$effort" --effort
cfg=(-c "model=$model" -c "model_reasoning_effort=$effort")
stdin=/dev/null

case $kind in
  impl)
    need "$cwd" --cwd; need "$prompt" --prompt
    args=(exec -s workspace-write -C "$cwd" -o "$out" "${cfg[@]}"); stdin=$prompt ;;
  ask)
    need "$prompt" --prompt
    args=(exec -s read-only)
    [ -n "$cwd" ] && args+=(-C "$cwd")
    args+=(-o "$out" "${cfg[@]}"); stdin=$prompt ;;
  review)
    need "$cwd" --cwd; need "$target" --target
    read -ra tgt <<< "$target"
    args=(exec -C "$cwd" -o "$out" review "${tgt[@]}" "${cfg[@]}") ;;
  resume)
    need "$session" --session; need "$prompt" --prompt
    args=(exec)
    [ -n "$cwd" ] && args+=(-s workspace-write -C "$cwd")   # §3d: -s/-C は exec と resume の間
    args+=(resume "$session" -o "$out" "${cfg[@]}" -); stdin=$prompt ;;
  *) echo "unknown kind: $kind" >&2; exit 2 ;;
esac
[ "$stdin" = /dev/null ] || [ -f "$stdin" ] || { echo "prompt file not found: $stdin" >&2; exit 2; }

codex "${args[@]}" < "$stdin" > /dev/null 2> "$out.err"
code=$?
echo "$code" > "$out.exit"
sid=$(grep -m1 -oE 'session id: [0-9a-f-]+' "$out.err" | awk '{print $3}')
bytes=$( [ -f "$out" ] && wc -c < "$out" | tr -d ' ' || echo 0)
echo "exit=$code session=${sid:-unknown} out=$out bytes=$bytes err=$out.err"
exit "$code"
