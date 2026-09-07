#!/usr/bin/env bash
# Ponytail（DietrichGebert/ponytail）の更新と Codex hook 信頼の同期（ローカル用。AI が実行する）。
#
#   bash ~/.agents/skills/skill-ops/scripts/ponytail-sync.sh            # check: 導入版と repo の信頼ハッシュを照合
#   bash ~/.agents/skills/skill-ops/scripts/ponytail-sync.sh --update   # CC / Codex の Ponytail を最新化してから check
#   bash ~/.agents/skills/skill-ops/scripts/ponytail-sync.sh --sync-trust
#       # 人間が `codex` → `/hooks` で再信頼した後に実行。~/.codex/config.toml の 3 エントリを
#       # codex/hooks-state.toml に写す（publish は別途 publish.sh）。
#
# 役割分担: 検知と複製はこのスクリプト、信頼の判断（/hooks での承認）は人間。ハッシュを自分で書き込むことはしない。
# 終了コード: check で不一致なら 1（publish 前チェックや CI に使えるように）。

set -u
REPO="$HOME/.agents"
STATE="$REPO/codex/hooks-state.toml"
HASHER="$REPO/codex/hook-hash.py"
KEY_PREFIX="ponytail@ponytail:hooks/claude-codex-hooks.json"
PY=""
for c in python3 python; do
  if "$c" -c 'import hashlib' >/dev/null 2>&1; then PY="$c"; break; fi   # Windows のストア版偽 python3 を除外
done

log() { printf '[ponytail-sync] %s\n' "$*"; }

installed_hooks_json() {
  # Codex 側キャッシュを優先（信頼判定は Codex が行うため）。無ければ CC 側。
  local f
  f=$(ls -td "$HOME"/.codex/plugins/cache/ponytail/ponytail/*/ 2>/dev/null | head -1)
  [ -n "$f" ] && [ -f "${f}hooks/claude-codex-hooks.json" ] && { printf '%s' "${f}hooks/claude-codex-hooks.json"; return; }
  f=$(ls -td "$HOME"/.claude/plugins/cache/ponytail/ponytail/*/ 2>/dev/null | head -1)
  [ -n "$f" ] && [ -f "${f}hooks/claude-codex-hooks.json" ] && printf '%s' "${f}hooks/claude-codex-hooks.json"
}

do_update() {
  log "Claude Code: marketplace update → plugin update"
  claude plugin marketplace update ponytail && claude plugin update ponytail@ponytail || log "CC 側の更新に失敗（続行）"
  log "Codex: marketplace upgrade → plugin add（再 add で最新スナップショットに揃う）"
  codex plugin marketplace upgrade ponytail && codex plugin add ponytail@ponytail || log "Codex 側の更新に失敗（続行）"
}

do_check() {
  local hooks; hooks=$(installed_hooks_json)
  [ -n "$hooks" ] || { log "Ponytail の hooks JSON が見つからない（未導入）"; return 1; }
  [ -n "$PY" ] || { log "python が無いため照合不可"; return 1; }
  log "導入版: $hooks"
  local bad=0 seen=0 ev h stored
  while read -r ev h; do
    seen=$((seen+1))
    stored=$(grep -A1 "$KEY_PREFIX:$ev:" "$STATE" 2>/dev/null | grep -o 'sha256:[0-9a-f]*')
    if [ "$stored" = "$h" ]; then
      log "OK  $ev"
    else
      log "NG  $ev  repo=${stored:-なし}  導入版=$h"
      bad=1
    fi
  done < <("$PY" "$HASHER" "$hooks")
  [ "$seen" -ge 1 ] || { log "NG  ハッシュを 1 件も計算できなかった（hook-hash.py の実行失敗）"; bad=1; }
  if [ "$bad" -eq 0 ]; then
    log "一致: クラウドの Codex でも Ponytail hook は信頼済みとして動く"
  else
    log "不一致: Ponytail の hook 定義が変わった。手順 → (1) 人間が \`codex\` → /hooks で再信頼 (2) $0 --sync-trust (3) publish.sh"
  fi
  return $bad
}

do_sync_trust() {
  local cfg="$HOME/.codex/config.toml"
  local n; n=$(grep -c "^\[hooks.state.\"$KEY_PREFIX" "$cfg" 2>/dev/null)
  [ "${n:-0}" -eq 3 ] || { log "~/.codex/config.toml に Ponytail の信頼エントリが $n 件（3 件必要）。先に codex → /hooks で信頼してください"; return 1; }
  { sed -n '/^#/p' "$STATE"; echo; grep -A1 "^\[hooks.state.\"$KEY_PREFIX" "$cfg" | sed 's/^--$//'; } > "$STATE.tmp" \
    && mv "$STATE.tmp" "$STATE" && log "codex/hooks-state.toml を更新しました（人間が信頼した値の複製）" || { rm -f "$STATE.tmp"; return 1; }
  sed -i "s/^# 出所: .*/# 出所: ローカルで \`codex\` → \`\/hooks\` から人間が信頼した結果の複製（~\/.codex\/config.toml、$(date +%Y-%m-%d)）。/" "$STATE"
  do_check
}

case "${1:-}" in
  --update) do_update; do_check ;;
  --sync-trust) do_sync_trust ;;
  ""|--check) do_check ;;
  *) sed -n '2,12p' "$0"; exit 2 ;;
esac
