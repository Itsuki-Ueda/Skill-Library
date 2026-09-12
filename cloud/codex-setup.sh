#!/usr/bin/env bash
# Codex クラウドの Environment の Setup script に貼り付ける内容。
#
# 前提:
# - Secret `CC_SUBSCRIPTION_TOKEN` は任意。登録した環境だけ Claude 連携が有効になる
#   （人間が `claude setup-token` の出力を登録する）。未登録ならスキル配置と CLI 導入だけ行う。
# - エージェント段階で次の4ドメインを許可する（POST を含む）: api.anthropic.com /
#   claude.ai / claude.com / platform.claude.com。Setup 段階はインターネット接続で
#   GitHub/npm から取得する。
# - 実行環境は Ubuntu 24.04 / root / Node.js / npm / Python 3 / git。
#   Secret は末尾改行なしで登録する。
# - Setup 結果のキャッシュは最大12時間（OpenAI の Cloud environments 仕様）。
#   https://learn.chatgpt.com/docs/environments/cloud-environment
#   Secret または Setup script の変更時は再構築が必要。
# - キャッシュに認証ファイルが残るため、その Environment にアクセスできる範囲だけで運用する。
# - Claude の単一リクエストと別タスク再利用は、キャッシュ無効の A/B 実測で確認済み。
#   キャッシュされた認証ファイルが別タスクで継続すること自体はこの構成では検証しない。
# - Secret が登録されているのに不正な場合は、起動を続行せず fail-closed で停止する。
# - トークンの期限は CLAUDE_TOKEN_ISSUED で管理。再発行時は Secret 更新＋この日付更新＋Setup 再実行。
#
# Secret は Setup 中にだけ読み、`~/.config/claude-subscription/oauth-token` (0600) に
# 書いた後は環境変数を破棄する。認証ファイルの内容や CLI の出力にはトークンを出さない。

set +x
set -euo pipefail
umask 077

readonly REPO_URL="https://github.com/Itsuki-Ueda/Skill-Library.git"
readonly REPO_BRANCH="main"
readonly SKILL_LIBRARY_ROOT="/root/.local/share/skill-library"
readonly AUTH_DIR="/root/.config/claude-subscription"
readonly AUTH_FILE="${AUTH_DIR}/oauth-token"
readonly CLAUDE_TOKEN_ISSUED="2026-09-12"   # `claude setup-token` を実行した日。再発行したら更新する
readonly CLAUDE_TOKEN_TTL_DAYS=365          # setup-token の有効期間（Anthropic 公式）
readonly CLAUDE_TOKEN_WARN_DAYS=30

fail() {
  printf 'codex cloud setup: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "必要なコマンドがありません: $1"
}

[ "$(id -u)" -eq 0 ] || fail 'Codex クラウドの root Ubuntu 環境で実行してください'
[ "${HOME:-}" = /root ] || fail 'Codex クラウドの HOME=/root 環境で実行してください'

write_auth_file() {
  case "$CC_SUBSCRIPTION_TOKEN" in
    sk-ant-oat01-*) ;;
    *) fail '`claude setup-token` が表示した最終トークンを Secret に登録してください' ;;
  esac
  case "$CC_SUBSCRIPTION_TOKEN" in
    *[[:space:]]*) fail 'Secret CC_SUBSCRIPTION_TOKEN に空白が含まれています' ;;
  esac

  if [ -L "$AUTH_DIR" ]; then
    fail "認証ディレクトリがシンボリックリンクです: $AUTH_DIR"
  fi
  mkdir -p "$AUTH_DIR"
  chmod 700 "$AUTH_DIR"
  if [ -L "$AUTH_FILE" ]; then
    fail "認証ファイルがシンボリックリンクです: $AUTH_FILE"
  fi
  if [ -e "$AUTH_FILE" ] && [ ! -f "$AUTH_FILE" ]; then
    fail "認証ファイルの保存先が通常ファイルではありません: $AUTH_FILE"
  fi

  local tmp_file
  tmp_file=$(mktemp "$AUTH_DIR/.oauth-token.XXXXXX")
  trap 'rm -f "$tmp_file"' RETURN
  chmod 600 "$tmp_file"
  printf '%s' "$CC_SUBSCRIPTION_TOKEN" >"$tmp_file"
  mv -f "$tmp_file" "$AUTH_FILE"
  trap - RETURN
  unset CC_SUBSCRIPTION_TOKEN
}

update_repository() {
  mkdir -p "$(dirname "$SKILL_LIBRARY_ROOT")"
  if [ -L "$SKILL_LIBRARY_ROOT" ]; then
    fail "Skill-Library の配置先がシンボリックリンクです: $SKILL_LIBRARY_ROOT"
  elif [ -d "$SKILL_LIBRARY_ROOT/.git" ]; then
    [ -z "$(git -C "$SKILL_LIBRARY_ROOT" status --porcelain)" ] \
      || fail "Skill-Library の作業ツリーが汚れています: $SKILL_LIBRARY_ROOT"
    [ "$(git -C "$SKILL_LIBRARY_ROOT" remote get-url origin)" = "$REPO_URL" ] \
      || fail "Skill-Library の origin が想定外です"
    [ "$(git -C "$SKILL_LIBRARY_ROOT" branch --show-current)" = "$REPO_BRANCH" ] \
      || fail "Skill-Library が $REPO_BRANCH ブランチではありません"
    git -C "$SKILL_LIBRARY_ROOT" pull --ff-only origin "$REPO_BRANCH"
  elif [ -e "$SKILL_LIBRARY_ROOT" ] || [ -L "$SKILL_LIBRARY_ROOT" ]; then
    fail "Skill-Library の配置先が Git リポジトリではありません: $SKILL_LIBRARY_ROOT"
  else
    git clone --depth 1 --branch "$REPO_BRANCH" --single-branch \
      "$REPO_URL" "$SKILL_LIBRARY_ROOT"
  fi

  [ -f "$SKILL_LIBRARY_ROOT/AGENTS.md" ] || fail 'Skill-Library/AGENTS.md がありません'
  [ -d "$SKILL_LIBRARY_ROOT/codex/agents" ] || fail 'Skill-Library/codex/agents がありません'
  [ -d "$SKILL_LIBRARY_ROOT/codex/skills" ] || fail 'Skill-Library/codex/skills がありません'
}

ensure_layout() {
  python3 - "$SKILL_LIBRARY_ROOT" "$HOME" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve(strict=True)
home = Path(sys.argv[2]).resolve(strict=True)
codex_home = home / ".codex"

def link(source: Path, target: Path) -> None:
    source = source.resolve(strict=True)
    if target.is_symlink():
        if target.resolve(strict=True) != source:
            raise RuntimeError(f"リンク先が異なります: {target}")
        return
    if target.exists():
        raise RuntimeError(f"既存パスと競合しています: {target}")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.symlink_to(source, target_is_directory=source.is_dir())

link(root, home / ".agents")

agent_sources = sorted((root / "codex" / "agents").glob("*.toml"))
if not agent_sources:
    raise RuntimeError("codex/agents に Agent 定義がありません")
for source in agent_sources:
    link(source, codex_home / "agents" / source.name)

skill_sources = sorted(path for path in (root / "codex" / "skills").iterdir() if path.is_dir())
if not skill_sources:
    raise RuntimeError("codex/skills にスキルがありません")
for source in skill_sources:
    link(source, codex_home / "skills" / source.name)

entry = codex_home / "AGENTS.md"
expected = "Read ~/.agents/AGENTS.md and ~/.agents/codex/AGENTS.md before working.\n"
if entry.is_symlink() or (entry.exists() and entry.read_text(encoding="utf-8") != expected):
    raise RuntimeError(f"既存の Codex ルールと競合しています: {entry}")
if not entry.exists():
    entry.parent.mkdir(parents=True, exist_ok=True)
    entry.write_text(expected, encoding="utf-8")
PY
}

check_auth_file() {
  [ ! -L "$AUTH_DIR" ] || fail "認証ディレクトリがシンボリックリンクです: $AUTH_DIR"
  [ -d "$AUTH_DIR" ] || fail "認証ディレクトリがありません。Setup を再実行してください: $AUTH_DIR"
  [ "$(stat -c '%a' "$AUTH_DIR")" = 700 ] \
    || fail "認証ディレクトリの権限が 700 ではありません: $AUTH_DIR"
  [ -f "$AUTH_FILE" ] || fail "認証ファイルがありません。Setup を再実行してください: $AUTH_FILE"
  [ ! -L "$AUTH_FILE" ] || fail "認証ファイルがシンボリックリンクです: $AUTH_FILE"
  [ "$(stat -c '%a' "$AUTH_FILE")" = 600 ] \
    || fail "認証ファイルの権限が 600 ではありません: $AUTH_FILE"
}

check_token_expiry() {
  local expires_at now remaining_days
  expires_at=$(date -d "$CLAUDE_TOKEN_ISSUED + $CLAUDE_TOKEN_TTL_DAYS days" +%s) || fail "CLAUDE_TOKEN_ISSUED の日付を解釈できません: $CLAUDE_TOKEN_ISSUED"
  now=$(date +%s)
  if [ "$now" -ge "$expires_at" ]; then
    fail "Claude トークンの期限切れ（発行 $CLAUDE_TOKEN_ISSUED）。人間が claude setup-token で再発行し、Secret CC_SUBSCRIPTION_TOKEN を更新して CLAUDE_TOKEN_ISSUED を書き換えてください"
  fi
  remaining_days=$(( (expires_at - now) / 86400 ))
  if [ "$remaining_days" -le "$CLAUDE_TOKEN_WARN_DAYS" ]; then
    printf 'codex cloud setup: 警告: Claude トークンの期限まで残り %s 日（発行 %s）\n' "$remaining_days" "$CLAUDE_TOKEN_ISSUED" >&2
  fi
}

case "${1:-setup}" in
  --maintenance)
    require_command git
    require_command python3
    update_repository
    ensure_layout
    if [ -f "$AUTH_FILE" ]; then
      check_auth_file
      check_token_expiry
      claude_linked=1
    else
      printf 'codex cloud maintenance: Claude 連携なし（認証ファイルなし）のまま続行します\n' >&2
      claude_linked=0
    fi
    printf 'CODEX_CLOUD_MAINTENANCE_OK claude_linked=%s\n' "$claude_linked"
    ;;
  setup)
    require_command git
    require_command python3
    require_command npm
    if [ -n "${CC_SUBSCRIPTION_TOKEN:-}" ]; then
      write_auth_file
      claude_linked=1
    else
      printf 'codex cloud setup: Secret CC_SUBSCRIPTION_TOKEN 未登録のため Claude 連携なしで続行します（スキル配置のみ）\n' >&2
      claude_linked=0
    fi
    update_repository
    timeout 180 npm install -g --no-audit --no-fund @openai/codex @anthropic-ai/claude-code
    require_command claude
    require_command codex
    ensure_layout
    if [ "$claude_linked" -eq 1 ]; then
      check_auth_file
      check_token_expiry
    fi
    printf 'CODEX_CLOUD_SETUP_OK claude_linked=%s\n' "$claude_linked"
    ;;
  *)
    fail "使い方: $0 [--maintenance]"
    ;;
esac
