---
name: agent-team
description: Claude Codeでagent-teamを実行するためのラッパー。「/agent-team」「チームで開発」「分解して並列で」「ミッション」「Codex部隊に」「複数モジュールにまたがる開発」、init/status/resumeで共通本体と併読する。
---

# agent-team — Claude Code実行経路

共通本体 `~/.agents/skills/agent-team/SKILL.md` を読む。共通本体が直接ロードされた場合も本書を使う。
agent-team中の分担は本書と共通本体を適用し、通常セッション用CLAUDE.mdの役割分担で上書きしない。

## 設定と起動
- `~/.agents/skills/agent-team/references/defaults.yaml` のroutingを、プロジェクトteam.yamlのroutingで項目単位に上書きする。limitsも同様。未知キーは無視する。
- CLIのmodel/effortは解決したyaml、Agentのmodelはagent定義が正本（yamlの明示指定があればそれを渡す）。CLI値が未定義の場合だけcodex-protocol §1へフォールバックする。
- モデル・effortは事前定義を使う。毎dispatchの再照合や人間確認を増やさない。設定変更時に定義・対応経路を確認する。
- `cli: codex` を実行するときだけ `~/.agents/docs/codex-protocol.md` を読む。実装は§3d、調査・計画/コードレビューは§3a、継続は§3c（実装にはsandbox指定）。
- CLIの共通規律はdispatchを優先し、プロトコルの既定モデル・修正回数・親の直接実装への切替で上書きしない。
- `agent:` はAgentツールで名前指定して起動し、継続は同じAgentへのSendMessage。role skillの正本パスと契約/対象を必ず渡す。
- 非同期起動し、CLIのsession ID・出力・エラーログを記録する。完了通知で回収する。
- Windowsのgit `ref:path` はPowerShellで全体を引用する。Git Bashが必要ならMSYS_NO_PATHCONV=1を使う。

## レビュー経路
| 対象 | 担当 |
| --- | --- |
| 親の計画 | routing.codex-review（team-plan-reviewer）＋初回routing.plan-probe |
| Codex実装 | routing.codex-review（独立ゲート）とrouting.review（別ベンダーの独立ゲート） |
| coding-agent実装 | routing.codex-review（team-code-reviewer） |
| express | `~/.agents/skills/agent-team/references/express.md` に従う |

両ゲートの初回は互いの結果を見せず並行実行し、指摘をまとめる。executor自身の品質確認は補助であり独立ゲートの代替にしない。
レビューの版・再確認・縮退・証拠は `~/.agents/skills/agent-team/references/dispatch.md` に従う。

## executor（節約運用）
- 親がFableなら[3]の承認後にrouting.executorへ[4]〜[6]を委任する。それ以外・極小1タスク・起動不可なら親が進行管理する。
- 渡すものは共通本体・dispatch・本書のパス、ミッション、分解骨子、契約清書の指示、停止条件。
- executorはミッションとqueueへ記帳できる。STATE縮約は親だけ。
- executorはCLI worker・CLI reviewerを起動できるが、Agentツールによる孫起動はしない。coding-agentと独立reviewerのAgent起動は親へ依頼する。親は待機中も依頼を回収して起動・結果返却する。
- 設計変更、同一タスク2回切替、usage limit、人間判断、破壊的Git操作の判断は親へ返す。同じexecutorへ追加指示して継続する。

## 検証・縮退
- 完了ゲートは親/executor、またはrouting.cc-choreへ委譲する。元の実行記録を親が観測できない場合は未検証とし、親側で再実行する。
- CLI restricted sandboxで不可の環境準備・Git書込・ブラウザ等は、実行可能な親側経路が担当する。ベンダー名だけで可否を判断しない。
- 調査のCLI usage limitは再試行せずrouting.cc-researchへ（enumerate/semanticの定義を使う）。人間がCC調査を指定した場合も同じ経路。
- 実装のusage limitは親へ戻して環境レーン等への再割当を判断する。レビューの利用不可は共通の縮退規則で扱い、未達を通常doneにしない。
