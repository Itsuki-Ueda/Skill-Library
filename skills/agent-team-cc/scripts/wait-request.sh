#!/usr/bin/env bash
# agent-team-cc（常駐セッション側）: review-requests ブランチに未処理の依頼が現れるまで待ち、見つけたら 1 行出して終わる。
# 未処理 = requests/<id>.txt があり、origin/<結果ブランチ> に reviews/<id>.md が無いもの。
#   bash ~/.agents/skills/agent-team-cc/scripts/wait-request.sh <結果ブランチ> [間隔秒=20] [上限秒=3000]
set -u
out=${1:?result branch}; iv=${2:-20}; limit=${3:-3000}; t=0
while [ "$t" -lt "$limit" ]; do
  git fetch -q origin review-requests "$out" 2>/dev/null
  for f in $(git ls-tree --name-only origin/review-requests requests/ 2>/dev/null | grep '\.txt$'); do
    id=$(basename "$f" .txt)
    git cat-file -e "origin/$out:reviews/$id.md" 2>/dev/null && continue
    echo "REQUEST id=$id $(git show "origin/review-requests:$f" | tr '\n' ' ')"
    exit 0
  done
  sleep "$iv"; t=$((t + iv))
done
echo "NO_REQUEST within ${limit}s"
