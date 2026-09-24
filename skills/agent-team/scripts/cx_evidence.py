#!/usr/bin/env python3
"""agent-team: Codex のセッション記録（~/.codex/sessions の rollout）から実行証拠を抜き出す。

親が worker の検証を再実行せずに確認するための道具（codex-protocol §10 の「元記録」）。
worker の自己申告ではなく、Codex 自身が記録したコマンド・作業場所・終了コード・出力を表示する。

  python cx_evidence.py <session id | rollout.jsonl> [--worktree <path>] [--match REGEX] [--tail N]

表示: 作業場所 / 元コミット / モデル・effort・sandbox / 編集したファイルと最終変更時刻 /
      全コマンドの一覧（終了コード・所要秒・最終変更より後か）/ 検証コマンドと失敗コマンドの出力末尾。
最終変更より前に実行された検証は「変更前」と表示する（その合格は最終版の証拠にならない）。
--worktree を付けると、git status 上の変更ファイルの更新時刻も「変更」に数える。
シェル経由の書き込み（記録に FileChange が残らない）や、worker 完了後の親の編集も検出するため、判定時は必ず付ける。
"""
import argparse
import glob
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone

# 既定の検証判定: 実行コマンドが runner で始まり、かつ検証語を含む（rg の検索語などを誤検出しない）
RUNNER = re.compile(r"^\s*(?:&\s*)?(?:npx|npm|pnpm|yarn|bunx?|pytest|python3?|tsc|eslint|vitest|jest|cargo|go|dotnet|make|bash)\b")
KEYWORD = re.compile(r"\b(?:test|vitest|jest|pytest|tsc|eslint|typecheck|lint|build|check)\b|capture\.sh")


def find_rollout(key):
    if os.path.isfile(key):
        return key
    home = os.environ.get("CODEX_HOME") or os.path.expanduser("~/.codex")
    hits = glob.glob(os.path.join(home, "sessions", "**", f"rollout-*{key}*.jsonl"), recursive=True)
    if not hits:
        sys.exit(f"rollout not found for session: {key}")
    return max(hits, key=os.path.getmtime)


def parse(ts):
    return datetime.fromisoformat(ts.replace("Z", "+00:00"))


def local(ts):
    return parse(ts).astimezone().strftime("%H:%M:%S")


def worktree_changes(path):
    """git status 上の変更・未追跡ファイルと、その更新時刻（ISO UTC）。削除は時刻なしで除外。"""
    out = subprocess.run(["git", "-C", path, "status", "--porcelain", "-uall", "-z"],
                         capture_output=True, text=True, encoding="utf-8", check=True).stdout
    found = []
    entries = out.split("\0")
    i = 0
    while i < len(entries):
        e = entries[i]
        i += 1
        if len(e) < 4:
            continue
        if e[0] in "RC":  # rename/copy は次の要素が元パス
            i += 1
        full = os.path.join(path, e[3:])
        if os.path.isfile(full):
            ts = datetime.fromtimestamp(os.path.getmtime(full), timezone.utc).isoformat().replace("+00:00", "Z")
            found.append((ts, e[3:]))
    return found


def shell_text(command):
    # ["pwsh.exe", "-Command", "<cmd>"] のような配列 → 実際のコマンド文字列
    if isinstance(command, list):
        return command[-1] if command else ""
    return str(command)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("session")
    ap.add_argument("--worktree", help="変更ファイルの更新時刻も最終変更に数える作業場所")
    ap.add_argument("--match", help="検証コマンドとみなす正規表現（省略時は runner＋検証語で判定）")
    ap.add_argument("--tail", type=int, default=15)
    a = ap.parse_args()
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    meta, ctx, cmds, edits = {}, {}, [], []
    with open(find_rollout(a.session), encoding="utf-8", errors="replace") as f:
        for line in f:
            o = json.loads(line)
            t, p = o.get("type"), o.get("payload") or {}
            if t == "session_meta":
                meta = p
            elif t == "turn_context" and not ctx:
                ctx = p
            elif t == "event_msg" and p.get("type") == "item_completed":
                it = p.get("item") or {}
                if it.get("type") == "CommandExecution":
                    cmds.append((o["timestamp"], it))
                elif it.get("type") == "FileChange":
                    edits.append((o["timestamp"], sorted((it.get("changes") or {}).keys())))

    changes = [(ts, p) for ts, ps in edits for p in ps]
    if a.worktree:
        changes += worktree_changes(a.worktree)
    last_edit = max((parse(ts) for ts, _ in changes), default=None)
    sandbox = (ctx.get("sandbox_policy") or {}).get("type") if isinstance(ctx.get("sandbox_policy"), dict) else ctx.get("sandbox_policy")
    print(f"session: {meta.get('id', a.session)}  cli: {meta.get('cli_version', '?')}")
    print(f"cwd: {meta.get('cwd', '?')}  base commit: {(meta.get('git') or {}).get('commit_hash', '?')}")
    print(f"model: {ctx.get('model', '?')}  effort: {ctx.get('effort', '?')}  sandbox: {sandbox or '?'}")
    files = sorted({p for _, p in changes})
    print(f"changed files ({len(files)}): " + (", ".join(files) if files else "なし"))
    last = last_edit.astimezone().strftime("%H:%M:%S") if last_edit else "なし"
    print(f"last change: {last}" + ("" if a.worktree else "  ※--worktree なし: シェル経由の書き込みは未検出"))
    print()
    print("| # | 時刻 | exit | 秒 | 最終変更 | コマンド |")
    print("|---|---|---|---|---|---|")
    custom = re.compile(a.match) if a.match else None

    def is_verify_cmd(text):
        return bool(custom.search(text)) if custom else bool(RUNNER.search(text) and KEYWORD.search(text))

    verify_after, verify_fail = 0, 0
    for i, (ts, it) in enumerate(cmds, 1):
        text = shell_text(it.get("command"))
        dur = it.get("duration") or {}
        secs = dur.get("secs", 0) + dur.get("nanos", 0) / 1e9
        after = "後" if (last_edit is None or parse(ts) > last_edit) else "変更前"
        is_verify = is_verify_cmd(text)
        if is_verify and after == "後":
            verify_after += 1
            verify_fail += it.get("exit_code") != 0
        one = text.replace("\n", " ").replace("|", "\\|")
        print(f"| {i} | {local(ts)} | {it.get('exit_code')} | {secs:.1f} | {after} | `{one[:140]}` |")
    print()
    print(f"最終変更より後の検証コマンド: {verify_after}件（exit≠0: {verify_fail}件）")
    for i, (ts, it) in enumerate(cmds, 1):
        text = shell_text(it.get("command"))
        if not (is_verify_cmd(text) or it.get("exit_code") != 0):
            continue
        out = (it.get("aggregated_output") or "").replace("\r\n", "\n").rstrip("\n").split("\n")
        print(f"\n--- #{i} exit={it.get('exit_code')} 出力末尾{a.tail}行 ---")
        print("\n".join(out[-a.tail:]))


if __name__ == "__main__":
    main()
