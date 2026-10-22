"""check_types.check の確認。実行: python3 test_check_types.py（pytest でも可）"""
from check_types import check

BASE = """# M-001: test

型: {types}

## Goal

x

## Acceptance

- {acc}

## 型の対応表

| 型の段 | この計画では |
| --- | --- |
{rows}
## Human Escalation
"""


def m(types="feature.md", acc="一覧に表示される", rows="| feature [6] 本物で確かめる | Acceptance 1 |\n"):
    return check(BASE.format(types=types, acc=acc, rows=rows))


def test_ok():
    assert m() == []


def test_time_target_without_perf_stops():
    assert len(m(acc="1ページの中央値が10秒以下")) == 1
    assert len(m(acc="応答が 500ms 以内")) == 1
    for acc in ("応答が500ms以内", "10sで終わる", "5分で終わる", "1時間以内"):
        assert len(m(acc=acc)) == 1, acc
    assert m(acc="5 sessions を一覧に出す") == []


def test_time_target_with_perf_and_rows_passes():
    rows = "| feature [6] 本物 | A1 |\n| perf [6] 7問 | A2 |\n"
    assert m(types="feature.md, perf.md", acc="中央値10秒以下", rows=rows) == []


def test_missing_row_for_chosen_type_stops():
    assert len(m(types="feature.md, perf.md", acc="中央値10秒以下")) == 1


def test_no_type_needs_no_table():
    assert m(types="なし（調査・設計のみ）", rows="") == []


def test_time_outside_acceptance_is_ignored():
    s = BASE.format(types="feature.md", acc="表示される", rows="| feature [6] x | A1 |\n") + "\n## Log\n- 10秒かかった\n"
    assert check(s) == []


if __name__ == "__main__":
    for name, f in list(globals().items()):
        if name.startswith("test_"):
            f()
    print("ok")
