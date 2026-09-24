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

[ -n "$win" ] && out=$(cygpath -u "$out")
# Codex の sandbox では祖先フォルダ（ユーザーフォルダ直下など）の一覧が拒否され mkdir -p が失敗するので、
# 存在する最も深い祖先へ移動してから、残りだけを相対で作る
dir=$(dirname "$out") rest=
while [ ! -d "$dir" ]; do rest="$(basename "$dir")${rest:+/$rest}"; dir=$(dirname "$dir"); done
[ -z "$rest" ] || (cd "$dir" && mkdir -p "$rest") || { echo "cannot create output directory for $out" >&2; exit 2; }
profile=$(mktemp -d "${TMPDIR:-/tmp}/capture-profile.XXXXXX")
server_pid= port=

# 指定ポートで待ち受けているプロセスの PID。
# Codex の sandbox 内では taskkill /T も WMI での子孫探索も効かないが、netstat と PID 指定の Stop-Process は効く。
# sandbox 内で起動したプロセスは sandbox 外（親）の権限では止められないので、サーバはポートで特定してここで止める。
listeners() {
  if [ -n "$win" ]; then
    netstat -ano | tr -d '\r' | awk -v p=":$port" '$1=="TCP" && $4=="LISTENING" && substr($2, length($2)-length(p)+1)==p {print $5}' | sort -u
  else
    lsof -ti "tcp:$port" -sTCP:LISTEN 2>/dev/null
  fi
}
stop_pids() {
  [ -n "$1" ] || return 0
  if [ -n "$win" ]; then
    powershell.exe -NoProfile -Command "Stop-Process -Id $(echo $1 | tr ' ' ',') -Force -ErrorAction SilentlyContinue" >/dev/null 2>&1
  else
    kill -TERM $1 2>/dev/null
  fi
}

cleanup() {
  # ブラウザの取り残し（固まった子プロセス）を、専用プロファイルのパスで特定して止める（sandbox 外で有効）
  if [ -n "$win" ]; then
    powershell.exe -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { \$_.ProcessId -ne \$PID -and \$_.CommandLine -like '*$(basename "$profile")*' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force -ErrorAction SilentlyContinue }" >/dev/null 2>&1
  else
    pkill -f "$profile" 2>/dev/null
  fi
  if [ -n "$server_pid" ]; then
    [ -n "$win" ] || kill -TERM -- "-$server_pid" 2>/dev/null
    for _ in 1 2 3 4 5; do
      pids=$(listeners); [ -z "$pids" ] && break
      stop_pids "$pids"; sleep 1
    done
    [ -z "$(listeners)" ] || echo "warning: server still listening on port $port (stop it from the same sandbox)" >&2
  fi
  rm -rf "$profile"
}
trap cleanup EXIT

if [ -n "$serve" ]; then
  port=$(printf '%s' "$url" | sed -nE 's#^[a-zA-Z]+://[^/:]+:([0-9]+).*#\1#p')
  [ -n "$port" ] || { echo "--serve requires an explicit port in --url" >&2; exit 2; }
  [ -z "$(listeners)" ] || { echo "port $port is already in use; refusing to start (would stop someone else's server)" >&2; exit 2; }
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
