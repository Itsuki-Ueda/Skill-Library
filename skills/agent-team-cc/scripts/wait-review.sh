#!/usr/bin/env bash
# agent-team-cc: Codex 専用セッションの結果（または準備完了の印）が結果ブランチに届くまで待つ。
#   wait-review.sh --repo <リポジトリ> --id <依頼ID> [--result-branch codex-reviewer] [--timeout 分=30] [--interval 秒=20]
#   wait-review.sh --repo <リポジトリ> --ready [--result-branch ...] [--timeout 0]   # 準備完了の確認（0 = 1 回だけ見る）
# 届いたら 1 行目に ARRIVED/READY、続けてファイルの中身を出して exit 0。期限切れは TIMEOUT で exit 1。
set -u
repo= id= rb=codex-reviewer timeout=30 iv=20 ready=
while [ $# -gt 0 ]; do
  case $1 in
    --ready) ready=1; shift; continue ;;
    --repo) repo=$2 ;; --id) id=$2 ;; --result-branch) rb=$2 ;; --timeout) timeout=$2 ;; --interval) iv=$2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift 2
done
[ -n "$repo" ] || { echo "--repo is required" >&2; exit 2; }
if [ -n "$ready" ]; then f=reviews/READY.md; label=READY; else [ -n "$id" ] || { echo "--id or --ready is required" >&2; exit 2; }; f=reviews/$id.md; label=ARRIVED; fi
cd "$repo"
t0=$(date -u +%s); deadline=$((t0 + timeout * 60))
while :; do
  git fetch -q origin "$rb" 2>/dev/null
  if git cat-file -e "origin/$rb:$f" 2>/dev/null; then
    echo "$label $f after $(( $(date -u +%s) - t0 ))s at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    git show "origin/$rb:$f"; exit 0
  fi
  [ "$(date -u +%s)" -ge "$deadline" ] && break
  sleep "$iv"
done
echo "TIMEOUT $f not on origin/$rb after ${timeout}min"; exit 1
