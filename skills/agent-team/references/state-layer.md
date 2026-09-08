# state-layer.md — 状態レイヤーの運用規約

「消すのではなく沈める」記憶モデル。セッションが死んでも次のセッションが
ファイルだけから現在地を再構築できる状態を常に保つ（セッション単位Leadの生命線）。
**肥大化対策・記憶の書式・書き先判定・蒸留/最新化/昇格の手順は `memory-ops` スキルが正本**
（`~/.agents/skills/memory-ops/SKILL.md`）。ここには構造とライフサイクルだけを置く。

## 層構造

| 層 | 場所 | 規約 |
| --- | --- | --- |
| 作業記憶 | `.agents/state/STATE.md` | activeミッションの1行サマリ+blocker+受入負債+直近Log。**上限100行** |
| 中期記憶 | `.agents/state/missions/M-xxx.md`（完了で `closed/` へ） | ミッションの経緯・判断の詳細 |
| 候補箱 | `.agents/state/INBOX.md` | 教訓・罠の初出はここ。3回目で正式記憶へ昇格。**上限60行** |
| 長期記憶（Orchestrator向け） | `.agents/state/MEMORY.md` | ミッションを回す知見だけ（人間の決定・好みは AGENTS.md へ）。**上限150行** |
| 長期記憶（全員向け） | リポジトリ `AGENTS.md` | コードを壊さないための規約と人間の決定・好み。全セッションが読む。**上限200行** |
| 履歴 | git履歴 + `missions/closed/` + `.agents/queue/` | 無制限。想起はresearcherに掘らせる |

- 本流・resumeが起動時に読む状態は STATE.md → 対象ミッション → MEMORY.md **だけ**
  （プロジェクトの入口ルールもハーネスの方式で読む）。`closed/`・`queue/`・INBOX.md は通常の起動時に読まない。statusは現状報告に必要なSTATE/BACKLOG/queueを読み取り専用で調べる。
- 起動時に読むファイルは**すべて上限を持つ**。上限があるから起動コストが一定に保たれる。
  上限は `memory-ops/scripts/check-size.sh` で測る（SessionStart hook でも毎回表示される）。
- 過去の判断が必要になったら、コンテキストに載せず ラッパーで解決したresearch担当に `missions/closed/` と `git log` をgrepさせて要点だけ回収する。

## 書き込み権

- STATE.md・INBOX.md・MEMORY.md・BACKLOG.md に書けるのは**Orchestratorだけ**。ミッション記帳の委任は次項のexecutor例外に限る。
- worker・サブエージェントの成果物は親が `queue/`（reports/reviews/research）へ保存する。明示委任したexecutorだけはミッション・queueへの記帳可。STATE縮約は親だけ。
  契約のDo not modifyにも状態ファイルを必ず入れる。

## STATE.md の構造

```
# STATE
## Missions（インデックス）
| ID | Title | Status | Branch | 詳細 |
## Blockers
## 受入負債（人間の受入が未実施・一括合格で個別未確認の項目。1項目1行の表）
## Log（直近の完了記録・時系列1行ずつ・最大20件。古いものから削る）
```

- **この4節以外の節を作らない**。「触るときの原則」「次に触る人へ」のような
  設計不変条件・罠の集積はSTATEに書かない（第2のMEMORYができ、起動コストが際限なく増える。
  実例: 規約外の節と18行のLogエントリで 513 行に達したプロジェクトがある）。
  罠・教訓は memory-ops の「記録の入口」（INBOX.md）へ。
- 完了ミッションの補足段落をMissions表の下に積まない。警告が要るなら受入負債表へ1行。
- **Logは1エントリ1行厳守**。1行に収まらない内容は、ミッションファイルか INBOX に書いてから
  STATEには書かない（詳細をLogに書くのは縮約の不履行であり、二重記録でもある）。

## ミッションのライフサイクル

1. [1]Intakeで `missions/M-xxx.md` 作成（MISSION_TEMPLATE準拠）、STATE.mdに1行追加、
   `Active session` に自セッションを記載。
2. 工程の進行・判断・dispatch記録はすべてミッションファイルに書く（STATE.mdには書かない）。
3. [7]完了時の**縮約（強制ステップ）**:
   - STATE.mdのMissions行を完了記録1行（ID・成果・commit範囲）に縮めてLogへ移す。
   - 得られた教訓・罠は memory-ops の「記録の入口」に従って INBOX.md へ（初出）、
     または回数3到達で昇格、人間指示なら直行。**MEMORY.md に追記して終わりにしない。**
   - ミッションファイルの `Active session` をクリアし `missions/closed/` へ移動。
   - `check-size.sh` を実行し、閾値超過があれば memory-ops の該当サブコマンドを実施する。
   - `.agents/` の変更をコミット。
   - **縮約と計測が済むまで人間への完了報告を締めない。**
4. 中断時（セッション終了・人間の停止指示）: 現在地・次アクション・未回収のcodex session idを
   ミッションファイルに書き残してから閉じる。`Active session` はクリアする。

## 計測のタイミング（agent-team 側の義務）

`check-size.sh` を次の全てで実行し、超過があればmemory-opsを実施する（本流・resumeは着手前、[7]は終了時。statusは例外）
（提案ではなく実施。超過が軽微〔閾値+10%未満〕なら同セッションの [7] まで先送りしてよい）:

- `/agent-team status` は計測・報告のみ（本節の整理義務の例外）。書込・commitをしない。
- `/agent-team resume`
- ミッションフロー [0] 前提確認
- ミッションフロー [7] 縮約後

ミッションファイル自体が長大化した場合（長期ミッション）: Timeline/Logの古い節を
同ファイル末尾の「Archive」節へ移し、冒頭のTasks表とNext actionsだけで現在地が
分かる状態を保つ。
