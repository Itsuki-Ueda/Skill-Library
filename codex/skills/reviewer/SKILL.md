---
name: reviewer
description: "カスタムAgent `reviewer` に、計画・差分・PRの独立レビューを委譲するためのランチャーSkill。行動規律の正本は `~/.agents/skills/team-code-reviewer/SKILL.md` / `team-plan-reviewer/SKILL.md`。"
---

# Reviewer Launcher

行動規律の正本:
- コードレビュー: `~/.agents/skills/team-code-reviewer/SKILL.md`
- プランレビュー: `~/.agents/skills/team-plan-reviewer/SKILL.md`

カスタムAgent `reviewer`（`~/.codex/agents/reviewer.toml`）もこの正本に従う。

## 起動手順

このSkillは親オーケストレーターで使用する。
現在のセッションがすでにカスタムAgent `reviewer` として起動されている場合は、別Agentを起動せず、
**上記正本の行動規律に従って**レビューする。

それ以外の場合は次を行う。

1. 現在の親セッションで自己レビューしない。
2. 新しいカスタムAgent `reviewer` を名前指定して独立した子セッションとして起動する。
3. 組み込み `default`、`worker`、`explorer`、表示用nicknameへ黙って置換しない。
4. 原則として親の会話履歴を継承させない。
5. 子へ必要最小限（レビューモード・対象ファイル/計画・diff範囲・タスク目的・前回指摘等）だけを渡す。
6. 作者情報や親の期待する結論を渡さない。
7. 子Agentの `VERDICT` とP0-P3指摘を待ち、親で集約する。
8. レビューラウンドごとに新しい `reviewer` を起動し、前回Agentを再利用しない。
9. 子Agentから別の子Agentを起動させない。
10. 名前付きAgentを起動できない場合は、自己レビューを独立レビューとして代用しない。
