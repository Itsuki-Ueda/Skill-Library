---
name: agent-team
description: "調査・設計判断を伴う機能追加、不具合修正、リファクタリングと、その継続作業に使う。調査のみ、レビューのみ、誤字修正は対象外。"
---

# agent-team — Claude Code実行経路

共通本体 `~/.agents/skills/agent-team/SKILL.md` を読む。共通本体が直接ロードされた場合も本書を使う。
agent-team中の分担は本書と共通本体を適用し、通常セッション用CLAUDE.mdの役割分担で上書きしない。

## 設定と起動
- `~/.agents/skills/agent-team/references/defaults.yaml` のroutingを、プロジェクトteam.yamlのroutingで項目単位に上書きする。limitsも同様。未知キーは無視する。
- CLIのmodel/effortは解決したyaml、Agentのmodelはagent定義が正本（yamlの明示指定があればそれを渡す）。CLI値が未定義なら推測で埋めず、設定を直す。
- `~/.agents/docs/codex-protocol.md` は、CLIの起動失敗・sandboxの制限・`cx-run.sh` に無い形が要るときだけ読む。食い違ったらdispatchに従う。
- CLIは `bash ~/.agents/skills/agent-team/scripts/cx-run.sh`（impl / ask / review / resume）で、プロンプトをファイルに書いてBashツールの `run_in_background` で起動する。コマンドを手で組み立てない。スクリプトが `<out>`・`<out>.err`・`<out>.exit` を作り、完了時にsession IDを1行で出す。
- `agent:` はAgentツールで名前指定して起動し、継続は同じAgentへのSendMessage。role skillの正本パスと契約/対象を必ず渡す。Plugin経由（クラウド）では名前に `skill-library:` が付く。
- session IDと `<out>` 系のパスを記録し、回収は完了通知で行う。起動元のexecutorが交代して通知を受けられない場合だけ、後任は `<out>.exit` の出現を待機手段（Monitor等）で1回待ち、**終了コード0かつ `-o` が空でない**ことで完了と判定する。定期的に見に行かない。`-o` の中身の合否（NEED-DECISION等）は別に読む。
- Windowsのgit `ref:path` はPowerShellで全体を引用する。Git Bashが必要ならMSYS_NO_PATHCONV=1を使う。
- 別のworktree（他ミッション・レーン）のファイルを書くときは、先に `EnterWorktree(path=<そのworktree>)` で切り替えてから書き、終わったら `EnterWorktree` で元のworktreeへ戻る。別worktreeへのWrite/Editはフックで止められるため。止められてもBashやコピーで回り込まない（WriteとBashを同時に送らない）。レーンのexecutorは自分のレーンのworktreeに `EnterWorktree` してから作業する。

## レビュー経路
| 対象 | 担当 |
| --- | --- |
| 親の計画 | routing.codex-review（team-plan-reviewer）＋初回routing.plan-probe |
| Codex実装（executor運用） | routing.codex-review＋executorの直読 |
| Codex実装（親が直接進行管理） | routing.codex-review＋routing.review |
| coding-agent実装 | routing.codex-review（team-code-reviewer） |
| express | `~/.agents/skills/agent-team/references/express.md` に従う |

executor運用では、独立性はCodexレビュー、別ベンダーの視点はexecutor（既定Opus）の直読が担う。両ゲートとも合格が必要。初回は互いの結果を見ず並行して確認し、指摘をまとめる。
レビューの版・再確認・縮退・証拠は `~/.agents/skills/agent-team/references/dispatch.md` に従う。

## executor（節約運用）
- 親がFableまたはOpusなら[3]の承認後にrouting.executorへ[4]〜[6]をミッション単位で委任する。例外はexecutorを起動できないときだけで、1タスクでも委任する。それ以外（Sonnet等）なら親が進行管理する。
- 渡すものは共通本体・`references/execute.md`・dispatch・本書のパス、ミッション（`型:` に型があればその型のファイルのパスも）、分解骨子、契約清書の指示、停止条件。コマンドの形（`cx-run.sh` の引数など）は依頼文に書き写さず、スキルの節名で指す。委譲の直前にその節を読み直す。
- executorはミッションとqueueへ記帳できる。STATE縮約は親だけ。
- executorはCLI worker・CLI reviewerに加え、routingのagent（coding-agent・reviewer）もAgentツールで自分が起動する。結果は、次の項の差し戻しと同じく `<out>.report.md` と空の `<out>.done` を作らせ、`wait-done.sh` で待つ。会話の記録の検索や、届いた返事の文面で完了を判定しない（サブエージェントからのAgent起動はすぐ返ることがある）。親は中継しない。同じステップのタスクは1つのメッセージにAgent呼び出しを並べて同時に起動する。
- 差し戻しは同じエージェントへSendMessageで送り、末尾に「報告の全文を `<out>.report.md` に書き、最後に空の `<out>.done` を作ってから報告を返す」と添える（`<out>` は作業ツリーの外で、依頼ごとに新しい名前。例: `<タスク>-r2`。古い `.done` が残ると待たずに完了と判定される）。送ったら番を終えず（終えるとexecutorが止まり結果を受け取れない）、Bashツール（timeout 600000）で `bash ~/.agents/skills/agent-team/scripts/wait-done.sh <out>.done` を実行して待つ（TIMEOUTなら再実行）。同じステップの差し戻しはまとめて送り、全員の `.done` を1回の `wait-done.sh` に並べ、返るたびに出た分を処理して残りを待ち直す。DONE後は `<out>.report.md` を正とし、遅れて届いた正式報告は親へ転送しない。
- 設計変更、同一タスク2回切替、レビュー上限超過、usage limit、人間判断、破壊的Git操作の判断は親へ返す。孫（coding-agent・reviewer・CLI）からのエスカレーション・NEED-DECISION・P0/P1の設計指摘も、executorが自分で決着させず親へ返す。返すときは作業を止め、判断に要る事実と選択肢を添える。同じexecutorへ追加指示して継続する。
- レーン運用ではレーンごとに1体のexecutorを置き、親が起動する。レーン間の受け渡し（合流・範囲変更の配布）は親が行う。
- executorはコンテキスト上限に近づいたら `~/.agents/skills/agent-team/references/templates/HANDOVER_TEMPLATE.md` の形で引き継ぎメモをミッションのLogに残し、親へ交代を求める。交代のたびに代・理由・消費トークンをミッションに記録する。理由の無い交代は記録しない。

## 検証・縮退
- 完了ゲートはexecutor運用ではexecutor自身が実行し、直接進行管理では親が実行する。元の実行記録を親が観測できない場合は未検証とし、親側で再実行する。
- CLI workerの検証は `python ~/.agents/skills/agent-team/scripts/cx_evidence.py <session id> --worktree <作業場所>` でCodexのセッション記録を見る。契約のVerificationのコマンドが最終変更より後に終了コード0で記録されていれば親は再実行せず、記録に無い・変更前・sandboxで実行できなかったものだけ親が実行する。親が集約ファイル登録などで作業場所を変えた後は、影響する検証を親が実行する。workerの撮影（`capture.sh`）も同じ記録で最終変更より後かを確かめ、PNGはReadで開いて見る。
- sandbox内のworkerが起動したプロセス（塞がった開発サーバのポート等）は親の権限では止められないので、Codexに `Stop-Process -Id <PID>` を実行させる（PIDは `netstat -ano` で特定）。
- CLI restricted sandboxで不可の環境準備・Git書込・ブラウザ等は、実行可能な親側経路が担当する。ベンダー名だけで可否を判断しない。
- 調査のCLI usage limitは再試行せずrouting.cc-researchへ（そこに定義した model を使う）。人間がCC調査を指定した場合も同じ経路。
- 実装のusage limitは親へ戻して環境レーン等への再割当を判断する。
