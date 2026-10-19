---
name: backlog-files
description: "Backlog のプロジェクトの共有ファイルを一覧したり、ダウンロードして中身を読んだりするときに使う。「Backlogのファイル」「共有ファイル」も対象。"
---

# backlog-files — Backlog の共有ファイルを見る

Backlog の連携（MCP）には共有ファイルを扱う機能がないので、`scripts/backlog_files.py`（Python の標準ライブラリだけ）で Backlog の API を直接呼ぶ。

## 使い方

Windows では `python`、クラウドでは `python3` で動かす。

```bash
# 参加しているプロジェクトのキーと名前（プロジェクトキーが分からないとき）
python ~/.agents/skills/backlog-files/scripts/backlog_files.py projects

# 一覧（フォルダを省くと一番上。フォルダは中まで降りないので、DIR の行を見て辿る）
python ~/.agents/skills/backlog-files/scripts/backlog_files.py list {プロジェクトキー} [{フォルダのパス}]

# ダウンロード（ファイルIDは一覧の1列目。保存先を省くと一時フォルダの backlog-files/）
python ~/.agents/skills/backlog-files/scripts/backlog_files.py get {プロジェクトキー} {ファイルID} [{保存先フォルダ}]
```

一覧の列: `ID  種類(FILE/DIR)  サイズ  更新日時  パス`。`get` は保存したファイルのパスを1行出す。

中身を読むときは、出てきたパスを Read で開く（PDF・画像はそのまま読める）。Excel・Word・PowerPoint は xlsx・docx・pptx のスキルを使う。

保存先は作業中のリポジトリの中にしない（業務の資料をコミットしてしまうため）。

## 認証情報（APIキーとスペースの URL）

スクリプトは次の順に探す。APIキーは画面にもログにも出さない。

1. 環境変数 `BACKLOG_API_KEY` と `BACKLOG_SPACE_URL`（例: `https://{スペースID}.backlog.jp`）。クラウドはこちらで、環境のネットワークシークレットに入れる。
2. Windows の資格情報マネージャーの汎用資格情報 `backlog-api`（ユーザー名 = スペースの URL、パスワード = APIキー）。ローカルはこちら（2026-10-19 人間の決定）。

ローカルで初めて使うときは、人間に PowerShell で一度だけ次を流してもらう。`/pass` の後ろに値を書かないと、キーを聞かれて画面にも履歴にも残らない（AI はキーを受け取らない）:

```powershell
cmdkey /generic:backlog-api /user:{スペースのURL} /pass
```

APIキーは Backlog の「個人設定 → API」で発行する。見つからないとスクリプトは登録方法を表示して止まる。

## 確認

`python ~/.agents/skills/backlog-files/scripts/test_backlog_files.py`（偽のサーバーで一覧・取得・404 を確かめる。実キーは使わない）。
