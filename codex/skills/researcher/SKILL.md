---
name: researcher
description: "カスタムAgent `researcher` に、読み取り専用のコードベース調査を委譲するためのランチャーSkill。行動規律の正本は `~/.agents/skills/team-researcher/SKILL.md`。"
---

# Researcher Launcher

行動規律の正本: `~/.agents/skills/team-researcher/SKILL.md`（team-researcher スキル）。
カスタムAgent `researcher`（`~/.codex/agents/researcher.toml`）もこの正本に従う。

## 起動手順

このSkillは親オーケストレーターで使用する。
現在のセッションがすでにカスタムAgent `researcher` として起動されている場合は、別Agentを起動せず、
**team-researcher スキルの行動規律に従って**調査する。

それ以外の場合は次を行う。

1. カスタムAgent `researcher` を名前指定して新しい読み取り専用の子セッションとして起動する。
2. 組み込み `explorer`、`default`、表示用nicknameへ黙って置換しない。
3. 原則として親の会話履歴を継承させない。
4. 子へ必要最小限（調査質問・対象/除外範囲・確認したい経路・根拠形式・外部資料可否）だけを渡す。
5. ファイル編集、Git状態変更、修正実装を禁止する。
6. path:line、確認状態、否定形検索記録付きの結果を待ち、親で次工程へ渡す。
7. 子Agentから別の子Agentを起動させない。
8. 名前付きAgentを起動できない場合は、黙って `explorer` に置換せず、利用不可を報告する。ただしユーザーがフォールバックを明示許可した場合を除く。
