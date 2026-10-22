"""agent-team: 計画レビューの前に、ミッションの型の選び方の抜けを止める（references/types/README.md）。

使い方: python3 check_types.py <ミッションファイル>
  止める条件（どちらかで終了コード1）:
  - Acceptance に時間の数字（10秒・500ms 等）があるのに、`型:` に perf が無い
  - `型:` に型があるのに、「型の対応表」に、その型の行が無い
"""
import re, sys

from mission_cost import section

TIME = re.compile(r"\d+(?:\.\d+)?\s*(?:秒|ミリ秒|分|時間|(?:ms|sec|s)(?![A-Za-z]))")
TYPES = ("bug-fix", "feature", "refactor", "perf", "comparison", "ui")


def check(s):
    m = re.search(r"^型[:：](.*)$", s, re.M)
    line = m.group(1) if m else ""
    chosen = [t for t in TYPES if re.search(rf"\b{t}\b", line)]
    errors = []
    if TIME.search(section(s, "Acceptance")) and "perf" not in chosen:
        errors.append("Acceptance に時間の数字があるのに、型に perf.md がありません（types/README.md の表で選び直す）")
    rows = [l for l in section(s, "型の対応表").splitlines() if l.startswith("|")]
    for t in chosen:
        if not any(re.match(rf"\|\s*{t}\b", r) for r in rows):
            errors.append(f"型の対応表に {t} の行がありません（{t}.md の見出しの段の項目ごとに1行書く）")
    return errors


if __name__ == "__main__":
    errs = check(open(sys.argv[1], encoding="utf-8").read())
    for e in errs:
        print("止める: " + e)
    sys.exit(1 if errs else 0)
