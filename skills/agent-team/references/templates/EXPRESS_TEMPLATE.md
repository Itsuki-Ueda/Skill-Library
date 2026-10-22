# T-E-XXX: <title>

ネットワーク: <不要 | 要: workerが流す開発サーバー・ブラウザのテスト・E2E・撮影の名前>（要なら cx-run.sh に --net）

## Goal

<このタスクで成立させる状態>

## Acceptance

- <入力・操作に対して外部から観測できる成功条件。合意済みの実装方針は Constraints へ>

## Constraints（合意済みの制約がある場合のみ・不要なら削除）

- {守るべき境界、互換性、合意済みの実装方針}

## Allowed paths

- `path/to/file`

## Do not modify

- `.agents/` 配下すべて、`AGENTS.md`、`CLAUDE.md`

## Verification（worker自身が実行できる範囲の自己検証）

- worker: 契約範囲に関係する実在のtypecheck / lint / test等と合格条件を記載し、実行する（統合後の全体ビルドと verify は親）。
- {workerが実行するコマンドと合格条件、または目視確認手順}

## 画面確認（画面に表示されるファイルを変える、またはモックがあるタスクは必須。不要でも消さず「不要: 理由」と書く）

dispatch「画面確認（前倒し）」に従う。

- モック: <ファイルパス / なし>（見た目の正本。中身を契約に書き写さない）
- 確認する画面・状態: <URLパス / 表示状態 / 画面幅 / 対応するモックの画面名>
- verify: <GENERAL_TEMPLATEと同じ。機能地図の機能名と入口のコマンドと、流す人（worker / 進行管理者） / なし>
- 撮影: <verify が無いとき。GENERAL_TEMPLATEと同じ `capture.sh` のコマンド。ログインが要る画面はプロジェクトの撮影スクリプトのコマンド>

## Mutation list（テストを書く場合のみ・不要なら削除）

- <壊したら落ちるはずの変異（test-policy 原則6〜11）>

## Report

- team-worker「報告形式」に従う。
