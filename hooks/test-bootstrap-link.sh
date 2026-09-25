#!/usr/bin/env bash
# bootstrap.sh の「~/.agents を今の Plugin 版へ向ける」処理の確認。一時 HOME で実行し、実環境には触れない。
# Windows の Git Bash の ln -s は本物のリンクを作らないので、WSL か Linux で実行する
# （WSL からは /mnt/c 配下の ~/.agents/hooks/test-bootstrap-link.sh を bash で実行。Git Bash から呼ぶなら MSYS_NO_PATHCONV=1）。
set -u
BS="${1:-$(cd "$(dirname "$0")" && pwd)/bootstrap.sh}"
T=$(mktemp -d); export HOME="$T/home"; mkdir -p "$HOME" "$T/cache/v1/skills" "$T/cache/v2/skills"
run() { PATH=/usr/bin:/bin CLAUDE_CODE_REMOTE= CLAUDE_PLUGIN_ROOT="$1" bash "$BS" >/dev/null 2>"$T/log" || { echo "  bootstrap rc=$?: $(cat "$T/log")"; }; }
fail=0
check() { [ "$(readlink "$HOME/.agents")" = "$1" ] && echo "  OK" || { echo "  NG: $(readlink "$HOME/.agents") (expected $1)"; fail=1; }; }
echo "1) 初回（リンク無し）→ v1";              run "$T/cache/v1"; check "$T/cache/v1"
echo "2) 同じ版で再実行 → 変化なし";            run "$T/cache/v1"; check "$T/cache/v1"
echo "3) Plugin 更新後（v2）→ v2 へ張り直す";    run "$T/cache/v2"; check "$T/cache/v2"
{ [ -e "$T/cache/v2/v1" ] || [ -L "$T/cache/v2/v1" ]; } && { echo "  NG: v2 の中にリンクが作られた"; fail=1; }
echo "4) 古い版が削除され壊れたリンク → v2";    ln -sfn "$T/cache/gone" "$HOME/.agents"; run "$T/cache/v2"; check "$T/cache/v2"
echo "5) 実ディレクトリ（個別リンク方式）は置き換えない"; rm "$HOME/.agents"; mkdir "$HOME/.agents"; run "$T/cache/v2"
if [ -d "$HOME/.agents" ] && [ ! -L "$HOME/.agents" ] && [ "$(readlink "$HOME/.agents/skills")" = "$T/cache/v2/skills" ]; then
  echo "  OK"
else
  echo "  NG"; fail=1
fi
rm -rf "$T"
[ $fail = 0 ] && echo "ALL OK" || { echo "FAILED"; exit 1; }
