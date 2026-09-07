#!/usr/bin/env python3
"""Codex が hook 信頼判定に使うハッシュを、hooks JSON の定義内容から計算する（検知専用）。

用途: repo の codex/hooks-state.toml に保存した trusted_hash が、いま導入されている Plugin の
hook 定義と一致するか（Codex 上で「Modified」になっていないか）を機械的に確かめる。
信頼状態の書き込みは行わない。信頼は人間が `codex` → `/hooks` で行う。

計算方法（openai/codex codex-rs/hooks/src/engine/discovery.rs hook_hash と
config/src/fingerprint.rs version_for_toml の再現。ローカル実値 4 件で一致確認 2026-09-05）:
  identity = {event_name, matcher?, hooks:[normalized handler]} をキー昇順の JSON に直列化し sha256。
  normalized handler = {type:"command", command, timeout(既定 600 / SessionEnd・Interrupt は 1〜3), async(既定 false),
                        statusMessage?, additionalContextLimit?(既定 2500 は省略)}
  Windows では commandWindows があればそれを command として使う。

使い方:
  python3 hook-hash.py <hooks.json>            -> "<event_label> <sha256:...>" を 1 行ずつ
  python3 hook-hash.py <hooks.json> --plugin ponytail@ponytail --rel hooks/claude-codex-hooks.json
                                                -> hooks-state.toml と同じ TOML 形式で出力（目視比較用）
"""
import hashlib
import json
import re
import sys

DEFAULT_CONTEXT_LIMIT = 2500
CONTEXT_EVENTS = {"PreToolUse", "PostToolUse", "SessionStart", "UserPromptSubmit", "SubagentStart"}


def label(event: str) -> str:
    return re.sub(r"(?<!^)(?=[A-Z])", "_", event).lower()


def canon(v):
    if isinstance(v, dict):
        return {k: canon(v[k]) for k in sorted(v)}
    if isinstance(v, list):
        return [canon(x) for x in v]
    return v


def normalize(event: str, h: dict) -> dict:
    cmd = h.get("command", "")
    if sys.platform == "win32" and h.get("commandWindows"):
        cmd = h["commandWindows"]
    timeout = h.get("timeout")
    if event in ("SessionEnd", "Interrupt"):
        timeout = min(max(timeout if timeout is not None else 1, 1), 3)
    else:
        timeout = max(timeout if timeout is not None else 600, 1)
    out = {"type": "command", "command": cmd, "timeout": timeout, "async": bool(h.get("async", False))}
    if h.get("statusMessage") is not None:
        out["statusMessage"] = h["statusMessage"]
    lim = h.get("additionalContextLimit")
    if event in CONTEXT_EVENTS and lim is not None and lim != DEFAULT_CONTEXT_LIMIT:
        out["additionalContextLimit"] = lim
    return out


def hashes(hooks_json: dict):
    for event, groups in hooks_json.get("hooks", {}).items():
        for gi, group in enumerate(groups):
            for hi, h in enumerate(group.get("hooks", [])):
                if h.get("type", "command") != "command":
                    continue
                ident = {"event_name": label(event), "hooks": [normalize(event, h)]}
                if group.get("matcher") is not None:
                    ident["matcher"] = group["matcher"]
                s = json.dumps(canon(ident), separators=(",", ":"), ensure_ascii=False).encode("utf-8")
                yield label(event), gi, hi, "sha256:" + hashlib.sha256(s).hexdigest()


def main(argv):
    sys.stdout.reconfigure(newline="\n")  # Windows でも LF 固定（bash の read で CR が混ざらないように）
    if len(argv) < 2:
        print(__doc__)
        return 2
    with open(argv[1], encoding="utf-8") as f:
        data = json.load(f)
    plugin = rel = None
    if "--plugin" in argv:
        plugin = argv[argv.index("--plugin") + 1]
    if "--rel" in argv:
        rel = argv[argv.index("--rel") + 1]
    for ev, gi, hi, h in hashes(data):
        if plugin and rel:
            print(f'[hooks.state."{plugin}:{rel}:{ev}:{gi}:{hi}"]\ntrusted_hash = "{h}"\n')
        else:
            print(ev, h)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
