#!/usr/bin/env bash
# agent-team-cc: 作業ツリーの現在の状態をスナップショットとして push し、Codex 専用セッションへレビューを依頼する。
# 作業ツリーと index は変えない（一時 index で commit を作る）。手順の正本: references/codex-session.md
#   request-review.sh --repo <作業場所> --id <依頼ID> --base <比較元の commit/ref> [--paths <パス>...]
#   --paths 省略時は作業ツリー全体（未追跡ファイルを含む。.gitignore は効く）。
set -eu
repo= id= base= paths=()
while [ $# -gt 0 ]; do
  case $1 in
    --repo) repo=$2; shift 2 ;; --id) id=$2; shift 2 ;; --base) base=$2; shift 2 ;;
    --paths) shift; while [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; do paths+=("$1"); shift; done ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
[ -n "$repo" ] && [ -n "$id" ] && [ -n "$base" ] || { echo "--repo --id --base are required" >&2; exit 2; }
cd "$repo"
base_sha=$(git rev-parse --verify "$base^{commit}")
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
export GIT_INDEX_FILE=$tmp
git read-tree HEAD
if [ ${#paths[@]} -gt 0 ]; then git add -A -- "${paths[@]}"; else git add -A; fi
head_sha=$(git commit-tree "$(git write-tree)" -p HEAD -m "review snapshot: $id")
# 依頼ファイルを review-requests ブランチへ積む（無ければ親なしで作る）
git fetch -q origin review-requests 2>/dev/null || true
req_parent=$(git rev-parse -q --verify origin/review-requests || true)
if [ -n "$req_parent" ]; then git read-tree "$req_parent"; else git read-tree --empty; fi
blob=$(printf 'head=review/%s/head base=review/%s/base\n' "$id" "$id" | git hash-object -w --stdin)
git update-index --add --cacheinfo 100644 "$blob" "requests/$id.txt"
req_sha=$(git commit-tree "$(git write-tree)" ${req_parent:+-p "$req_parent"} -m "request: $id")
unset GIT_INDEX_FILE
# スナップショットを先に、依頼を後に push する（依頼を見た常駐セッションが対象を必ず取れるように）
git push -q origin "$head_sha:refs/heads/review/$id/head" "$base_sha:refs/heads/review/$id/base"
git push -q origin "$req_sha:refs/heads/review-requests"
echo "requested id=$id head=$head_sha base=$base_sha at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
