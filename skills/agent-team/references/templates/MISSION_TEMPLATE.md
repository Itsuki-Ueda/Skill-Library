# M-XXX: <title>

Status: intake | planning | executing | integrating | done
Branch: {git-opsに従うブランチ名}
Active session: <引き継ぎ時に記載・終了時にクリア>

## Goal

<人間と合意した目的>

## Acceptance

- <検証可能な成功条件>

## Human Escalation

- <人間の判断を仰ぐ条件>

## Human Decisions（承認・判断の履歴）

- <日付> <内容>

## Tasks

| Task | 実装者 | Status | Session ID | Review | Commit |
| --- | --- | --- | --- | --- | --- |

Status: contracted → dispatched → fixing(rN) → review_ok → committed

## レビュー・完了証拠

- レビュー記録: {queue/reviewsのパス。対象版・範囲・担当/ベンダー・判定を含む}
- 統合確認: {接続・共有資源・順序依存の確認記録。不要なら理由}
- 実行記録: {対象HEAD・コマンド・終了コード・必要な出力}
- 未達/例外受入: {未達内容・Human Decisionsの明示承認。なければなし}

## 並列計画

- ステップ数: {何回に分けて起動するか} / 依存の深さ: {依存のつながりの最も長い段数}（台帳が読む書式。数字だけ置き換える。例: A と B を同時に起動し、両方の後に C なら ステップ数: 2 / 依存の深さ: 2）
- <並列グループと、直列化した箇所の名指しの理由>
- 作業ツリーの共有可否: <検証が他タスクのパスを読み込むか。読み込むならレーン分割、分けないなら停止待ちの明記>

| Lane | 担当タスク | Branch | Worktree | Executor session | 合流順 |
| --- | --- | --- | --- | --- | --- |

## Blockers

- なし

## Next actions

- <次のセッションが最初にやること>

## Log（判断と経緯の時系列記録）

- <日付時刻> <出来事・判断・根拠>
