#!/usr/bin/env bash
# agent-team: SessionStart（起動・再開・圧縮後）に、agent-team 運用のリポジトリであることを親セッションへ知らせる。
# 圧縮でスキル本文と明示指定が消え、次の開発依頼で agent-team が使われなくなるのを防ぐ（2026-10-07）。
# 使い方: session-reminder.sh [--json]（--json は SessionStart hook 用。クラウドは bootstrap.sh が文字で取り込む）
# .agents/state が無いリポジトリでは何も出さない。サブエージェントでは SessionStart が動かないので、ワーカーには届かない。
root="${CLAUDE_PROJECT_DIR:-$PWD}"
proj=""
for c in "$root" "$root"/*/; do c="${c%/}"; [ -d "$c/.agents/state" ] && { proj="$c"; break; }; done
[ -z "$proj" ] && exit 0
active=$(ls "$proj/.agents/state/missions" 2>/dev/null | grep -E '^M-.*\.md$' | sed 's/\.md$//' | paste -sd' ' -)
msg="[agent-team] このリポジトリは agent-team 運用。機能追加・不具合修正・リファクタリングとその継続作業の依頼は、着手前に agent-team スキルを Skill ツールで読んでから進める（圧縮・再開の後も同じ。調査のみ・レビューのみ・誤字修正は対象外）。active ミッション: ${active:-なし}"
if [ "$1" = "--json" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$msg"
else
  echo "$msg"
fi
