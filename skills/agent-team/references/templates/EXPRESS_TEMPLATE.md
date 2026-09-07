# T-E-XXX: <title>

## Goal

<このタスクで成立させる状態>

## Acceptance

- <外部から観測できる成功条件>

## Allowed paths

- `path/to/file`

## Do not modify

- `.agents/` 配下すべて、`AGENTS.md`、`CLAUDE.md`

## Verification（worker自身が実行できる範囲の自己検証）

- <sandbox内で実行可能なコマンド、または目視確認手順>

## Mutation list（テストを書く場合のみ・不要なら削除）

- <壊したら落ちるはずの変異。テスト方針正本 `~/.agents/docs/test-policy.md` 原則6〜11に従う>

## Report

- 最終メッセージに: 変更ファイル一覧 / 変更概要 / 自己検証の結果 / 残課題
