---
name: plan-probe
description: "カスタムAgent `plan-probe` に、プラン文書の曖昧さ測定（言い換えプローブ）を委譲するためのランチャーSkill。行動規律の正本は `~/.agents/skills/team-plan-probe/SKILL.md`。"
---

# Plan-Probe Launcher

行動規律の正本: `~/.agents/skills/team-plan-probe/SKILL.md`（team-plan-probe スキル）。
カスタムAgent `plan-probe`（`~/.codex/agents/plan-probe.toml`）もこの正本に従う。

## 起動手順

このSkillは親オーケストレーターで使用する。
現在のセッションがすでにカスタムAgent `plan-probe` として起動されている場合は、別Agentを起動せず、
**team-plan-probe スキルの行動規律に従って**回答する。

それ以外の場合は次を行う。

1. カスタムAgent `plan-probe` を名前指定して新しい読み取り専用の子セッションとして起動する。
2. 子へ渡すのは**プラン文書のパスだけ**（背景説明を足すと測定にならない）。
3. 4課題（変更対象／やらないこと／完了条件の判定手順化／迷った箇所）の回答を待ち、
   親が原文と突き合わせて**ズレ＝曖昧箇所**として修正に流す。合否には数えない。
4. 子Agentから別の子Agentを起動させない。
5. 名前付きAgentを起動できない場合は、黙って別Agentに置換せず、利用不可を報告する。
