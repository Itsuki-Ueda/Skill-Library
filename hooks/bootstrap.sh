#!/usr/bin/env bash
# skill-library Plugin の SessionStart ブートストラップ。
#
# 役割は 2 つだけ:
#   1. ローカル（~/.agents が本物の clone）なら何もしない。
#      CLAUDE.md の @import が既に効いているので、二重にルールを注入しない。
#   2. クラウド（~/.agents が無い）なら、Plugin を最新化し、Plugin 展開先を ~/.agents としてリンクし、
#      Codex 側の設定を用意し、共通ルールを additionalContext として注入する。
#      Plugin 自体は環境の Setup script（cloud/setup.sh）がスナップショットに入れている。
#
# 既存スキル内の `~/.agents/skills/...` という絶対パス参照を書き換えずに動かすための仕組み。
set -euo pipefail

ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

log() { printf '[skill-library] %s\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# 1. ローカル判定
#    ~/.agents/skills/skill-ops/SKILL.md が実在し、かつ ~/.agents がシンボリック
#    リンクでない = clone が本物 = ローカル。何も出力せず終了する。
# ---------------------------------------------------------------------------
if [ -f "$HOME/.agents/skills/skill-ops/SKILL.md" ] && [ ! -L "$HOME/.agents" ]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# ここから先はクラウド分岐。診断のため実行環境を記録する
# （ローカル分岐は上で exit 済みなので、ローカルでは何も出力されない）。
# ---------------------------------------------------------------------------
log "CLAUDE_CODE_REMOTE=${CLAUDE_CODE_REMOTE:-unset}"

# ---------------------------------------------------------------------------
# 1.5. Plugin を最新化する
#      Setup script のスナップショットは約 7 日キャッシュされるため、これが無いと古いスキルを使い続ける。
#      反映は次セッションから（このセッションは既にロード済みの版で動く。遅れは最大 1 セッション）。
#      public repo なので認証は不要。失敗しても続行。
# ---------------------------------------------------------------------------
if [ "${CLAUDE_CODE_REMOTE:-}" = "true" ] && command -v claude >/dev/null 2>&1; then
  if claude plugin marketplace update ueda >/dev/null 2>&1 && claude plugin update skill-library@ueda >/dev/null 2>&1; then
    log "skill-library Plugin を最新化しました（反映は次セッション）"
  else
    log "skill-library Plugin の更新をスキップ（失敗・続行）"
  fi
  claude plugin marketplace update ponytail >/dev/null 2>&1 && claude plugin update ponytail@ponytail >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------------------
# 2. クラウド: ~/.agents を Plugin 展開先へ向ける
# ---------------------------------------------------------------------------
if [ ! -e "$HOME/.agents" ]; then
  ln -s "$ROOT" "$HOME/.agents" && log "~/.agents -> $ROOT をリンクしました"     || log "警告: ~/.agents のリンク作成に失敗しました"
elif [ -d "$HOME/.agents" ] && [ ! -L "$HOME/.agents" ]; then
  # Codex が ~/.agents/plugins を作っている等、ディレクトリが既にある場合は
  # 中身を個別にリンクする（ディレクトリ自体は置き換えない）。
  for entry in skills agents commands codex claude docs bin AGENTS.md; do
    [ -e "$ROOT/$entry" ] || continue
    target="$HOME/.agents/$entry"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
      # 実ディレクトリ/実ファイルが既にある。ln -sfn だとその中にリンクを作ってしまうので、
      # 空ディレクトリなら消してからリンク、それ以外は触らず警告する。
      if [ -d "$target" ] && rmdir "$target" 2>/dev/null; then
        :
      else
        log "既存の実ディレクトリ/ファイルのためスキップ: $target"
        continue
      fi
    fi
    ln -sfn "$ROOT/$entry" "$target" || log "警告: $target のリンク作成に失敗しました"
  done
  log "~/.agents 配下に $ROOT の各エントリを個別リンクしました"
fi

# ---------------------------------------------------------------------------
# 3. Codex 側の設定を用意する
#    Codex Plugin はカスタム Agent 定義を同梱できないため、TOML は実体をコピーする。
#    Codex 用スキルラッパーはリンクで足りる。
# ---------------------------------------------------------------------------
if [ -d "$ROOT/codex/agents" ]; then
  mkdir -p "$HOME/.codex/agents"
  cp -f "$ROOT"/codex/agents/*.toml "$HOME/.codex/agents/" 2>/dev/null || true
  log "~/.codex/agents に Agent 定義をコピーしました"
fi

if [ -d "$ROOT/codex/skills" ]; then
  mkdir -p "$HOME/.codex/skills"
  for d in "$ROOT"/codex/skills/*/; do
    [ -d "$d" ] || continue
    ln -sfn "${d%/}" "$HOME/.codex/skills/$(basename "$d")"       || log "警告: ~/.codex/skills/$(basename "$d") のリンク作成に失敗しました"
  done
  log "~/.codex/skills に Codex 用スキルラッパーをリンクしました"
fi

if [ ! -f "$HOME/.codex/AGENTS.md" ]; then
  mkdir -p "$HOME/.codex"
  cat > "$HOME/.codex/AGENTS.md" <<'CODEX_AGENTS_MD'
# Codex ルールの入口（このファイルは参照指示のみ）

**最初に次の 2 ファイルを読み、記載の全ルールに従うこと。**

1. `~/.agents/AGENTS.md` — CC・Codex 共通ルールの正本
2. `~/.agents/codex/AGENTS.md` — Codex 固有設定の正本

このファイル単体では不完全である。ルール本文をここに書き足さない（正本側へ書く）。
CODEX_AGENTS_MD
  log "~/.codex/AGENTS.md を作成しました"
fi

# ---------------------------------------------------------------------------
# 4. Codex CLI があれば marketplace 登録と Plugin 導入を試みる（失敗しても続行）
# ---------------------------------------------------------------------------
if command -v codex >/dev/null 2>&1; then
  if codex plugin marketplace list 2>/dev/null | grep -q 'ueda'; then
    log "codex marketplace ueda は登録済みのため add をスキップ"
  else
    codex plugin marketplace add Itsuki-Ueda/Skill-Library 1>&2 \
      || log "codex plugin marketplace add をスキップ（失敗）"
  fi
  codex plugin marketplace upgrade ueda 1>&2 \
    || log "codex plugin marketplace upgrade をスキップ（失敗）"
  codex plugin add skill-library@ueda 1>&2 \
    || log "codex plugin add をスキップ（既導入または失敗）"
  # Ponytail（DietrichGebert/ponytail）。hook は Codex 側の信頼確認（/hooks）が無いと動かない。
  # スキル（/ponytail 系）は信頼なしでも使える。
  if codex plugin marketplace list 2>/dev/null | grep -q 'ponytail'; then
    log "codex marketplace ponytail は登録済みのため add をスキップ"
  else
    codex plugin marketplace add DietrichGebert/ponytail 1>&2 \
      || log "codex plugin marketplace add ponytail をスキップ（失敗）"
  fi
  codex plugin add ponytail@ponytail 1>&2 \
    || log "codex plugin add ponytail をスキップ（既導入または失敗）"
  # Ponytail hook の信頼エントリを投入する。
  # 中身は植田さんがローカルの `codex` → `/hooks` で信頼した結果の複製（codex/hooks-state.toml、承認 2026-09-05）。
  TRUST_SRC="$CLAUDE_PLUGIN_ROOT/codex/hooks-state.toml"
  CODEX_CFG="$HOME/.codex/config.toml"
  if [ -f "$TRUST_SRC" ]; then
    if [ -f "$CODEX_CFG" ] && grep -q 'ponytail@ponytail:hooks/claude-codex-hooks.json' "$CODEX_CFG"; then
      log "Ponytail hook 信頼エントリは既に config.toml にあるためスキップ"
    else
      { printf '\n'; grep -v '^#' "$TRUST_SRC"; } >> "$CODEX_CFG" \
        && log "Ponytail hook 信頼エントリを ~/.codex/config.toml に追記しました" \
        || log "Ponytail hook 信頼エントリの追記に失敗（続行）"
    fi
  fi
else
  log "codex CLI 未検出、Codex 側導入スキップ"
fi

# ---------------------------------------------------------------------------
# 4.5. Codex のデバイス認証（サブスク認証）を自動で開始する
#      クラウドは毎回新規 VM なので ~/.codex/auth.json は残らない。
#      未認証なら `codex login --device-auth` をバックグラウンド起動し、
#      認証 URL とワンタイムコードを additionalContext で Claude に渡す。
#      人間がやるのはブラウザでの承認だけ。
# ---------------------------------------------------------------------------
CODEX_AUTH_NOTE=''

if ! command -v codex >/dev/null 2>&1; then
  log "codex CLI 未検出のためデバイス認証はスキップ"
elif [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  log "CLAUDE_CODE_REMOTE != true のためデバイス認証はスキップ"
elif codex login status >/dev/null 2>&1; then
  log "Codex 認証済み"
else
  mkdir -p "$HOME/.codex" || true
  LOGF="$HOME/.codex/device-auth.log"
  PIDF="$HOME/.codex/device-auth.pid"

  if pgrep -f 'codex login --device-auth' >/dev/null 2>&1; then
    log "device-auth プロセスが既に稼働中。既存ログを再利用します"
  else
    : > "$LOGF" || true
    if command -v setsid >/dev/null 2>&1; then
      nohup setsid codex login --device-auth </dev/null >"$LOGF" 2>&1 &
    else
      nohup codex login --device-auth </dev/null >"$LOGF" 2>&1 &
    fi
    AUTH_PID=$!
    printf '%s\n' "$AUTH_PID" > "$PIDF" || true
    log "codex login --device-auth を起動しました (pid=$AUTH_PID, log=$LOGF)"

    # 認証 URL が出力されるまで最大 20 秒待つ（0.5 秒間隔）。
    i=0
    while [ "$i" -lt 40 ]; do
      if grep -q 'http' "$LOGF" 2>/dev/null; then
        break
      fi
      sleep 0.5 || true
      i=$((i + 1))
    done
  fi

  AUTH_LOG_HEAD=$(head -30 "$LOGF" 2>/dev/null || true)
  if [ -n "$AUTH_LOG_HEAD" ]; then
    CODEX_AUTH_NOTE="【Codex 未認証・デバイス認証を起動済み】
セッション開始時に \`codex login --device-auth\` をバックグラウンドで起動しました（ログ: ~/.codex/device-auth.log）。
最初の返答で、他の作業より先に、次のログから認証 URL とワンタイムコードを抜き出してユーザーに提示し、ブラウザで承認するよう依頼してください。
承認の報告を受けたら \`codex login status\` で確認してください。
コードが期限切れ・ログが空の場合は \`codex login --device-auth\` を再実行し、新しい URL とコードを提示してください（プロセスは維持すること）。
--- device-auth ログ ---
$AUTH_LOG_HEAD"
  else
    CODEX_AUTH_NOTE="【Codex 未認証・デバイス認証を起動したが出力なし】
セッション開始時に \`codex login --device-auth\` を起動しましたが、20 秒待っても出力がありませんでした。
最初の返答で、他の作業より先に \`cat ~/.codex/device-auth.log\` を実行して認証 URL とワンタイムコードを確認し、ユーザーに提示してください。
ログが空なら \`codex login --device-auth\` を再実行し（プロセスは維持すること）、新しい URL とコードを提示してください。
承認の報告を受けたら \`codex login status\` で確認してください。"
  fi
fi

# ---------------------------------------------------------------------------
# 5. 共通ルールを additionalContext として注入する
# ---------------------------------------------------------------------------
NOTE='【skill-library Plugin 経由（クラウド環境）】スキルは `skill-library:<name>`、サブエージェントは `skill-library:<name>` の名前空間付きで見える。`~/.agents` は Plugin 展開先へのリンク。'

CONTEXT="$NOTE"
if [ -n "$CODEX_AUTH_NOTE" ]; then
  CONTEXT="$CONTEXT

$CODEX_AUTH_NOTE"
fi
for f in "$ROOT/AGENTS.md" "$ROOT/claude/CLAUDE.md"; do
  [ -f "$f" ] || continue
  CONTEXT="$CONTEXT
$(cat "$f")"
done

# JSON エスケープ: jq → python3 → python の順で使えるものを使う。
# どれも無ければ additionalContext なしで正常終了する。
if command -v jq >/dev/null 2>&1; then
  ESCAPED=$(printf '%s' "$CONTEXT" | jq -Rs .)
elif command -v python3 >/dev/null 2>&1 && python3 -c '' >/dev/null 2>&1; then
  # stdin をバイナリで読んで UTF-8 と明示デコードする。
  # ロケール依存のデコード（Windows の cp932 等）で文字化けさせないため。
  ESCAPED=$(printf '%s' "$CONTEXT" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.buffer.read().decode("utf-8")))')
elif command -v python >/dev/null 2>&1 && python -c '' >/dev/null 2>&1; then
  ESCAPED=$(printf '%s' "$CONTEXT" | python -c 'import json,sys;print(json.dumps(sys.stdin.buffer.read().decode("utf-8")))')
else
  log "jq / python が無いため additionalContext の注入をスキップしました"
  exit 0
fi

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}}\n' "$ESCAPED"
