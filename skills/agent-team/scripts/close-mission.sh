#!/usr/bin/env bash
# agent-team: ミッションを閉じる（[7] の closed への移動と [8] の撮影画像の掃除・台帳への記録を1回で行う）。
#   bash close-mission.sh <M-ID> [<作業場所>]   # 作業場所 = ミッションの記録がある本体か worktree（省略時は今のフォルダ）
# worktree・ブランチの後片付けと最終報告は、このあと git-ops に従って行う（判断が要るので自動にしない）。
set -euo pipefail
mid=${1:?usage: close-mission.sh <M-ID> [<作業場所>]}; here=$(cd "${2:-.}" && pwd)
dir="$here/.agents/state/missions"; s=$(cd "$(dirname "$0")" && pwd)
if [ -f "$dir/$mid.md" ]; then
  mkdir -p "$dir/closed"
  git -C "$here" mv "$dir/$mid.md" "$dir/closed/$mid.md" 2>/dev/null || mv "$dir/$mid.md" "$dir/closed/$mid.md"
  echo "移動: missions/$mid.md → missions/closed/"
elif [ ! -f "$dir/closed/$mid.md" ]; then echo "ミッションの記録が無い: $dir/$mid.md" >&2; exit 1
fi
repo=$(dirname "$(git -C "$here" rev-parse --path-format=absolute --git-common-dir)")
bash "$s/capture.sh" --clean "$(basename "$repo")" || echo "撮影画像の掃除に失敗（続行）" >&2
python "$s/mission_cost.py" "$here" "$mid"
