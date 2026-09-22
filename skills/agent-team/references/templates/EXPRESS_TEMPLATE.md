# T-E-XXX: <title>

## Goal

<このタスクで成立させる状態>

## Acceptance

入力・操作に対して外部から観測できる結果で書く。合意済みの実装方針はConstraintsへ記載する。

- <外部から観測できる成功条件>

## Constraints（合意済みの制約がある場合のみ・不要なら削除）

- {守るべき境界、互換性、合意済みの実装方針}

## Allowed paths

- `path/to/file`

## Do not modify

- `.agents/` 配下すべて、`AGENTS.md`、`CLAUDE.md`

## Verification（worker自身が実行できる範囲の自己検証）

- worker: 契約範囲に関係する実在のtypecheck / lint / test等と合格条件を記載し、実行する。
- 親: 統合後の全体ビルドとverify.post_change / verify.smokeを担当する。必須ゲートは省略しない。
- {workerが実行するコマンドと合格条件、または目視確認手順}

## Mutation list（テストを書く場合のみ・不要なら削除）

- <壊したら落ちるはずの変異。テスト方針正本 `~/.agents/docs/test-policy.md` 原則6〜11に従う>

## Report

- 最終メッセージに: 変更ファイル一覧 / 変更概要 / 自己検証の結果 / 残課題
