#!/usr/bin/env bash
# Claude Code クラウド環境（claude.ai/code）の Setup script に貼り付ける内容。
#
# 貼り付け先: claude.ai/code の環境（Environment）設定ダイアログの「Setup script」欄。
#   - 実行ユーザーは root、OS は Ubuntu 24.04。
#   - **初回のみ実行され、結果はファイルシステムのスナップショットとして約 7 日キャッシュされる。**
#     このファイルの内容を変更して貼り直すと再実行される。
#   - 制限時間は 5 分。**終了コードは必ず 0**（非ゼロだとセッションの起動そのものが失敗する）。
#     そのため全コマンドを `|| true` で受け、最後に明示的に `exit 0` する。
#   - Node.js 20/21/22 は同梱済み（v22 が PATH）。npm も使える。
#   - Trusted ネットワークには npm と GitHub は含まれるが、**OpenAI のドメインは含まれない**。
#     Codex CLI のインストールはできるが、実行・ログインには別途ドメイン許可が必要。
#
# ここが Plugin 導入の**唯一の経路**（2026-09-07 決定）。
#   Skill-Library は public リポジトリなので、認証なしで marketplace add / install が通る
#   （同じ経路の Ponytail で実証済み）。作業リポジトリ側の .claude/settings.json には何も置かない。
#   スナップショットが古くなる問題は、Plugin 自身の SessionStart hook（hooks/bootstrap.sh）が
#   毎セッション `claude plugin update` を実行して埋める（反映は次セッションから）。

echo "=== skill-library cloud setup 開始 ==="

# --- Codex CLI（Node 同梱のため npm でそのまま入る） ---
npm install -g @openai/codex || true

# --- jq（hooks/bootstrap.sh の JSON エスケープ用。python3 フォールバックがあるので必須ではない） ---
command -v jq >/dev/null 2>&1 || {
  apt-get update -qq || true
  apt-get install -y -qq jq || true
} || true

# --- Plugin をスナップショットに焼き込む ---
CLAUDE_BIN="$(command -v claude || true)"
[ -n "$CLAUDE_BIN" ] || CLAUDE_BIN=/opt/claude-code/bin/claude
echo "--- plugins ---"
if [ ! -x "$CLAUDE_BIN" ]; then
  echo "claude CLI が見つかりません（$CLAUDE_BIN）。Plugin 導入をスキップします"
else
  "$CLAUDE_BIN" plugin marketplace add Itsuki-Ueda/Skill-Library || true
  "$CLAUDE_BIN" plugin install skill-library@ueda || true
  "$CLAUDE_BIN" plugin marketplace add DietrichGebert/ponytail || true
  "$CLAUDE_BIN" plugin install ponytail@ponytail || true
  echo "--- plugin cache ---"
  ls -d "$HOME"/.claude/plugins/cache/ueda/skill-library/*/ || echo "skill-library のキャッシュなし"
  ls -d "$HOME"/.claude/plugins/cache/ponytail/ponytail/*/ || echo "ponytail のキャッシュなし"
fi

# --- 導入結果の表示（失敗しても続行） ---
echo "--- versions ---"
node --version || true
codex --version || true
jq --version || true

echo "=== skill-library cloud setup 完了 ==="
exit 0
