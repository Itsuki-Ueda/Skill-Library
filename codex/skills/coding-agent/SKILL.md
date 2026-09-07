---
name: coding-agent
description: "カスタムAgent `coding` に、承認済み仕様の実装を委譲するためのランチャーSkill。行動規律の正本は `~/.agents/skills/team-worker/SKILL.md`。"
---

# Coding Agent Launcher

行動規律の正本: `~/.agents/skills/team-worker/SKILL.md`（team-worker スキル）。
カスタムAgent `coding`（`~/.codex/agents/coding.toml`）もこの正本に従う。

## 起動手順

このSkillは親オーケストレーターで使用する。
現在のセッションがすでにカスタムAgent `coding` として起動されている場合は、別Agentを起動せず、
**team-worker スキルの行動規律に従って**実装する。

それ以外の場合は次を行う。

1. 現在のセッションで実装しない。
2. カスタムAgent `coding` を名前指定して新しい子セッションとして起動する。
3. 組み込み `worker`、`default`、表示用nicknameへ黙って置換しない。
4. 子へ必要最小限（目的・完了条件・仕様/計画・対象ファイル・やらないこと・検証ゲート・commit可否）だけを渡す。
5. 原則として親の会話履歴を継承させない。
6. 子Agentの完了を待ち、変更ファイル、検証、逸脱、エスカレーションを親で集約する。
7. 子Agentから別の子Agentを起動させない。
8. 名前付きAgentを起動できない場合は、勝手に自己実装せず、利用不可を報告する。ただしユーザーがフォールバックを明示許可した場合を除く。
