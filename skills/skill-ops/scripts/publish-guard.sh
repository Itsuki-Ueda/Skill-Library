#!/usr/bin/env bash
# publish-guard.sh — public リポジトリ（~/.agents = Itsuki-Ueda/Skill-Library）に
# 非公開情報を載せないための機械検査。境界の正本は skill-ops SKILL.md「公開範囲」節。
#
# 使い方:
#   publish-guard.sh            追跡済み＋未追跡（.gitignore 除外後）の全ファイルを検査
#   publish-guard.sh --staged   stage 済みファイルだけ検査（.githooks/pre-commit が使う）
#
# 判定:
#   BLOCK パターンにヒット → 一覧を表示して exit 1（commit / publish が止まる）
#   WARN  パターンのみ      → 表示して exit 0
#
# パターンの置き場:
#   汎用（メール・トークン・秘密鍵）はこのスクリプト内。
#   固有名詞（勤務先 org・業務リポジトリ名・案件名 等）は **repo に置けない**（置いた瞬間に公開される）ので
#   ~/.config/skill-library/denylist.txt から読む（1 行 1 パターン、ERE、# 行と空行は無視）。
#   このファイルは repo 外・PC ローカル。新しい固有名詞が出たら、書く前にここへ足す。
set -u
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
DENY="${SKILL_LIBRARY_DENYLIST:-$HOME/.config/skill-library/denylist.txt}"
SELF="skills/skill-ops/scripts/publish-guard.sh"
cd "$REPO" || exit 1

if [ "${1:-}" = "--staged" ]; then
  FILES=$(git diff --cached --name-only --diff-filter=ACMR)
else
  FILES=$( { git ls-files; git ls-files -o --exclude-standard; } | sort -u)
fi
FILES=$(printf '%s\n' "$FILES" | grep -v -x "$SELF" | grep -v '^$' || true)
[ -n "$FILES" ] || { echo "[publish-guard] 検査対象なし"; exit 0; }

# grep -I: バイナリを除外。-n: 行番号。-H: ファイル名。
scan() { printf '%s\n' "$FILES" | tr '\n' '\0' | xargs -0 grep -InHE -- "$1" 2>/dev/null || true; }

BLOCK=""
# 1) 実在しうるメールアドレス（GitHub の noreply と example ドメインは許可）
hits=$(scan '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' \
       | grep -vE 'users\.noreply\.github\.com|noreply@|@example\.(com|org|net)|example@|@github\.com/' || true)  # 最後は URL 例（user:token@github.com/...）
[ -n "$hits" ] && BLOCK="$BLOCK
[メールアドレス]
$hits"
# 2) トークン・鍵の形をした文字列
hits=$(scan 'github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|eyJ[A-Za-z0-9_-]{20,}\.eyJ[A-Za-z0-9_-]{20,}')
[ -n "$hits" ] && BLOCK="$BLOCK
[トークン・鍵]
$hits"
# 3) ローカル denylist（固有名詞）
if [ -f "$DENY" ]; then
  pats=$(grep -vE '^\s*(#|$)' "$DENY" | paste -sd'|' -)
  if [ -n "$pats" ]; then
    hits=$(scan "$pats")
    [ -n "$hits" ] && BLOCK="$BLOCK
[denylist: $DENY]
$hits"
  fi
else
  echo "[publish-guard] 警告: denylist が無い（$DENY）。固有名詞の検査をスキップし、汎用検査のみ実施。" >&2
fi

# WARN: このPC固有の絶対パス（公開しても害は小さいが、クラウドで解決しない。~/.agents/... に直す）
WARN=$(scan 'C:\\Users\\[A-Za-z0-9_.-]+|/c/Users/[A-Za-z0-9_.-]+' || true)

if [ -n "$WARN" ]; then
  echo "[publish-guard] WARN: PC 固有の絶対パス（~/.agents/... に書き直すこと。今回は通す）" >&2
  printf '%s\n' "$WARN" | sed 's/^/  /' | cut -c1-160 >&2
fi
if [ -n "$BLOCK" ]; then
  echo "[publish-guard] BLOCK: 非公開情報の疑い。修正するまで commit / publish できません。" >&2
  printf '%s\n' "$BLOCK" | sed 's/^/  /' | cut -c1-200 >&2
  echo "[publish-guard] 誤検知なら denylist / 許可条件を見直す（skill-ops「公開範囲」）。" >&2
  exit 1
fi
echo "[publish-guard] OK: 非公開情報のヒットなし"
exit 0
