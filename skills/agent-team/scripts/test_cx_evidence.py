"""cx_evidence.is_compound の確認。実行: python test_cx_evidence.py（pytest でも可）"""
from cx_evidence import is_compound

CASES = [
    ("$env:ANTHROPIC_API_KEY=''; npx vitest run", False),
    ("$env:A = ''; npm run build -- --webpack", False),
    ('$env:A = "x"; $env:B=1; npm test', False),
    ("$env:A='a;b'; npx tsc --noEmit", False),
    ("npm run lint; npx tsc --noEmit", True),
    ("npx vitest run | tail", True),
    ("npm run lint; $lint=$LASTEXITCODE", True),
    ("$env:A=''; npx vitest run; exit $LASTEXITCODE", True),  # 終了コードは保たれるが安全側で複合
]


def test_is_compound():
    for cmd, expected in CASES:
        assert is_compound(cmd) == expected, cmd


if __name__ == "__main__":
    test_is_compound()
    print(f"ok ({len(CASES)} cases)")
