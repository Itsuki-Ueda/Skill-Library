"""cx_evidence.is_compound と worktree_changes の確認。実行: python test_cx_evidence.py（pytest でも可）"""
import os
import subprocess
import tempfile

from cx_evidence import is_compound, worktree_changes

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


def test_worktree_changes_skips_agents_dir():
    with tempfile.TemporaryDirectory() as d:
        subprocess.run(["git", "init", "-q", d], check=True)
        for rel in ["src/a.py", ".agents/queue/tasks/T-001.md"]:
            os.makedirs(os.path.dirname(os.path.join(d, rel)), exist_ok=True)
            open(os.path.join(d, rel), "w").write("x")
        assert [p for _, p in worktree_changes(d)] == ["src/a.py"]


if __name__ == "__main__":
    test_is_compound()
    test_worktree_changes_skips_agents_dir()
    print(f"ok ({len(CASES)} cases)")
