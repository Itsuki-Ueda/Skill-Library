#!/usr/bin/env bash
# agent-team-cc（常駐セッション側）: 未着手の依頼が review-requests ブランチに現れるまで待ち、見つけたら全件を 1 行ずつ出して終わる。
# 未着手 = requests/<id>.txt があり、origin/<結果ブランチ> に reviews/<id>.md が無く、処理中の印（/tmp/review-<id>）も無いもの。
# 処理中の印は「依頼 1 件の処理」の 2 で作る worktree そのもの（終わったら消す）。これで並行処理中の依頼を二重に拾わない。
#   bash ~/.agents/skills/agent-team-cc/scripts/wait-request.sh <結果ブランチ> [間隔秒=20] [上限秒=3000]
set -u
out=${1:?result branch}; iv=${2:-20}; limit=${3:-3000}; t=0
while [ "$t" -lt "$limit" ]; do
  git fetch -q origin review-requests "$out" 2>/dev/null
  found=0
  for f in $(git ls-tree --name-only origin/review-requests requests/ 2>/dev/null | grep '\.txt$'); do
    id=$(basename "$f" .txt)
    git cat-file -e "origin/$out:reviews/$id.md" 2>/dev/null && continue
    [ -e "/tmp/review-$id" ] && continue
    echo "REQUEST id=$id $(git show "origin/review-requests:$f" | tr '\n' ' ')"; found=1
  done
  [ "$found" = 1 ] && exit 0
  sleep "$iv"; t=$((t + iv))
done
echo "NO_REQUEST within ${limit}s"
