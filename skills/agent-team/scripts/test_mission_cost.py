"""mission_cost.parse_mission の人間の判断の数え方の確認。実行: python test_mission_cost.py（pytest でも可）"""
import os
import tempfile

from mission_cost import parse_mission

MISSION = """# M-001: test

## Human Decisions（承認・判断の履歴）

- 2026-10-17 人間の事前承認: 「計画レビューに合格したら承認済みとして進めてよい」
- 2026-10-17 15:27 計画レビュー r2 pass。上の事前承認により、分解を承認済みとして進める。
- 2026-10-17 15:40 人間の判断: 「端数は切り捨てのままでよい」

## Log（判断と経緯の時系列記録）

- 2026-10-17 15:20 [1] 人間不在のため、不明点は依頼文から決めた。
- 2026-10-17 15:28 [3] 人間の事前承認により計画を承認済みとした。
"""


def test_human_decisions_counts_only_the_section():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "M-001.md")
        open(p, "w", encoding="utf-8").write(MISSION)
        assert parse_mission(p)["quality"]["human_decisions"] == 2


if __name__ == "__main__":
    test_human_decisions_counts_only_the_section()
    print("ok")
