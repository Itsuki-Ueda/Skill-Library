#!/usr/bin/env bash
# agent-team: 画面をヘッドレスブラウザで1枚撮る（dispatch「画面確認」の前倒し用。プレビュー画面を使わないので並行できる）。
#
#   capture.sh --url <url> --out <png> [--serve "<開発サーバ起動コマンド>" --serve-cwd <dir>]
#              [--size 1280,800] [--wait-ms 10000] [--timeout 120] [--no-browser-sandbox]
#
# --serve を付けると、サーバを起動 → URL が 200 を返すまで待つ → 撮影 → サーバをプロセスツリーごと停止、まで行う。
# --no-browser-sandbox は Codex の restricted sandbox 内で撮るときだけ使う（ブラウザ内の安全装置と二重になり落ちるため）。
# 開くのは自分のアプリ（localhost）に限る。外部サイトには使わない。
set -u
url= out= serve= serve_cwd=. size=1280,800 wait_ms=10000 limit=120 nosbx=
while [ $# -gt 0 ]; do
  case $1 in
    --url) url=$2; shift ;; --out) out=$2; shift ;; --serve) serve=$2; shift ;;
    --serve-cwd) serve_cwd=$2; shift ;; --size) size=$2; shift ;; --wait-ms) wait_ms=$2; shift ;;
    --timeout) limit=$2; shift ;; --no-browser-sandbox) nosbx=1 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
[ -n "$url" ] && [ -n "$out" ] || { echo "--url and --out are required" >&2; exit 2; }

win=; case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) win=1 ;; esac
native() { if [ -n "$win" ]; then cygpath -w "$1"; else printf '%s' "$1"; fi; }

browser=${BROWSER_BIN:-}
if [ -z "$browser" ]; then
  for b in "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" \
           "/c/Program Files/Google/Chrome/Application/chrome.exe" \
           "$(command -v chromium 2>/dev/null)" "$(command -v chromium-browser 2>/dev/null)" \
           "$(command -v google-chrome 2>/dev/null)"; do
    [ -n "$b" ] && [ -x "$b" ] && { browser=$b; break; }
  done
fi
[ -n "$browser" ] || { echo "no Chromium-based browser found (set BROWSER_BIN)" >&2; exit 2; }

mkdir -p "$(dirname "$out")"
profile=$(mktemp -d "${TMPDIR:-/tmp}/capture-profile.XXXXXX")
server_pid=

cleanup() {
  # ブラウザの取り残し（固まった子プロセス）を、専用プロファイルのパスで特定して止める
  if [ -n "$win" ]; then
    powershell.exe -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { \$_.ProcessId -ne \$PID -and \$_.CommandLine -like '*$(basename "$profile")*' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force -ErrorAction SilentlyContinue }" >/dev/null 2>&1
  else
    pkill -f "$profile" 2>/dev/null
  fi
  if [ -n "$server_pid" ]; then
    if [ -n "$win" ]; then
      taskkill //T //F //PID "$(cat "/proc/$server_pid/winpid" 2>/dev/null || echo "$server_pid")" >/dev/null 2>&1
    else
      kill -TERM -- "-$server_pid" 2>/dev/null
    fi
  fi
  rm -rf "$profile"
}
trap cleanup EXIT

if [ -n "$serve" ]; then
  if [ -n "$win" ]; then
    (cd "$serve_cwd" && exec bash -c "$serve") > "$out.serve.log" 2>&1 &
  else
    (cd "$serve_cwd" && exec setsid bash -c "$serve") > "$out.serve.log" 2>&1 &
  fi
  server_pid=$!
  ready=
  for _ in $(seq 1 "$limit"); do
    [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 "$url")" = 200 ] && { ready=1; break; }
    kill -0 "$server_pid" 2>/dev/null || break
    sleep 1
  done
  [ -n "$ready" ] || { echo "server not ready: $url" >&2; tail -n 20 "$out.serve.log" >&2; exit 1; }
fi

rm -f "$out"
timeout "$limit" "$browser" --headless=new --disable-gpu ${nosbx:+--no-sandbox} \
  --user-data-dir="$(native "$profile")" --window-size="$size" --virtual-time-budget="$wait_ms" \
  --screenshot="$(native "$out")" "$url" > /dev/null 2>&1
if [ -s "$out" ]; then
  echo "ok out=$out bytes=$(wc -c < "$out" | tr -d ' ') url=$url"
else
  echo "capture failed: $url (browser=$browser)" >&2
  exit 1
fi
