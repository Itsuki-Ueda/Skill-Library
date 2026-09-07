#!/usr/bin/env bash
# skill-library クラウド接続の自己診断スクリプト。
#
# 使い方（クラウドセッション内）:
#   Claude に次のように頼む:
#     「`bash /home/user/{リポジトリ名}/cloud/selfcheck.sh` を実行して出力をそのまま報告して」
#     （$CLAUDE_PROJECT_DIR は hook 実行時しか設定されないため、通常のプロンプトでは実パスを書く）
#   Plugin 経由で ~/.agents が用意されていれば、次でも同じものが実行できる:
#     bash ~/.agents/cloud/selfcheck.sh
#
# 全項目を最後まで報告するため `set -e` は付けない（`set -u` のみ）。
# 各項目を OK / NG / SKIP の 1 行で出し、最後に NG 件数を表示する。終了コードは常に 0。
set -u

NG_COUNT=0

ok()   { printf 'OK   | %s\n' "$*"; }
ng()   { printf 'NG   | %s\n' "$*"; NG_COUNT=$((NG_COUNT + 1)); }
skip() { printf 'SKIP | %s\n' "$*"; }
info() { printf '     |   %s\n' "$*"; }

echo "===== skill-library クラウド自己診断 ====="
echo "実行日時: $(date 2>/dev/null || echo '取得不可')"
echo

# --- 1. クラウド判定 -------------------------------------------------------
echo "[1] 実行環境（CLAUDE_CODE_REMOTE）"
REMOTE_VAL="${CLAUDE_CODE_REMOTE:-unset}"
if [ "$REMOTE_VAL" = "true" ]; then
  ok "CLAUDE_CODE_REMOTE=true（クラウド環境で実行中）"
else
  ng "CLAUDE_CODE_REMOTE=${REMOTE_VAL}（クラウドではない可能性。ローカル実行ならこの NG は想定内）"
fi
echo

# --- 2. Plugin キャッシュ --------------------------------------------------
echo "[2] Plugin キャッシュ（~/.claude/plugins/cache/ueda/skill-library/）"
PLUGIN_CACHE="$HOME/.claude/plugins/cache/ueda/skill-library"
if [ -d "$PLUGIN_CACHE" ]; then
  VERSIONS=$(ls -1 "$PLUGIN_CACHE" 2>/dev/null)
  if [ -n "$VERSIONS" ]; then
    ok "キャッシュディレクトリあり、バージョンディレクトリを検出"
    printf '%s\n' "$VERSIONS" | while IFS= read -r v; do
      [ -n "$v" ] && info "version: $v"
    done
  else
    ng "キャッシュディレクトリはあるが中身が空（Plugin の取得に失敗している可能性）"
  fi
else
  ng "キャッシュディレクトリが存在しない: $PLUGIN_CACHE"
fi
echo

# --- 3. installed_plugins.json --------------------------------------------
echo "[3] Plugin 導入登録（~/.claude/plugins/installed_plugins.json。環境の Setup script が導入する）"
INSTALLED_JSON="$HOME/.claude/plugins/installed_plugins.json"
if [ -f "$INSTALLED_JSON" ]; then
  if grep -q 'skill-library@ueda' "$INSTALLED_JSON" 2>/dev/null; then
    ok "installed_plugins.json に skill-library@ueda を検出"
  elif grep -q 'skill-library' "$INSTALLED_JSON" 2>/dev/null; then
    ng "skill-library の記載はあるが 'skill-library@ueda' の形では見つからない"
  else
    ng "installed_plugins.json に skill-library が見つからない"
  fi
  if grep -q 'ponytail@ponytail' "$INSTALLED_JSON" 2>/dev/null; then
    ok "installed_plugins.json に ponytail@ponytail を検出"
  else
    ng "installed_plugins.json に ponytail@ponytail が無い（Setup script の Ponytail 導入が失敗した可能性）"
  fi
else
  ng "installed_plugins.json が存在しない: $INSTALLED_JSON"
fi
echo

# --- 4. ~/.agents リンク ---------------------------------------------------
echo "[4] ~/.agents の状態"
if [ -L "$HOME/.agents" ]; then
  ok "~/.agents はシンボリックリンク"
  info "リンク先: $(readlink "$HOME/.agents" 2>/dev/null || echo '取得不可')"
elif [ -d "$HOME/.agents" ]; then
  skip "~/.agents は実ディレクトリ（ローカル clone、または bootstrap が個別リンク方式を採った場合）"
else
  ng "~/.agents が存在しない（bootstrap hook が動いていない可能性）"
fi

if [ -r "$HOME/.agents/skills/skill-ops/SKILL.md" ]; then
  ok "~/.agents/skills/skill-ops/SKILL.md が読める"
else
  ng "~/.agents/skills/skill-ops/SKILL.md が読めない"
fi
echo

# --- 5. スキル数 -----------------------------------------------------------
echo "[5] ~/.agents/skills のスキル数"
if [ -d "$HOME/.agents/skills" ]; then
  SKILL_COUNT=$(find "$HOME/.agents/skills" -maxdepth 1 -mindepth 1 2>/dev/null | wc -l | tr -d ' ')
  if [ "${SKILL_COUNT:-0}" -gt 0 ] 2>/dev/null; then
    ok "スキル数: ${SKILL_COUNT}"
  else
    ng "スキルが 0 件"
  fi
else
  ng "~/.agents/skills が存在しない"
fi
echo

# --- 6. Codex 側の配置 -----------------------------------------------------
echo "[6] Codex 側の配置（~/.codex/）"
CODEX_AGENT_COUNT=$(ls -1 "$HOME"/.codex/agents/*.toml 2>/dev/null | wc -l | tr -d ' ')
if [ "${CODEX_AGENT_COUNT:-0}" -gt 0 ] 2>/dev/null; then
  ok "~/.codex/agents/*.toml: ${CODEX_AGENT_COUNT} 件"
else
  ng "~/.codex/agents/*.toml が 0 件（bootstrap のコピーが動いていない可能性）"
fi

if [ -d "$HOME/.codex/skills" ]; then
  CODEX_SKILL_COUNT=$(find "$HOME/.codex/skills" -maxdepth 1 -mindepth 1 2>/dev/null | wc -l | tr -d ' ')
  ok "~/.codex/skills の項目数: ${CODEX_SKILL_COUNT}"
  find "$HOME/.codex/skills" -maxdepth 1 -mindepth 1 2>/dev/null | while IFS= read -r s; do
    [ -n "$s" ] && info "$(basename "$s")"
  done
else
  ng "~/.codex/skills が存在しない"
fi

if [ -f "$HOME/.codex/AGENTS.md" ]; then
  ok "~/.codex/AGENTS.md あり"
else
  ng "~/.codex/AGENTS.md が無い"
fi
echo

# --- 7. Codex CLI ----------------------------------------------------------
echo "[7] Codex CLI"
if command -v codex >/dev/null 2>&1; then
  ok "codex コマンドあり: $(command -v codex)"
  info "version: $(codex --version 2>&1 | head -1)"
  CODEX_AVAILABLE=1
else
  ng "codex コマンドが無い（Setup script の npm install が失敗した可能性）"
  CODEX_AVAILABLE=0
fi
echo

# --- 8. Codex Plugin 登録状況 ---------------------------------------------
echo "[8] Codex 側の marketplace / plugin 登録"
if [ "$CODEX_AVAILABLE" -eq 1 ]; then
  MP_OUT=$(codex plugin marketplace list 2>&1)
  if printf '%s' "$MP_OUT" | grep -q 'ueda'; then
    ok "codex plugin marketplace list に ueda を検出"
  else
    ng "codex plugin marketplace list に ueda が無い"
    info "出力: $(printf '%s' "$MP_OUT" | head -3 | tr '\n' ' ')"
  fi

  PL_OUT=$(codex plugin list 2>&1)
  if printf '%s' "$PL_OUT" | grep -q 'skill-library'; then
    ok "codex plugin list に skill-library を検出"
  else
    ng "codex plugin list に skill-library が無い"
    info "出力: $(printf '%s' "$PL_OUT" | head -3 | tr '\n' ' ')"
  fi
  if printf '%s' "$PL_OUT" | grep -q 'ponytail@ponytail'; then
    ok "codex plugin list に ponytail@ponytail を検出"
  else
    ng "codex plugin list に ponytail@ponytail が無い"
  fi
  CODEX_CFG="$HOME/.codex/config.toml"
  if [ -f "$CODEX_CFG" ] && grep -q "ponytail@ponytail:hooks/claude-codex-hooks.json" "$CODEX_CFG" 2>/dev/null; then
    ok "config.toml に Ponytail hook の信頼エントリあり"
    # 導入版の hook 定義から計算したハッシュと一致するか（不一致 = Codex 上で「Modified」扱いになり hook は動かない）
    PONY_HOOKS=$(ls -td "$HOME"/.codex/plugins/cache/ponytail/ponytail/*/ 2>/dev/null | head -1)hooks/claude-codex-hooks.json
    HASHER="$HOME/.agents/codex/hook-hash.py"
    if [ -f "$PONY_HOOKS" ] && [ -f "$HASHER" ] && command -v python3 >/dev/null 2>&1; then
      MISMATCH=0
      while read -r ev h; do
        grep -q "$h" "$CODEX_CFG" 2>/dev/null || MISMATCH=1
      done < <(python3 "$HASHER" "$PONY_HOOKS")
      if [ "$MISMATCH" -eq 0 ]; then
        ok "信頼ハッシュが導入版 Ponytail の hook 定義と一致（常時モード有効）"
      else
        ng "信頼ハッシュが導入版と不一致（Ponytail 更新で hook 定義が変わった。ローカルで再信頼 → ponytail-sync.sh --sync-trust → publish）"
      fi
    else
      skip "ハッシュ照合をスキップ（hooks JSON / hook-hash.py / python3 のいずれかが無い）"
    fi
  else
    skip "config.toml に Ponytail hook の信頼エントリ無し（/ponytail スキルは使えるが常時モードは無効。cloud/README.md「Ponytail」参照）"
  fi
else
  skip "codex CLI が無いため marketplace / plugin の確認をスキップ"
fi
echo

# --- 9. jq / python3 -------------------------------------------------------
echo "[9] JSON エスケープ用ツール（bootstrap.sh が使う）"
if command -v jq >/dev/null 2>&1; then
  ok "jq あり: $(jq --version 2>&1)"
else
  skip "jq 無し（python3 があれば bootstrap は動く）"
fi
if command -v python3 >/dev/null 2>&1; then
  ok "python3 あり: $(python3 --version 2>&1)"
else
  skip "python3 無し"
fi
if ! command -v jq >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
  ng "jq も python3 も無い（additionalContext の注入がスキップされる）"
fi
echo

# --- 10. Node --------------------------------------------------------------
echo "[10] Node.js"
if command -v node >/dev/null 2>&1; then
  ok "node: $(node --version 2>&1)"
else
  ng "node コマンドが無い"
fi
echo

# --- 11. Codex のサブスク認証 ----------------------------------------------
echo "[11] Codex の認証状態（サブスク / device-auth）"
if [ "$CODEX_AVAILABLE" -eq 1 ]; then
  if codex login status >/dev/null 2>&1; then
    ok "codex login status: 認証済み"
  else
    ng "codex login status: 未認証（bootstrap が起動した device-auth の URL をブラウザで承認してください）"
  fi
else
  skip "codex CLI が無いため認証状態の確認をスキップ"
fi

DEVICE_AUTH_LOG="$HOME/.codex/device-auth.log"
if [ -f "$DEVICE_AUTH_LOG" ]; then
  ok "~/.codex/device-auth.log あり（$(wc -l < "$DEVICE_AUTH_LOG" 2>/dev/null | tr -d ' ') 行）"
else
  skip "~/.codex/device-auth.log が無い（既に認証済み、またはローカル実行）"
fi
echo

echo "===== 診断終了: NG ${NG_COUNT} 件 ====="
exit 0
