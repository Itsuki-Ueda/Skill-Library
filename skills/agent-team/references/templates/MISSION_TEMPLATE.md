# M-XXX: <title>

Status: intake | planning | executing | integrating | done
Branch: {git-opsに従うブランチ名}
型: {types/README.md の表で選んだ型を全部（例: feature.md, perf.md）。無ければ なし}
Active session: <引き継ぎ時に記載・終了時にクリア>

## Goal

<人間と合意した目的>

## Acceptance

- <検証可能な成功条件>

## 型の対応表

{types/README.md「型の対応表」の書き方で。型が なし なら節ごと消す}

| 型の段 | この計画では |
| --- | --- |
| {feature [6] 本物で確かめる} | {Acceptance 3 で確かめる／やらない理由} |

## Human Escalation

- <人間の判断を仰ぐ条件>

## Human Decisions（承認・判断の履歴）

- <日付> 人間の<承認・判断>: <人間の発言の逐語>（親が承認を当てはめた記録は Log へ）

## Tasks

| Task | 実装者 | Status | Session ID | Review | Commit |
| --- | --- | --- | --- | --- | --- |

Status: contracted → dispatched → fixing(rN) → review_ok → committed

## レビュー・完了証拠

- レビュー記録: {queue/reviewsのパス}
- 統合確認: {接続・共有資源・順序依存の確認記録。不要なら理由}
- 実行記録: {対象HEAD・コマンド・終了コード・必要な出力}
- 未達/例外受入: {未達内容・Human Decisionsの明示承認。なければなし}

## 並列計画

- ステップ数: {何回に分けて起動するか} / 依存の深さ: {依存のつながりの最も長い段数}（台帳が読む書式。数字だけ置き換える）
- <並列グループと、直列化した箇所の名指しの理由>
- 作業ツリーの共有可否: <検証が他タスクのパスを読み込むか。読み込むならレーン分割、分けないなら停止待ちの明記>

| Lane | 担当タスク | Branch | Worktree | Executor session | 合流順 |
| --- | --- | --- | --- | --- | --- |

## Blockers

- なし

## Next actions

- <次のセッションが最初にやること>

## Log（判断と経緯の時系列記録）

- <`scripts/log.sh <M-ID> "<出来事・判断・根拠>"` で足す（時刻を手で書かない）>
