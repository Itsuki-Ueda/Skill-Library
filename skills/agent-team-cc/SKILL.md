---
name: agent-team-cc
description: "試験中の agent-team 派生。プロジェクトの AGENTS.md・team.yaml が agent-team-cc を指定しているとき、または人間が agent-team-cc と名指ししたときだけ使う。それ以外は agent-team を使う。"
---

# agent-team-cc — 実装を Claude に寄せ、Codex レビューを常駐セッションに頼む agent-team（試験中）

本書は agent-team との**差分だけ**を書く。差分の無い工程・規律はすべて agent-team に従う。
試験で問題が無ければ、本書の差分を agent-team に取り込み、本スキルは消す。

## 読み込み

1. agent-team の共通本体 `~/.agents/skills/agent-team/SKILL.md` と CC ラッパー `~/.agents/claude/skills/agent-team/SKILL.md` を読む。
2. 本書を読む。本書と食い違う箇所は本書を優先する。
3. 設定は `~/.agents/skills/agent-team/references/defaults.yaml` → `~/.agents/skills/agent-team-cc/references/defaults.yaml` → プロジェクトの `.agents/config/team.yaml` の順に、項目単位で上書きして解決する。
4. SessionStart の案内が「agent-team スキルを読む」と言っても、プロジェクトが agent-team-cc を指定していれば本スキルを読む。

## 実装レーン（express・worker・hard-worker を coding-agent に寄せる）

- 3 レーンとも `agent: coding-agent`。Agent ツールで `subagent_type: coding-agent` を名指しし、解決した `model` と `effort` を**毎回引数で渡す**（定義の既定 Opus 5.5 / high に任せない）。
  | レーン | model | effort | 根拠（実装ベンチ 2026-10） |
  |---|---|---|---|
  | express | haiku | high | 3 件で最安・往復 1 |
  | worker | sonnet | high | 料金・時間・往復の釣り合いが最良 |
  | hard-worker | opus | medium | 当時の Opus high より安く速く、品質同等 |
- 起動・差し戻し・回収は CC ラッパーの coding-agent の流れ（executor 節）を使う: Agent を `run_in_background=false` で起動し、差し戻しは同じエージェントへ SendMessage ＋ `wait-done.sh`。`cx-run.sh impl` と `cx_evidence.py` は使わない。
- 契約の「ネットワーク」欄は「不要（CC worker）」と書く（`--net` は Codex 用）。
- worker の検証は Codex のセッション記録が無いので、元の実行記録を親が観測できない。完了ゲートの Verification は進行管理者（executor 運用では executor）が再実行する。
- express の Haiku は、文脈が 10 万トークンを超えると単価が上がり失敗例もある。契約と対象ファイルが大きい課題は express にせず worker（M）に上げる。

## Codex コードレビュー（常駐セッションに Git 経由で頼む）

`routing.codex-review` が `session: git` のとき、コードレビュー（team-code-reviewer）を次の形で行う。手順の正本は `references/codex-session.md`。

`session: local` のときは常駐セッションを使わず、agent-team どおり Orchestrator のマシンで `cx-run.sh review` をその場で回す（Codex がローカルで使える個人のプロジェクト向け。下の 1〜5 と「立ち上げ」は不要）。プロジェクトの team.yaml に `routing: { codex-review: { session: local } }` と書いて切り替える。

1. **準備の確認**（[0] 前提確認で、ミッションごとに 1 回）: `bash ~/.agents/skills/agent-team-cc/scripts/wait-review.sh --repo <リポジトリ> --ready --result-branch <result_branch> --timeout 0`。`git fetch` 1 回なので、セッションを探し回らない。READY の時刻が古いだけでは止まったと判定しない（約 4 時間前の READY でも応答した実例がある）。READY が無ければ下の「立ち上げ」を行い、届くまでのレビューは 5 の縮退で進める（作業は止めない）。
2. **依頼**: レビュー対象（作業ツリーの現在の状態）をスナップショットとして push し、依頼を出す:
   `bash ~/.agents/skills/agent-team-cc/scripts/request-review.sh --repo <作業場所> --id <依頼ID> --base <比較元のcommit> [--paths <対象パス>...]`
   依頼IDは `<M-ID>-<T-ID>-r<N>`（express は `<T-E-ID>-r<N>`）。スクリプトは作業ツリーも index も変えない。出力の head・base の SHA をレビュー記録の対象版に書く。
3. **回収**: `bash ~/.agents/skills/agent-team-cc/scripts/wait-review.sh --repo <リポジトリ> --id <依頼ID> --result-branch <result_branch>` を Bash の `run_in_background: true` で起動し、完了通知で結果ファイルを読む。結果の head SHA が依頼と一致しなければ無効として扱う。
4. 結果ファイルの「codex: exit=」が 0 以外、または「## 失敗」節があれば、失敗として 1 回だけ依頼をやり直す（新しい依頼ID）。
5. **縮退**: READY が無い・`timeout_min` 内に結果が来ない・やり直しも失敗した場合は、agent-team の通常経路（Orchestrator 自身のマシンで Codex CLI を `cx-run.sh review` で起動し、結果をファイルで受け取る）で同じモデル・effort のレビューを回す。そのマシンに Codex CLI とログインが要る。縮退した事実と理由をレビュー記録に残し（Codex レビュー自体は達成扱い）、人間（または起動できるセッション）に常駐セッションの再起動を頼む。
6. 計画レビュー（team-plan-reviewer）は試験の対象外。agent-team どおり `cx-run.sh ask` で回す。

Orchestrator の直読・変異の抜き取り・計測は agent-team から変えない（Codex は同じ差分でも回ごとに指摘がぶれ、仕込んだ不具合を見逃した実例がある。2026-10-17）。

## 立ち上げ（init と、READY が無いとき）

- agent-team の init の最後に、Codex 専用セッションの立ち上げを加える（`session: local` のプロジェクトでは不要）。READY が届いたら敷設完了とし、`.agents/config/team.yaml` の `routing.codex-review.result_branch` に結果ブランチ名を書く。
- 起動できる立場（クラウドセッションを起動できるツールを持つセッション）なら Claude が起動する。できなければ人間に頼む。どちらも手順は `references/codex-session.md`「立ち上げ」で、最初に送る指示は次の 1 行に固定する:
  `~/.agents/skills/agent-team-cc/references/codex-session.md の「常駐セッションの手順」に従う。結果ブランチは <result_branch>。`
- 人間に頼むことは 2 つだけ: リポジトリをクラウドから取り込めるようにする（別アカウントなら共同編集者に追加）ことと、Codex の device-auth の承認。

## 記録と評価

- 起動した coding-agent の agentId をミッションに記録する。試験の評価では `bench/impl/usage.py`（非公開の作業フォルダー）で model・effort・cacheTtl・料金を確かめる。
- レビュー依頼ごとに、依頼の push 時刻と結果の検知時刻をレビュー記録に書く（受け渡しの所要時間を後で比べるため）。
