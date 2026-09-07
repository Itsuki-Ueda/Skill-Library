#!/usr/bin/env bash
# git-hygiene.sh — マージ済みブランチ・不要worktreeを安全に検出/後片付けする棚卸しスクリプト。
# git-ops スキルの正本ツール。判定ロジック（スカッシュマージ対応・fail-closed・場所ベース分類）を固定化。
#
# 使い方:
#   bash git-hygiene.sh                    # ドライラン（既定）: 対象を一覧するだけ
#   bash git-hygiene.sh --apply            # ローカル後片付け（一時用worktree削除→解放ブランチ削除）
#   bash git-hygiene.sh --apply --remote   # 上記＋リモートのマージ済みブランチ削除
#
# 安全設計:
#   - 既定はドライラン。--apply のときだけ削除。
#   - main と「現在スクリプトを動かしている worktree」は絶対に触らない。
#   - 削除は fail-closed: 「マージ済みPRがある」or「origin/main に未反映コミットが0」のものだけ。
#   - worktree は場所で分類（§1.5）。一時用置き場のものだけ自動 closeout。ユーザー保有は検出のみ。
#   - .git/worktrees/<name>/KEEP がある worktree は常に残す。
#   - worktree 削除前に内部の junction/symlink（node_modules 共有等）を検出し「通路だけ」外す。
#     （2026-08-03 実害: junction を残したまま remove --force するとリンク先の親 node_modules が
#       破壊される。しかも worktree 自体の削除は失敗と報告されるためログから気づけない）
#   - 未コミット変更のある worktree は差分をパッチ退避してから削除。
#   - gh 不可なら PR照合を諦め ahead=0（main内包）判定だけで安全側に倒す。
set -u

APPLY=0; REMOTE=0
for a in "$@"; do
  case "$a" in
    --apply)  APPLY=1 ;;
    --remote) REMOTE=1 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "not a git repo" >&2; exit 1; }
cd "$ROOT" || exit 1
MAIN="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
MAIN="${MAIN:-main}"
CUR="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
SELF_WT="$(git rev-parse --show-toplevel 2>/dev/null)"
BACKUP="${TMPDIR:-/tmp}/git-hygiene-backups/$(git rev-parse --short HEAD)"
TOREMOVE="${TMPDIR:-/tmp}/gh-hyg-toremove.$$"; : > "$TOREMOVE"
trap 'rm -f "$TOREMOVE"' EXIT

echo "repo:   $ROOT"
echo "main:   $MAIN   current: $CUR   mode: $([ $APPLY -eq 1 ] && echo APPLY || echo DRY-RUN)$([ $REMOTE -eq 1 ] && echo ' +REMOTE')"
echo "-------------------------------------------------------------"

git fetch --prune origin --quiet 2>/dev/null || true

# --- マージ済みPRのヘッドブランチ一覧（gh があれば） ---
MERGED_PRS=""
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  MERGED_PRS="$(gh pr list --state merged --limit 500 --json headRefName --jq '.[].headRefName' 2>/dev/null | sort -u)"
else
  echo "(gh 未使用: PR照合をスキップし、mainへ完全内包のブランチのみ対象にします)"
fi
has_merged_pr() { printf '%s\n' "$MERGED_PRS" | grep -qxF "$1"; }
fully_in_main() { [ "$(git rev-list --count "origin/$MAIN..$1" 2>/dev/null || echo 1)" = "0" ]; }

# checked-out ブランチ集合（ローカルブランチ削除の保護に使う。都度再計算する）
checked_out_set() { git worktree list --porcelain | awk '/^branch /{sub("refs/heads/","",$2); print $2}'; }

is_protected() {  # $1=branch。ローカルブランチ削除section用（どこかにチェックアウト中なら保護）
  [ "$1" = "$MAIN" ] && return 0
  printf '%s\n' "$CHECKED_OUT" | grep -qxF "$1" && return 0
  return 1
}
is_deletable() {  # ローカルブランチが削除可か（fail-closed, checkout保護あり）
  local b="$1"; is_protected "$b" && return 1
  has_merged_pr "$b" && return 0; fully_in_main "$b" && return 0; return 1
}
is_deletable_remote() {  # リモートブランチ判定。ローカル同名ではなく origin/ 側の実物を見る
  # （ローカル名で rev-list すると: 同名ローカル無し→エラー→fail-closedで候補落ち、
  #   同名ローカル有り→ローカルの状態で判定→origin側だけ先行コミットがあると誤削除=データ喪失）
  local b="$1"; is_protected "$b" && return 1
  has_merged_pr "$b" && return 0; fully_in_main "origin/$b" && return 0; return 1
}

# --- worktree 用の判定（自分のブランチがチェックアウト中なのは当然なので checkout保護は使わない） ---
branch_merged() {  # $1=branch。main内包 or マージ済PR（mainそのものは対象外）
  local b="$1"; [ "$b" = "$MAIN" ] && return 1
  has_merged_pr "$b" && return 0; fully_in_main "$b" && return 0; return 1
}
head_in_main() { [ "$(git -C "$1" rev-list --count "origin/$MAIN..HEAD" 2>/dev/null || echo 1)" = "0" ]; }
is_temp_location() {  # §1.5 の一時/自動生成置き場か（Windows/Unix両形式）
  case "$1" in
    */.claude/worktrees/*) return 0 ;;
    */.codex/worktrees/*)  return 0 ;;
    [Cc]:/tmp/*|/c/tmp/*|/tmp/*) return 0 ;;
    *) return 1 ;;
  esac
}
has_keep() {  # $1=worktree path。per-worktree の .git/worktrees/<name>/KEEP
  local gd; gd="$(git -C "$1" rev-parse --absolute-git-dir 2>/dev/null)" || return 1
  [ -f "$gd/KEEP" ]
}
detach_reparse_points() {  # $1=worktree path。内部の junction/symlink の「通路」だけ外す（リンク先の実体には触れない）
  # 深さ2まで走査（node_modules 等の共有リンクはトップ付近にある想定。リンクの中へは潜らない）
  local wt="$1" p
  find "$wt" -mindepth 1 -maxdepth 2 -type l 2>/dev/null | while read -r p; do
    rm "$p" 2>/dev/null && echo "    (リンク解除: $p)"
  done
  # Windows junction は MSYS の find/-type l に映らない場合があるため PowerShell でも検出。
  # DirectoryInfo.Delete()（非再帰）は reparse point 自体だけを消し、リンク先には触れない。
  # rmdir /s や Remove-Item -Recurse は junction を辿って実体を破壊するため絶対に使わない。
  if command -v powershell.exe >/dev/null 2>&1; then
    local wwt
    wwt="$(cygpath -w "$wt" 2>/dev/null)" || return 0
    powershell.exe -NoProfile -Command \
      "Get-ChildItem -LiteralPath '$wwt' -Directory -Force -Depth 1 -ErrorAction SilentlyContinue | Where-Object { \$_.Attributes -band [IO.FileAttributes]::ReparsePoint } | ForEach-Object { \$_.Delete(); \$_.FullName }" \
      2>/dev/null | tr -d '\r' | while read -r p; do
        [ -n "$p" ] && echo "    (junction解除: $p)"
      done
  fi
  return 0
}
RECENT_HOURS="${GIT_HYGIENE_RECENT_HOURS:-12}"
is_session_branch() { case "$1" in claude/*|codex/*) return 0 ;; *) return 1 ;; esac; }
recently_active() {  # $1=worktree path。HEAD が直近 RECENT_HOURS 時間内に動いたか（稼働中の代理指標）
  # 注: index は git status(read) で、ORIG_HEAD は reset/merge 等で汚れる/不定なため見ない。
  #     commit/checkout でのみ動く HEAD と、その reflog である logs/HEAD だけを見る。
  local gd f m now newest=0
  gd="$(git -C "$1" rev-parse --absolute-git-dir 2>/dev/null)" || return 1
  now="$(date +%s 2>/dev/null)" || return 1
  for f in "$gd/HEAD" "$gd/logs/HEAD"; do
    [ -e "$f" ] || continue
    m="$(stat -c %Y "$f" 2>/dev/null || echo 0)"
    [ "$m" -gt "$newest" ] && newest="$m"
  done
  [ "$newest" -gt 0 ] || return 1
  [ $(( now - newest )) -lt $(( RECENT_HOURS * 3600 )) ]
}

# ============ 1) worktree の closeout ============
echo "== worktree 棚卸し =="
git worktree list --porcelain | awk '/^worktree /{print $2}' | while read -r wt; do
  [ "$wt" = "$ROOT" ] && continue
  [ "$wt" = "$SELF_WT" ] && continue
  if br="$(git -C "$wt" symbolic-ref -q --short HEAD 2>/dev/null)"; then :; else br="(detached)"; fi
  dirty="$(git -C "$wt" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"

  # 残す指定（KEEP）
  if has_keep "$wt"; then
    echo "  KEEP    $wt  [$br]  ($(head -1 "$(git -C "$wt" rev-parse --absolute-git-dir)/KEEP" 2>/dev/null))"
    continue
  fi

  # 削除可否（fail-closed）
  #  - detached: HEAD が main内包なら可、未内包は REVIEW(手動)
  #  - セッションブランチ(claude/*,codex/*): マージ済PRのときだけ可（ahead=0だけでは消さない＝決定C-B）
  #  - その他: branch_merged（マージ済PR or main内包）
  deletable=0; why="未マージ"
  if [ "$br" = "(detached)" ]; then
    head_in_main "$wt" && deletable=1 || deletable=2
  elif is_session_branch "$br"; then
    if has_merged_pr "$br"; then deletable=1; else why="セッションブランチ・PR未マージ"; fi
  else
    branch_merged "$br" && deletable=1
  fi

  if [ "$deletable" = "2" ]; then
    echo "  REVIEW  $wt  [detached, HEAD未内包]  → 手動確認（自動では消さない）"; continue
  fi
  if [ "$deletable" != "1" ]; then
    echo "  keep    $wt  [$br]  ($why)"; continue
  fi
  # ユーザー保有は自動削除しない（決定C-B/決定B）
  if ! is_temp_location "$wt"; then
    echo "  OWNED(ユーザー保有・マージ済) $wt  [$br]  → 手動削除可。自動では消さない"; continue
  fi
  # 稼働中ガード（決定C-A）: 直近に使われていれば触らない
  if recently_active "$wt"; then
    echo "  SKIP(最近使用<${RECENT_HOURS}h) $wt  [$br]  → 稼働中の可能性。今回は触らない"; continue
  fi
  # ここまで来たら 一時用・削除可・非稼働 → closeout
  echo "  DELETE(一時用) $wt  [$br]  dirty=$dirty"
  [ "$br" != "(detached)" ] && echo "$br" >> "$TOREMOVE"
  if [ $APPLY -eq 1 ]; then
    if [ "$dirty" != "0" ]; then
      mkdir -p "$BACKUP"; safe="$(echo "$wt" | tr '/:\\' '___')"
      git -C "$wt" diff HEAD > "$BACKUP/$safe.patch" 2>/dev/null || true
      echo "    (未コミット差分を $BACKUP/$safe.patch に退避)"
    fi
    detach_reparse_points "$wt"
    git worktree remove --force "$wt" 2>/dev/null && echo "    removed" \
      || echo "    ★ 削除失敗（プロセスがロック中の可能性。セッションを閉じて再実行）"
  fi
done
[ $APPLY -eq 1 ] && git worktree prune

# ローカルブランチ削除の前に checked-out 集合を再計算（apply でworktreeを外した後の解放を反映）
CHECKED_OUT="$(checked_out_set)"

# ============ 2) ローカルブランチ ============
echo "== ローカルブランチ棚卸し =="
git for-each-ref --format='%(refname:short)' refs/heads/ | while read -r b; do
  if is_deletable "$b" || { branch_merged "$b" && grep -qxF "$b" "$TOREMOVE" 2>/dev/null; }; then
    echo "  DELETE local: $b"
    [ $APPLY -eq 1 ] && { git branch -D "$b" >/dev/null 2>&1 && echo "    deleted" || echo "    ★ 削除失敗（worktreeがまだ使用中）"; }
  fi
done

# ============ 3) リモートブランチ（--remote 時のみ） ============
if [ $REMOTE -eq 1 ]; then
  echo "== リモートブランチ棚卸し（--remote）=="
  git for-each-ref --format='%(refname:short)' refs/remotes/origin/ \
    | grep '^origin/' | sed 's#^origin/##' | grep -vxE "$MAIN|HEAD" | while read -r rb; do
      if is_deletable_remote "$rb"; then
        echo "  DELETE remote: $rb"
        [ $APPLY -eq 1 ] && { git push origin --delete "$rb" >/dev/null 2>&1 && echo "    deleted" || echo "    ★ push失敗"; }
      fi
    done
  [ $APPLY -eq 1 ] && git remote prune origin >/dev/null 2>&1
fi

# ============ 4) worktree置き場の孤立フォルダ（未登録・検出のみ・削除しない） ============
echo "== 参考: worktree置き場の孤立フォルダ（git未登録・検出のみ・削除しない）=="
REG="$(git worktree list --porcelain | awk '/^worktree /{print $2}')"
for base in "$ROOT/.claude/worktrees" "$HOME/.codex/worktrees"; do
  [ -d "$base" ] || continue
  for d in "$base"/*/; do
    [ -d "$d" ] || continue
    d="${d%/}"
    printf '%s\n' "$REG" | grep -qxF "$d" || echo "  ORPHAN(git未登録フォルダ): $d"
  done
done

echo "-------------------------------------------------------------"
if [ $APPLY -eq 0 ]; then
  echo "これはドライランです。実行するには: bash $(basename "$0") --apply [--remote]"
else
  echo "完了。残存: local=$(git branch | wc -l | tr -d ' ')本 / worktree=$(git worktree list | wc -l | tr -d ' ')個"
  [ -d "$BACKUP" ] && echo "退避パッチ: $BACKUP"
fi
