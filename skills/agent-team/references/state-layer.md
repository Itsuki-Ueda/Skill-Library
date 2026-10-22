# state-layer.md — 状態レイヤーの運用規約

セッションが死んでも、次のセッションがファイルだけから現在地を再構築できる状態を保つ。
上限・記憶の書式・書き先判定・整理手順は `memory-ops` スキルが正本。ここには構造とライフサイクルだけを置く。

## 層構造

| 層 | 場所 | 規約 |
| --- | --- | --- |
| 作業記憶 | `.agents/state/STATE.md` | activeミッションの1行サマリ+blocker+受入負債+直近Log |
| 中期記憶 | `.agents/state/missions/M-xxx.md`（完了で `closed/` へ） | ミッションの経緯・判断の詳細 |
| 解説ページの記録 | `.agents/state/explain/E-xxx.md` | 人間向けに作った解説ページ（Artifact）の索引と、設計判断の結論・理由。書き方は explain-page スキルが正本 |
| 候補箱 | `.agents/state/INBOX.md` | 教訓・罠の初出はここ。回数で正式記憶へ昇格 |
| 長期記憶（Orchestrator向け） | `.agents/state/MEMORY.md` | ミッションを回す知見だけ（人間の決定・好みは AGENTS.md へ） |
| 長期記憶（全員向け） | リポジトリ `AGENTS.md` | コードを壊さないための規約と人間の決定・好み。全セッションが読む |
| 履歴 | git履歴 + `missions/closed/` + `.agents/queue/` | 無制限。想起はresearcherに掘らせる |

- 起動時に読む状態は SKILL.md「読み込みと設定」の3つだけ。`closed/`・`queue/`・INBOX.md は読まない。
- 起動時に読むファイルはすべて上限を持つ（起動コストを一定に保つため。計測は下記）。
- 過去の判断は、まず SKILL.md [1] の `list.sh` で結論を見る。足りなければresearch担当に `missions/closed/`・`explain/`・`git log` をgrepさせて要点だけ回収する。

## 書き込み権

- STATE.md・INBOX.md・MEMORY.md・BACKLOG.md に書けるのはOrchestratorだけ。worker・サブエージェントの成果物は親が `queue/`（reports/reviews/research）へ保存する。
- 例外は明示委任したexecutorによるミッション・queueへの記帳だけ（SKILL.md [3.5]）。契約のDo not modifyに状態ファイルを入れる。

## STATE.md の構造

```
# STATE
## Missions（インデックス）
| ID | Title | Status | Branch | 詳細 |
## Blockers
## 受入負債（人間の受入が未実施・一括合格で個別未確認の項目。1項目1行の表）
## Log（直近の完了記録・時系列1行ずつ。件数は memory-ops の distill に従う）
```

- この4節以外の節を作らない。罠・教訓は memory-ops の「記録の入口」（INBOX.md）へ。
- 完了ミッションの補足段落をMissions表の下に積まない。警告が要るなら受入負債表へ1行。
- Logは1エントリ1行。収まらない詳細はミッションファイルか INBOX に書く。

## ミッションのライフサイクル

1. [1]Intakeで `missions/M-xxx.md` 作成（MISSION_TEMPLATE準拠）、STATE.mdに1行追加、
   `Active session` に自セッションを記載。
2. 工程の進行・判断・dispatch記録はすべてミッションファイルに書く（STATE.mdには書かない）。
3. [7]完了時の**縮約（強制ステップ）**:
   - Missions行を完了記録1行（ID・成果・commit範囲）にしてLogへ移す。
   - 教訓・罠は memory-ops の「記録の入口」へ（MEMORY.md に直接追記して終わりにしない）。
   - `Active session` をクリアし、SKILL.md [7] の `close-mission.sh` で閉じる。
   - `check-size.sh` で計測・整理し、`.agents/` をコミットする。**ここまで済むまで完了報告を締めない。**
4. 中断時（セッション終了・人間の停止指示）: 現在地・次アクション・未回収のcodex session idを
   ミッションファイルに書き残してから閉じる。`Active session` はクリアする。

## 計測のタイミング（agent-team 側の義務）

`check-size.sh` を resume・[0] 前提確認・[7] 縮約後に実行し、超過があれば memory-ops を実施する（提案でなく実施。閾値+10%未満なら同セッションの [7] まで先送り可）。`/agent-team status` は計測・報告のみで、書込・commitをしない。

ミッションファイルが長大化したら、古いTimeline/Logを末尾の「Archive」節へ移し、冒頭のTasks表とNext actionsで現在地が分かるようにする。
