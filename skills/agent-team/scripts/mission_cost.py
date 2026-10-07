"""agent-team: ミッション1件ごとの費用と品質の指標を、記録から集計する（memory 等には書かない。標準出力と台帳へ）。

使い方: python mission_cost.py <リポジトリ> [M-005 M-006 ...] [--ledger <jsonl>]
  ミッション省略時は missions/ と missions/closed/ の全件。台帳の既定は ~/.claude/agent-team-ledger.jsonl（追記）。

割り振り:
  - Codex: ミッションファイルに書かれたセッション ID（UUID）の rollout の最終 total_token_usage。
  - サブエージェント: ファイルに書かれた agent ID、または依頼文にミッション ID・タスク ID・作業場所名を含むもの。
  - 親: 呼び出しごとに、その呼び出しのツール入力・本文に出たミッションの識別子で割り振り、出なければ直前の割り振りを引き継ぐ。
    どのミッションにも当たらない分は「未割当」。
作業時間: そのミッションに割り振った Claude の呼び出し時刻を並べ、間隔10分以内の区間だけを足す（人間の待ち・放置は含まない）。
計画の形: ミッションの並列計画の「波: N」「最長の列: N段」と、executor の代数。
費用の換算: 通常入力1・キャッシュ読み0.1・キャッシュ書き1.25（1時間キャッシュは2.0）・出力5 の仮定（相対比較用。実際の料金表ではない）。
"""
import glob, json, os, re, sys, collections
from datetime import datetime

UUID = r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
TASK = r"T-[A-Z0-9]+(?:-[A-Z0-9]+)*-?\d+[a-z]?"
W = {"input_tokens": 1, "cache_read_input_tokens": 0.1, "cache_creation_input_tokens": 1.25, "output_tokens": 5}


def units(u):
    """キャッシュ書き込みは内訳があれば 5分=1.25・1時間=2.0 で数える（内訳の無い古い記録は 1.25）。"""
    c = u.get("cache_creation") or {}
    if c:
        u = dict(u, cache_creation_input_tokens=c.get("ephemeral_5m_input_tokens", 0) + c.get("ephemeral_1h_input_tokens", 0) * 2.0 / 1.25)
    return sum(u.get(k, 0) * w for k, w in W.items())


def parse_mission(path):
    s = open(path, encoding="utf-8").read(); mid = os.path.basename(path)[:-3]
    rows = [l for l in s.splitlines() if re.match(r"\|\s*T-", l)]
    rev = " ".join(r.split("|")[5] if r.count("|") > 6 else r for r in rows)
    times = sorted(re.findall(r"^- (\d{4}-\d{2}-\d{2}) (\d{2})", s, re.M))
    num = lambda pat: max(map(int, re.findall(pat, s)), default=None)
    return {
        "id": mid, "path": path,
        "keys": {mid} | set(re.findall(TASK, s)) | set(re.findall(r"\.claude/worktrees/([\w.-]+)", s)),
        # Codex は UUID 全体か、「Codex 01a10fa6」のような先頭8桁で書かれる（rollout のファイル名との部分一致で引く）
        "codex": set(re.findall(UUID, s)) | set(re.findall(r"Codex[^0-9a-f\n]{0,3}([0-9a-f]{8})\b", s)), "agents": set(re.findall(r"agent (a[0-9a-f]{16})", s)),
        "quality": {
            "tasks": len(rows),
            "review_rounds": sum(max(map(int, re.findall(r"\br(\d+)", r)), default=0) for r in rows),
            "review_fails": rev.count("fail"),
            "P1": sum(int(n or 1) for n in re.findall(r"P1(?:×(\d+))?", rev)),
            "P2": sum(int(n or 1) for n in re.findall(r"P2(?:×(\d+))?", rev)),
            "plan_review_rounds": len(set(re.findall(r"計画レビュー r(\d+)", s))),
            "integration_review_rounds": len(set(re.findall(r"統合レビュー[^\n]*?r(\d+)", s))),
            "human_decisions": len(re.findall(r"^- \d{4}-\d{2}-\d{2}[^\n]*人間", s, re.M)),
        },
        # 計画の形: 並列計画の「波: N」「最長の列: N段」と、executor の代数（「N 代目」「第 N 代」の最大）
        "plan": {"waves": num(r"波[:：]\s*(\d+)"), "critical_path": num(r"最長の列[:：]\s*(\d+)"),
                 "executor_gens": num(r"(?:第\s*|\b)(\d+)\s*代(?:目)?")},
        "start": f"{times[0][0]} {times[0][1]}" if times else "", "end": f"{times[-1][0]} {times[-1][1]}" if times else "",
    }


def codex_usage(ids):
    tot = collections.Counter(); found = 0
    files = glob.glob(os.path.expanduser("~/.codex/sessions/**/rollout-*.jsonl"), recursive=True)
    for f in files:
        sid = next((i for i in ids if i in os.path.basename(f)), None)
        if not sid: continue
        last = None
        for l in open(f, encoding="utf-8", errors="ignore"):
            if '"token_count"' not in l: continue
            info = (json.loads(l).get("payload") or {}).get("info") or {}
            last = info.get("total_token_usage") or last
        if last: found += 1; tot.update({k: v for k, v in last.items() if isinstance(v, int)})
    return tot, found


def claude_calls(path, sidechain=False):
    """(timestamp, usage, そのメッセージの文字列) を API 呼び出し単位で返す。"""
    out = {}; order = []
    for l in open(path, encoding="utf-8"):
        try: o = json.loads(l)
        except Exception: continue
        if o.get("type") != "assistant" or bool(o.get("isSidechain")) != sidechain: continue
        m = o.get("message") or {}; mid = m.get("id"); u = m.get("usage")
        if not mid or not u: continue
        if mid not in out: out[mid] = [o.get("timestamp", ""), u, ""]; order.append(mid)
        out[mid][2] += json.dumps(m.get("content"), ensure_ascii=False)
    return [out[k] for k in order]


def session_cwd(path):
    for l in open(path, encoding="utf-8"):
        c = json.loads(l).get("cwd")
        if c: return c
    return None


def first_prompt(path):
    for l in open(path, encoding="utf-8"):
        o = json.loads(l)
        if o.get("type") == "user":
            c = (o.get("message") or {}).get("content")
            return c if isinstance(c, str) else json.dumps(c, ensure_ascii=False)
    return ""


def active_hours(stamps, gap=600):
    """Claude の呼び出し時刻を並べ、間隔が gap 秒以内の区間だけを足した作業時間（人間の待ち・放置を除く）。"""
    t = sorted(datetime.fromisoformat(x.replace("Z", "+00:00")).timestamp() for x in stamps if x)
    return round(sum(b - a for a, b in zip(t, t[1:]) if b - a <= gap) / 3600, 2)


def rewrite_units(prev, ts, u, gap=300, min_tokens=10000):
    """待った直後の書き直し: 同じ会話の直前の呼び出しから gap 秒以上空き、min_tokens 以上を書き込んだ呼び出しの書き込み費用。
    キャッシュが切れて文脈全体を書き直した分の目安（1時間キャッシュが効いていれば書き込みが小さく、数えられない）。"""
    if not prev or not ts or u.get("cache_creation_input_tokens", 0) < min_tokens: return 0
    t = lambda x: datetime.fromisoformat(x.replace("Z", "+00:00")).timestamp()
    if t(ts) - t(prev) < gap: return 0
    return units({k: u[k] for k in ("cache_creation_input_tokens", "cache_creation") if k in u})


def main():
    args = sys.argv[1:]; ledger = os.path.expanduser("~/.claude/agent-team-ledger.jsonl")
    if "--ledger" in args: i = args.index("--ledger"); ledger = args[i + 1]; del args[i:i + 2]
    repo = os.path.abspath(args[0]); want = set(args[1:])
    mdir = os.path.join(repo, ".agents", "state", "missions")
    ms = [parse_mission(p) for p in glob.glob(mdir + "/M-*.md") + glob.glob(mdir + "/closed/M-*.md")]
    enc = re.sub(r"[^A-Za-z0-9]", "-", repo)
    # フォルダ名は日本語が全部 "-" になり別リポジトリと衝突するので、記録の cwd が対象リポジトリ配下のものだけ使う
    norm = lambda x: os.path.normcase(os.path.abspath(x))
    sessions = [f for d in glob.glob(os.path.expanduser("~/.claude/projects/") + enc + "*") for f in glob.glob(d + "/*.jsonl")
                if (lambda c: c and (norm(c) + os.sep).startswith(norm(repo) + os.sep))(session_cwd(f))]
    res = {m["id"]: {"parent": collections.Counter(), "sub": collections.Counter(), "sub_n": collections.Counter(), "ts": [], "rewrite": collections.Counter()} for m in ms}
    unassigned = collections.Counter()
    for f in sessions:
        cur = None; prev = None
        for ts, u, text in claude_calls(f):
            hit = [m["id"] for m in ms if any(k in text for k in m["keys"])]
            if len(hit) == 1: cur = hit[0]
            nums = {k: v for k, v in u.items() if isinstance(v, (int, float))}
            (res[cur]["parent"] if cur else unassigned).update(nums | {"units": units(u), "calls": 1})
            if cur: res[cur]["ts"].append(ts); res[cur]["rewrite"].update({"parent": rewrite_units(prev, ts, u)})
            prev = ts
        for sf in glob.glob(f[:-6] + "/subagents/agent-*.jsonl"):
            aid = os.path.basename(sf)[6:-6]; prompt = first_prompt(sf)
            owner = next((m["id"] for m in ms if aid in m["agents"]), None) or \
                next((m["id"] for m in ms if any(k in prompt for k in m["keys"])), None)
            if not owner: continue
            meta = sf[:-6] + ".meta.json"
            t = json.load(open(meta, encoding="utf-8")).get("agentType", "?") if os.path.exists(meta) else "?"
            prev = None
            for ts, u, _x in claude_calls(sf, sidechain=True):
                res[owner]["sub"].update({t: units(u)}); res[owner]["sub_n"].update({t: 1}); res[owner]["ts"].append(ts)
                res[owner]["rewrite"].update({t: rewrite_units(prev, ts, u)}); prev = ts
    with open(ledger, "a", encoding="utf-8") as lg:
        for m in sorted(ms, key=lambda x: x["id"]):
            if want and m["id"] not in want: continue
            r = res[m["id"]]; cx, n = codex_usage(m["codex"])
            row = {"repo": os.path.basename(repo), "mission": m["id"], "start": m["start"], "end": m["end"],
                   "measured_at": datetime.now().isoformat(timespec="minutes"),
                   "active_hours": active_hours(r["ts"]),
                   "plan": m["plan"],
                   "claude_units": round(r["parent"]["units"] + sum(r["sub"].values())),
                   "parent": {"units": round(r["parent"]["units"]), "calls": r["parent"]["calls"],
                              "avg_ctx": round((r["parent"]["cache_read_input_tokens"] + r["parent"]["cache_creation_input_tokens"] + r["parent"]["input_tokens"]) / max(r["parent"]["calls"], 1))},
                   "subagents": {t: {"units": round(v), "calls": r["sub_n"][t]} for t, v in r["sub"].items()},
                   # 待った直後の書き直し（5分以上空いた後の大きなキャッシュ書き込み）。読み直しの無駄の物差し
                   "idle_rewrite": {k: round(v) for k, v in r["rewrite"].items() if v},
                   "codex": {"sessions_found": n, "sessions_listed": len(m["codex"]), "input": cx["input_tokens"],
                             "cached": cx["cached_input_tokens"], "output": cx["output_tokens"]},
                   "quality": m["quality"]}
            lg.write(json.dumps(row, ensure_ascii=False) + "\n")
            sub = " ".join(f"{t}={v['units'] / 1e6:.1f}M" for t, v in row["subagents"].items())
            rw = " ".join(f"{k}={v / 1e6:.1f}M" for k, v in row["idle_rewrite"].items()) or "なし"
            print(f"{m['id']} {m['start']}〜{m['end']}（作業 {row['active_hours']}h・{m['plan']}） | Claude {row['claude_units'] / 1e6:6.1f}M（親 {row['parent']['units'] / 1e6:.1f}M・平均ctx {row['parent']['avg_ctx']:,} / {sub}）"
                  f" | 待った直後の書き直し {rw} | Codex 入力 {cx['input_tokens'] / 1e6:.1f}M（{n}/{len(m['codex'])}件） | 品質 {m['quality']}")
    print(f"未割当（親）: {unassigned['units'] / 1e6:.1f}M・{unassigned['calls']}回 / 台帳: {ledger}")


if __name__ == "__main__":
    main()
