---
name: agent-team
description: "調査・設計判断を伴う機能追加、不具合修正、リファクタリングと、その継続作業に使う。調査のみ、レビューのみ、誤字修正は対象外。"
---

# agent-team — Claude Code実行経路

共通本体 `~/.agents/skills/agent-team/SKILL.md` を読む。共通本体が直接ロードされた場合も本書を使う。
agent-team中の分担は本書と共通本体を適用し、通常セッション用CLAUDE.mdの役割分担で上書きしない。

## 設定と起動
- `~/.agents/skills/agent-team/references/defaults.yaml` のroutingを、プロジェクトteam.yamlのroutingで項目単位に上書きする。limitsも同様。未知キーは無視する。
- CLIのmodel/effortは解決したyaml、Agentのmodelはagent定義が正本（yamlの明示指定があればそれを渡す）。CLI値が未定義の場合だけcodex-protocol §1へフォールバックする。
- モデル・effortは事前定義を使う。毎dispatchの再照合や人間確認を増やさない。設定変更時に定義・対応経路を確認する。
- `cli: codex` を実行するときだけ `~/.agents/docs/codex-protocol.md` を読む。実装は§3d、調査・計画/コードレビューは§3a、継続は§3c（実装にはsandbox指定）。
- CLIの起動は `bash ~/.agents/skills/agent-team/scripts/cx-run.sh`（impl / ask / review / resume）を既定とし、コマンドを手で組み立てない。プロンプトはファイルに書いて渡す。Bashツールで `run_in_background` 起動する。`<out>`・`<out>.err`・`<out>.exit` を同スクリプトが作り、完了時にsession IDを1行で出す。
- CLIの共通規律はdispatchを優先し、プロトコルの既定モデル・修正回数・親の直接実装への切替で上書きしない。
- `agent:` はAgentツールで名前指定して起動し、継続は同じAgentへのSendMessage。role skillの正本パスと契約/対象を必ず渡す。
- 非同期起動し、CLIのsession ID・`-o` 出力・エラーログ・終了コードファイル（codex-protocol §3d の `<out>.exit`）のパスを記録する。回収は完了通知を既定とする。起動元のexecutorが交代して通知を受けられない場合だけ、後任は `<out>.exit` の出現を待機手段（Monitor等）で1回待ち、**終了コード0かつ `-o` が空でない**ことで完了と判定する。定期的に見に行かない。`-o` の中身の合否（NEED-DECISION等）は完了判定とは別に読む。usage limit・タイムアウト・中断時に `-o` が残るかは未確認（2026-09-22時点、codex-cli 0.153.4）。
- Windowsのgit `ref:path` はPowerShellで全体を引用する。Git Bashが必要ならMSYS_NO_PATHCONV=1を使う。

## レビュー経路
| 対象 | 担当 |
| --- | --- |
| 親の計画 | routing.codex-review（team-plan-reviewer）＋初回routing.plan-probe |
| Codex実装（executor運用） | routing.codex-review＋executorの直読 |
| Codex実装（親が直接進行管理） | routing.codex-review＋routing.review |
| coding-agent実装 | routing.codex-review（team-code-reviewer） |
| express | `~/.agents/skills/agent-team/references/express.md` に従う |

Fable親のexecutor運用では、独立性はCodexレビュー、別ベンダーの視点はexecutor（既定Opus）の直読が担う。executorは孫Agentを起動できないため、別reviewerの追加起動は要求しない。両ゲートとも合格が必要。初回は互いの結果を見ず並行して確認し、指摘をまとめる。
レビューの版・再確認・縮退・証拠は `~/.agents/skills/agent-team/references/dispatch.md` に従う。

## executor（節約運用）
- 親がFableなら[3]の承認後にrouting.executorへ[4]〜[6]を委任する。例外はexecutorを起動できないときだけ。規模による例外は設けない（小さいものはIntakeでexpressに振られており、本節の対象外。「1タスクだから」で親が直接進行管理しない）。親がFable以外なら親が進行管理する。
- 渡すものは共通本体・dispatch・本書のパス、ミッション、分解骨子、契約清書の指示、停止条件。
- executorはミッションとqueueへ記帳できる。STATE縮約は親だけ。
- executorはCLI worker・CLI reviewerを起動できるが、Agentツールによる孫起動はしない。coding-agentが必要なタスクだけ親へ起動を依頼する。親は待機中も依頼を回収して起動・結果返却する。
- 設計変更、同一タスク2回切替、usage limit、人間判断、破壊的Git操作の判断は親へ返す。同じexecutorへ追加指示して継続する。
- レーン運用ではレーンごとに1体のexecutorを置き、親が起動する。レーン間の受け渡し（合流・範囲変更の配布）は親が行う。
- executorはコンテキスト上限に近づいたら `~/.agents/skills/agent-team/references/templates/HANDOVER_TEMPLATE.md` の形で引き継ぎメモをミッションのLogに残し、親へ交代を求める。交代のたびに代・理由・消費トークンをミッションに記録する。理由の無い交代は記録しない。

## 検証・縮退
- 完了ゲートはexecutor運用ではexecutor自身が実行し、直接進行管理では親が実行する。元の実行記録を親が観測できない場合は未検証とし、親側で再実行する。
- CLI workerの検証は、Codexのセッション記録を元記録として `python ~/.agents/skills/agent-team/scripts/cx_evidence.py <session id> --worktree <作業場所>` で確認する。契約のVerificationのコマンドが「最終変更より後」に終了コード0で記録されていれば、親は再実行しない。記録に無いもの・「変更前」のもの・sandboxで実行できなかったものだけ親が実行する。親が集約ファイル登録などで作業場所を変えた後は、影響する検証を親が実行する。workerの撮影（`capture.sh`）も同じ記録で「最終変更より後」かを確かめ、PNGはReadで開いて見る。
- sandbox内のworkerが起動したプロセスは親の権限では止められない（アクセス拒否）。開発サーバのポートが塞がったまま等の取り残しを見つけたら、Codexに `Stop-Process -Id <PID>` を実行させて止める（PIDは `netstat -ano` で特定する）。
- CLI restricted sandboxで不可の環境準備・Git書込・ブラウザ等は、実行可能な親側経路が担当する。ベンダー名だけで可否を判断しない。
- 調査のCLI usage limitは再試行せずrouting.cc-researchへ（enumerate/semanticの定義を使う）。人間がCC調査を指定した場合も同じ経路。
- 実装のusage limitは親へ戻して環境レーン等への再割当を判断する。レビューの利用不可は共通の縮退規則で扱い、未達を通常doneにしない。
