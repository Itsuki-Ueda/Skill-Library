---
name: agent-team
description: 機能追加・不具合修正・リファクタリングを、規模に応じた実装・レビュー・検証で進める開発スキル。調査や設計判断を伴う開発依頼、および進行中の開発の追加修正・再開に適用する。誤字修正などの軽微な変更は除く。
---

# /agent-team — チーム開発の共通手順

## 適用範囲

agent-teamで進行中の開発は、後続の追加実装・修正・再開にも継続適用する。毎回の明示指定は不要。無関係な依頼や軽微な変更は対象外とする。

## 原則

- 現在のセッションがOrchestrator。親モデルの切替で品質条件は変えない。計画・割当・受入・状態管理を担当し、実装はworkerへ委譲する。集約ファイルの登録だけは親が担当する。
- サブエージェントは事前定義を使う。セッションごとのモデル選択やdispatchごとの設定照合は追加しない。
- 通常ミッションの計画・コードは独立レビューと別ベンダーの視点を確保する。担当の組合せはハーネス用ラッパーに従い、実装者の自己承認は禁止する。expressは `references/express.md` に従う。
- 契約、レビュー、統合後の検証が揃うまで完了としない。現在の要件を満たす簡潔な実装を選び、既存機能を再利用する。
- 状態はファイルに保存し、上限・書込権は `references/state-layer.md` に従う。

## 読み込みと設定

1. 使用中のハーネス用ラッパーを読む（既読なら再読不要）:
   Claude Code: `~/.agents/claude/skills/agent-team/SKILL.md` /
   Codex: `~/.agents/codex/skills/agent-team/SKILL.md`。
   共通本体が直接ロードされた場合もこの入口を使う。
2. 本流・resumeでは `references/defaults.yaml` と `.agents/config/team.yaml` を読む。設定の解決はラッパーに従う。
3. `.agents/state/STATE.md` → 対象ミッション → `.agents/state/MEMORY.md`。履歴全量は読まない。
4. 工程に必要な資料だけ読む: 分解・実行はdispatch、S判定はexpress、状態操作はstate-layer、契約作成はtemplates。実行プロトコルは該当経路だけ読む。

作業ツリーに `.agents/` が無い場合は、`git log --all --oneline -- .agents` と既定ブランチの状態ファイルを調べる。
履歴にあれば敷設済みとして対象commit/PRを特定し、復元・統合を提案する。履歴にも無い場合のみinitを提案する。
Git操作は `~/.agents/skills/git-ops/SKILL.md` に従う。

## モードと規模

| 呼び出し | 動作 |
| --- | --- |
| `/agent-team {依頼}` | 前提確認・intake → S/M/L判定 |
| `/agent-team init` | 下記の敷設手順 |
| `/agent-team status` | 行数、STATE/BACKLOG/queueを読み、現状・超過を報告するだけ。記憶整理・session記帳・commitはしない |
| `/agent-team resume` | 下記の引継ぎ手順 |

- **S / express**: 対象ファイル確定、設計判断不要、diff一読でレビュー可能。`references/express.md` へ。
- **M**: 分解不要だが契約・独立レビューが必要。1タスクで下記工程を回す。
- **L**: 依存する複数タスクへ分解し全工程を回す。
- 規模判定に迷ったら人間に確認する。単発PR中心のフローを希望する場合はautodevを案内する。

## ミッションフロー

各工程の完了条件を満たしてから次へ進む。未達はミッションとSTATEのBlockersに記録する。

### [0] 前提確認
- 設定と状態を読み、`bash ~/.agents/skills/memory-ops/scripts/check-size.sh` で計測する。
- 閾値超過は `~/.agents/skills/memory-ops/SKILL.md` に従い整理する。閾値+10%未満のみ[7]へ先送り可。statusは報告のみ。
- 完了条件: 必須設定・状態が読め、上限内または許容された先送りである。

### [1] Intake
- Goal、検証可能なAcceptance、制約、Human Escalationを確定する。不明点だけ人間に確認する。
- `references/templates/MISSION_TEMPLATE.md` からM-xxxを採番し、STATEに索引を追加する。
- ブランチはgit-opsの命名に従う（例: `feat/m-xxx-summary`）。
- 完了条件: 成功条件と作業範囲を文書化した。

### [2] 調査（必要時）
- 調査担当へ `~/.agents/skills/team-researcher/SKILL.md`、質問・範囲・除外範囲を渡す。
- 独立した調査は並列化できる。重要領域の意図的な重複で矛盾を検出する。報告の採用規律はdispatchを参照。
- 読み取り専用担当の結果は親が `queue/research/` に保存する。
- 誤っていると計画全体を覆す前提は、権限内の小さな実験で検証する（根拠E1）。
- 完了条件: 判断に使う主張に根拠がある。

### [3] 分解・計画レビュー
- Goal / Acceptance / Allowed paths / 依存 / 実装者を骨子にする。契約はdispatch前に `GENERAL_TEMPLATE.md` へ清書する。委任されたexecutorがいれば清書を任せる。
- テストを書く契約では、骨子段階から変異リストを作る。**どのファイルのどの箇所を何に変えるか**を特定し、機構の削除・置換では維持すべき挙動の変異も列挙する（E2）。
- Acceptanceに登場するデータ・状態・設定値の生産者/消費者表を埋める。空欄ならdispatchしない。表の効果は数ミッション後に件数で点検する（E3）。
- `references/dispatch.md` で担当を選び、Allowed paths・依存の交差を確認する。直列化は競合資源を名指しする。集約ファイルは親の担当とする。
- 別ベンダーの独立担当へ `~/.agents/skills/team-plan-reviewer/SKILL.md` と分解文書を渡す。初回はplan-probeも並走させる。
- probeには `~/.agents/skills/team-plan-probe/SKILL.md` と文書パスだけを渡す。ズレは**曖昧箇所の候補**。読み落としか原文の不足か確認し、初回修正へまとめる。probeは合否に数えない。
- レビューの合格・版記録・再レビューはdispatchに従う。上限は `limits.fix_rounds_plan`。
- 指摘の由来を「修正起因／以前から存在」で区別する。修正起因が過半なら分解を見直す。上限超過時は文書の矛盾／実験が必要／上流設計の判断に分類し、再分解・スパイク・gpt-consult等の選択肢を人間に提示する（E1）。
- 分解と並列計画は人間の承認を1回得る。既存の承認範囲内で同じ確認を繰り返さない。
- 完了条件: 契約・計画レビュー・承認と並列計画が揃った。

### [3.5] 進行管理の委譲（該当時）
- ラッパーに定義された節約運用が該当する場合のみexecutorへ[4]〜[6]を委任する。
- 委任はミッションとqueueへの記帳に限定する。STATEの縮約、人間の判断、破壊的操作の判断は親に残す。委任先が使えなければ親が進行管理する。
- この委任は実装者の変更やレビュー条件の緩和を意味しない。

### [4] Dispatch
- 契約全文と役割スキルを名指しし、ラッパーの起動方法を使う。session ID、成果物パス、開始時刻を記録する。
- 非交差・依存解決済みのタスクだけ並列実行する。完了通知ごとに次のdispatchを判断し、バッチ全体の終了を待たない。
- 完了条件: 各タスクが起動済み、または依存待ちとして記録されている。

### [5] コードレビュー・修正
- worker報告を親が `queue/reports/T-xxx.md` に保存し、対象差分・新規ファイル・契約適合を確認する。
- 集約ファイルの登録があれば、親がレビュー前に追加する。**登録を含む最終変更**をレビュー・検証し、合格commitへ同梱する。
- `~/.agents/skills/team-code-reviewer/SKILL.md` を独立担当に渡す。複数レビューの指摘は一度に統合し、満たすべき性質を示して元のworkerへ差し戻す（E4）。
- 再レビュー・版の更新・上限超過はdispatchに従う。
- テスト契約は親またはexecutorが変異を1〜2件抜き取り実施し、workerの証跡と照合する（E2）。並走時の汚染防止はdispatch参照。
- 合格内容と実ファイルの一致を確認し、親が対象パスをstageしてtask commitする。未レビュー変更を混ぜない。
- 完了条件: 報告・版に紐づく合格・検証証拠・task commitが揃った。

### [6] 統合・完了ゲート
- タスク間の接続・共有資源・順序依存がある場合は統合後の整合性を独立レビューで確認する。契約と実際の変更から判断し、表の行の有無だけで省略しない。既存レビューに組み込める（別呼び出し必須ではない）。
- 未コミット変更ゼロを確認し、統合後HEADで `verify.post_change` と `verify.smoke` を実行する。
- テストを書いた場合は未実施分から変異を数件抜き取り、対応テストの失敗を確認して復元する。[5]で実施済み・対象不変なら再実施不要。
- 実行担当はラッパーに従い、対象版・コマンド・終了コード・必要な出力を記録する。実行の有無と検証内容の適切さは別々に確認する。自己申告だけでは合格にしない。
- 失敗は原因を切り分け[5]へ戻す。ゲートを緩めない。コード変更後は影響するレビュー・検証を更新する。
- 完了条件: 最終版に対する必要なレビュー・実行検証・変異証拠が揃った。

### [7] 受入・状態整理
- Acceptanceと証拠を照合する。フロントエンドは実描画を確認する。親の差分確認は要件に直結する範囲を抜き取り、独立レビュー全量を機械的に繰り返さない。
- 必須レビュー未達はdispatchの縮退規則に従い、通常のdoneにしない。
- state-layerに従いSTATEのLogを1行に縮約し、sessionをクリアしてミッションをclosedへ移す。教訓はmemory-opsの入口に従う。
- 行数を再計測し、必要な整理と状態commitを終える。PR希望時はミッション単位で作成する。
- 完了条件: 受入証拠と引継ぎ可能な状態が揃った。

### [8] Closeout・最終報告
- git-opsに従いミッション由来の一時worktree・統合済みブランチを後片付けする。
- 未統合・ロック等で保持する場合は理由と次の削除条件を記録する。未処理を黙って放置しない。
- 変更、検証、レビュー達成状況、例外受入・残課題、保持資源を報告する。

## init
1. `references/templates/init/` からconfig/state/backlog/queueを敷設する。stateにはmissions/closed、queueにはtasks/reports/reviews/researchを作る。
2. 実在する検証コマンドを確認して `verify.post_change` / `verify.smoke` をユーザーと確定する。未確定で本流へ進まない。
3. `AGENTS-section.md` の最小ポインタをプロジェクトAGENTS.mdへ追加し、CLAUDE.mdが無ければ `@AGENTS.md` を置く。規則本文を複製しない。
4. `.agents/tmp/` をgitignoreへ追加し、状態本体は追跡する。
5. 空repoの初回コミットはgit-setup、既存repoへの敷設はgit-opsに従う専用PR。開発ミッションに同乗させず先に統合する。

## resume
1. STATEと対象ミッションを読む。複数activeなら対象を確認する。
2. 他sessionのActive sessionが残る場合は二重運転を警告し、人間が引継ぎ可否を判断するまで記帳・整理しない。
3. 上限を計測・整理し、自sessionを記録する。Tasks/Next actionsから再開する。
4. 未回収の担当は記録したsession・報告・ラッパーの継続手段で確認する。未回収を完了扱いにしない。

## 禁則・参照
- 契約なしのdispatch、workerによるgovernance編集、権限回避、未実行の合格報告は禁止。
- workerのgovernance禁止には `.agents/`、AGENTS.md、CLAUDE.md、ハーネス設定を含む。報告・調査結果の保存は親が代行する。
- 通常ミッションの独立レビューをexpressの例外で省略しない。
- 規則の実測背景は `references/evidence.md`（必要時のみ）。状態の詳細はstate-layer、実行共通規律はdispatchを参照。
