---
name: agent-team
description: Claude または Codex(オーケストレーター)がCodexワーカー部隊とCCサブエージェントを指揮する開発チーム運用スキル。依頼を規模判定し、express(小)は直接dispatch、ミッション(大)はタスク契約に分解して並列実装→クロスレビュー→統合完了ゲートで品質保証する。状態は.agents/のファイルに永続化しセッションを跨いで継続。「/agent-team」「チームで開発」「分解して並列で」「ミッション」「Codex部隊に」「複数モジュールにまたがる開発」等で必ず使う。サブコマンド: init(状態レイヤー敷設)/status(現状報告)/resume(進行中ミッション引継ぎ)。単発タスクのPR中心自動開発はautodevが担当(本スキルの対象外)。Codexがオーケストレーターのときは ~/.agents/codex/skills/agent-team/SKILL.md（ハーネス固有の読み替え）を併読。
---

# /agent-team — Claude×Codex チームオーケストレーション

設計書: プロジェクトの `DESIGN.md`（AgentTeamsリポジトリ）。本スキルはその実装。

## 大原則

1. **あなた(このセッション)がOrchestrator** — Lead/Manager/Architect/Strategistの統合体。
   分解・契約作成・dispatch・レビュー・受入・状態管理が仕事。**実装の手は自分で動かさない**。
2. **実装者≠レビュアー** — 独立性（利害なし・文脈ゼロの審査）とクロスベンダー
   （別ベンダーの目）を必ず確保する。実装者と別ベンダーの独立レビューを必ず挟む
   （CC Orchestrator時: Codex実装分は独立Codexレビュー＋Claude側の確認の二重ゲート、
   CC実装分はCodexレビュー。Codex Orchestrator時はラッパーの表）。
   同一実装者・同一セッションによる自己承認は禁止。
3. **完了ゲートは省略しない** — post-change＋smoke（team.yamlのverify定義）が統合後HEADで通るまで、人間に完了を報告しない。expressでも省略しない。
4. **タスクは契約文書で渡す** — 散文で頼まない。Allowed paths/成功条件/検証を明記した契約(references/templates/)がCodexの沼りを防ぐ主防壁。
5. **記憶はファイルへ、ただし上限つき** — このセッションが死んでも次のセッションが続きを引き継げる状態を常に保つ（state-layer.mdの規約）。起動時に読むファイルには上限があり、超過は memory-ops で**実施**して戻す（提案で済ませない）。

## Windows実行の注意（gitの`ref:path`はPowerShellで）

`git show <ref>:<path>`（別ブランチから状態レイヤーを読む等）や、`:`・日本語・
`.agents/` を含むgit引数は、**PowerShellツールで実行し、`ref:path`全体をダブルクオートで囲む**:

```
git show "origin/main:.agents/state/STATE.md"
```

Bashツールで実行すると、MSYSのパス変換が `:`→`;`・`/`→`\` と化けさせ
`unknown revision` (exit 128) で失敗する（実測: 状態レイヤー読み込みが空振りした）。
どうしてもBashで実行する場合は `MSYS_NO_PATHCONV=1` を前置し引数をシングルクオートで囲む。
プロジェクトパスに日本語（例: `個人開発/競馬予想`）を含む環境ではPowerShellの方が安全。

## 前提の読み込み

作業開始前に必ず読む:

1. `~/.agents/docs/codex-protocol.md` — Codex呼び出しの唯一の正本（構文・失敗処理・雛形）
2. 設定の解決: `references/defaults.yaml`（グローバル既定・正本）を読み、
   `.agents/config/team.yaml`（プロジェクト差分）で上書きする。
   未定義キーは defaults.yaml → codex-protocol.md §1 の順にフォールバック。
   未知キーはエラーにせず無視する
3. Orchestratorが Codex のときは `~/.agents/codex/skills/agent-team/SKILL.md` を読み、
   `defaults.yaml` の `codex_routing` を `routing` の代わりに使う。以降の Agentツール／
   SendMessage／AskUserQuestion／`codex exec` の記述はラッパーの読み替え表に従う
4. `.agents/state/STATE.md` → 対象ミッションファイル → `.agents/state/MEMORY.md`

**`.agents/` が作業ツリーに無い場合、即「未敷設」と判断しない。** 先にgit履歴を探索する
（上記「Windows実行の注意」に従い、状態レイヤーの読み出しはPowerShellで）:

```
git log --all --oneline -- .agents          # 全ブランチから敷設コミットを探す
git show "origin/main:.agents/state/STATE.md"  # PowerShell・ref:pathはダブルクオート
```

- ヒットした場合 = **敷設済みだが現在のブランチに無いだけ**（典型: initがミッション
  ブランチ側でコミットされ、mainに未マージ）。該当コミット/ブランチを特定し、
  復元を提案する（例: `git checkout <branch> -- .agents AGENTS.md CLAUDE.md` または
  該当PRのマージ）。人間にコミットIDを尋ねない——自分で見つける。
- ヒットしない場合のみ未敷設。`/agent-team init` を提案する。

## モード分岐

| 呼び出し | 動作 |
| --- | --- |
| `/agent-team <依頼>` | 本流: intake → 規模判定 → express / ミッション |
| `/agent-team init` | 状態レイヤー敷設（下記「init手順」） |
| `/agent-team status` | まず `bash ~/.agents/skills/memory-ops/scripts/check-size.sh` で行数を測る。閾値超過なら**報告の前に memory-ops を実施**（提案ではなく実施）。その後 STATE.md/BACKLOG.md/queue を読み現状報告 |
| `/agent-team resume` | STATE.mdから進行中ミッションを特定し引き継ぐ（下記「resume手順」） |

## 規模判定（intake直後に必ず実施）

- **S (express)**: 変更対象ファイルが事前確定でき、設計判断不要、レビューはdiff一読で足りる
  → `references/express.md` の手順へ。
- **M (1タスクミッション)**: 分解不要だが契約・クロスレビュー・完了ゲートの価値がある
  → ミッションフローをタスク1件で回す（[3]の分解は契約1枚の作成のみ）。
  ユーザーがPR/人間承認の単発フローを望むならautodevを案内。
- **L (フルミッション)**: 依存関係のある複数タスクへの分解が必要 → ミッションフロー全工程。
- 判定に迷ったらAskUserQuestionで人間に確認する。勝手に大きい方へ倒さない。

## ミッションフロー

各工程末尾の☑を確認してから次へ進む。☑できない場合は工程を完了させるか、blockerとしてSTATE.mdに記録し人間に報告する。

### [0] 前提確認
- `.agents/` の存在、team.yaml、STATE.md/対象ミッション/MEMORY.mdの読み込み。
- `bash ~/.agents/skills/memory-ops/scripts/check-size.sh` を実行。閾値超過（STATE.md>100行 /
  MEMORY.md>150行 / INBOX.md>60行）があれば、**作業に入る前に** `memory-ops` の該当サブコマンドを
  実施する（提案ではなく実施。超過が閾値+10%未満なら [7] まで先送り可）。
- ☑ 前提3点を読み、行数を測り、閾値内か蒸留済みである

### [1] Intake
- 人間と対話し、Goal・Acceptance（検証可能な成功条件）・制約・Human Escalation条件を確定（不明点はAskUserQuestion）。
- ミッションID採番（M-001連番）、`state/missions/M-xxx.md` を`references/templates/MISSION_TEMPLATE.md` から作成、STATE.mdのインデックスに1行追加。
- 作業ブランチ `team/M-xxx` を作成。
- ☑ 成功条件が検証可能な形で文書化された

### [2] 調査（必要時のみ）
- **既定はCodex**: codex exec＋`team-researcher` スキル名指しで委譲（dispatch.md §調査dispatch）。
  並列fan-out可。結論に効く重要領域は複数の調査依頼で**意図的にスコープを重複**させる
  （矛盾の発生が誤報検出のシグナルになる）。
- **CC researcherサブエージェントへ切り替える条件**: (a)人間がCC委託を明示した場合
  (b)Codexがusage limitで使えない場合（プロトコル§6(d): リトライせず即切替）。
  CC側は列挙=haiku、意味解釈=sonnetでルーティング。
- 注: /agent-team実行中の調査ルーティングは本スキルとdefaults.yamlが正であり、
  グローバルCLAUDE.md第1層（CC researcher既定）より優先する。
  ただし**第1.5層の検証プロトコルは委譲先を問わず必ず適用**する
  （証拠なし主張の破棄・結論に効く主張と否定形主張の裏取り）。
- 結果は `.agents/queue/research/` へ保存させてから採用。
- **高リスクの未知はスパイクで潰す**: 調査結果が出揃ったら「この前提が誤っていたら
  分解ごとやり直しになるものはどれか」を問う。該当する前提（依存ライブラリ・DBの型・
  既存関数の実挙動等）は文書調査でなく**捨てる前提の実験コード（スパイク）で実際に確かめる**。
  文書レビューは前提の正しさを確認できない（実測: 存在しないDB型と既存関数の破壊挙動は
  数分の実験で判明する問題だったが、9ラウンドのプランレビューでは一度も出なかった）。
- ☑ 判断に使う主張は証拠(file:line)付き、または自分で裏取りした

### [3] 分解
- タスク契約は**骨子**で作成する: タスクごとに Goal / Acceptance / Allowed paths /
  依存 / 実装者 を箇条書きにした分解文書（GENERAL_TEMPLATE全文への清書は
  executorの仕事＝Orchestratorの出力トークンを長文穴埋めに使わない）。
- **テストを書くタスクには変異リスト（Mutation list）を骨子段階で列挙する**（GENERAL_TEMPLATE参照）。
  実測根拠: 契約に列挙した変異は11/11検出、列挙外は15/17素通り（M-011/M-012監査）。
  「壊れた実装なら落ちるテストを書け」という一般論だけでは効かない——具体的な変異を書く。
  変異は**「どのファイルのどの箇所を何に変えるか」まで特定する**——曖昧だとworkerは
  容易な方だけを壊して「検出できた」と報告する（同型の素通り4回、⚠️付き警告でも防げず。M-001実測）。
  **既存の機構を消す/置き換えるタスクでは「変わらないもの」を守る変異を必ず列挙する**
  ——Acceptanceに「退行させない」と書くだけでは守られない（実測: 締切ガード丸ごと削除で全緑）。
- **Acceptanceに登場するデータ・状態・設定値には参照関係表（生産者/消費者）を必須にする**
  （GENERAL_TEMPLATE参照）。空欄が1つでもあれば契約は未完成——dispatch前に埋めるかNEED-DECISION。
  実測根拠: M-001の契約起因欠陥3件（本番全滅級2件含む）はすべて「生産者不在／消費側の未追随」型。
  （形骸化検査: 導入2026-07-30。数ミッション後に「空欄のままdispatchされた回数／表が止めた欠陥数」を
  数え、止めていなければこの表は廃止する）
- 実装者ルーティングを契約ごとに機械的に判定（`references/dispatch.md` §ルーティング）。
- Allowed pathsの交差検査: 非交差タスク同士を並列グループ化、交差・依存があるものは直列化。
  直列にする場合は競合する資源を名指しした理由をミッションファイルに書く（「同じrepoだから」のような広い理由で直列にしない）。
  **集約ファイル**（複数タスクが1行ずつ追記したくなるファイル）はこの検査で特定し、
  どのタスクのAllowed pathsにも入れない（登録はOrchestratorがcommit時に同梱——dispatch.md §並列実行の規律）。
- 分解文書（タスク一覧+依存グラフ+並列計画）をCodexレビュー: 文書レビュー形(3a)で
  「`team-plan-reviewer` スキルを読み従え」を名指しして依頼（合格ライン=P2まで全クリア）。
  **初回ラウンドのみ、plan-probe（下位モデル固定の測定器。正本=`team-plan-probe`スキル）を
  Codexレビューと並走させる**: 分解文書のパスだけを渡し、返ってきた言い換え（変更対象／
  やらないこと／完了条件の判定手順化／迷った箇所）を原文と突き合わせ、
  **ズレ＝曖昧箇所**として初回の指摘反映にまとめて流す。合否には数えない
  （下位モデルが解釈に迷う箇所はworkerも迷う——契約の曖昧さ起因の欠陥の予防線）。
  呼び出しは defaults.yaml `routing.plan-probe`（CC=plan-probeエージェント/haiku）、
  Codex Orchestrator時は `codex_routing.plan-probe`（luna/low、`team-plan-probe`スキル名指し）。
  1ラウンド = 指摘反映→再レビュー。上限 `limits.fix_rounds_plan`（既定3）。
  再レビューはresume形(3c)で同一セッションに継続し、プロトコル§8bの二点評価
  （前回指摘への対処／修正で新たに入った問題）を行わせる。加えて各指摘に**由来ラベル**
  （「前回の修正が生んだ」／「以前から在って今回気づいた」）を付けさせる——
  **修正起因が過半なら、直すほど不整合が増えている信号**＝ラウンドを重ねず分解の粒度・方向を見直す。
  **上限超過＝分解の方向性自体に無理がある兆候**。それ以上ループせず、残っている指摘を
  まず3分類する: (i)文書内の矛盾・抜け＝文書レビューで決着可能
  (ii)実装しないと分からない（依存・DB型・既存関数の実挙動）＝**スパイクで確かめる**（[2]参照）
  (iii)上流の設計選択・ドメイン妥当性＝**gpt-consultで外部相談**。
  (ii)(iii)は文書レビューを何ラウンド重ねても出てこない（実測: 9ラウンドで実装後・外部レビュー
  発見の9件はどれも出なかった——同じ読者が同じ文書を読み直しても新しい情報は入らない）。
  分類とこちらの見解・選択肢（分解のやり直し / 指摘を承知で進める / スコープ縮小 /
  スパイク実施 / gpt-consult相談）をAskUserQuestionで確認し、判断をミッションファイルに記録する。
- 人間承認: AskUserQuestionで分解と並列計画を提示し承認を得る。
- ☑ 全契約のAllowed pathsが相互に非交差、または交差分は直列化されている

### [3.5] executor委譲（**自分がFableのときだけ**発動・Claude側の運用）
**Codex が Orchestrator のときはこの工程は発動せず、常に直接実行モード。**
この工程はCC（Claude）がOrchestratorのときの規定。**自分のモデルを環境情報ブロック
（`You are powered by the model named ...`）で確認し、条件分岐する**——
グローバルCLAUDE.md第2層（フル・オーケストレーションはFableのときだけ発動）と同じ原則。

- **自分がFableの場合**: [3]の人間承認後、**[4]〜[6]は自分で実行せず、
  executorサブエージェントに委譲する**（以下の手順）。
- **自分がFable以外（Opus等）の場合**: **委譲しない**。[4]〜[6]を自分で実行する
  （下記「直接実行モード」）。executorはOpusなので、Opus自身が指揮する場面で委譲しても
  単価も判断品質も変わらず、往復とコンテキスト再構築のオーバーヘッドだけが増える。

- 起動: Agentツールで `routing.executor`（既定: general-purpose / opus / effort high）を
  バックグラウンド起動。渡すもの:
  1. ミッションID・ミッションファイルと分解文書（骨子）のパス
  2. 「`~/.agents/skills/agent-team/references/dispatch.md` と `defaults.yaml` を読み、
     その手順で[4]〜[6]を実行せよ」という指示
  3. エスカレーション条件（下記）と報告形式
- executorの職務: 骨子→契約清書（GENERAL_TEMPLATE準拠で `queue/tasks/T-xxx.md` 作成）
  → dispatch → レビュー（**二重ゲート**: 独立Codexレビューを発注＋executor自身の
  契約適合・品質確認。dispatch.md「読者について」参照）
  → resume差し戻しループ → 完了ゲート実行 → ミッションファイル記帳 → 完了報告。
- executorはミッションファイル・queue/への**書き込み権を委任される**（禁則の例外。
  STATE.mdの縮約は[7]でOrchestratorが行う）。
- executorができないこと（Orchestratorに戻す）: サブエージェント起動（孫は不可。
  cc-worker行きタスクはOrchestratorが自らAgentツールでdispatchする）、
  破壊的git操作の判断、人間への質問。
- エスカレーション（executorが停止して報告する条件）: 同一タスクで実装者切替2回 /
  設計の穴・仕様変更が必要と判明 / usage limit。Orchestratorが判断し、
  **SendMessageで同一executorに追加指示**して継続（文脈保持）。
**直接実行モード**（自分がFable以外のとき／executor起動不能時／タスク1件の極小ミッション）:
[4]〜[6]を以下の記述どおり自分で実行する。二重ゲートのゲート2は
**reviewerサブエージェント(opus)**が担い（executor自己審査より独立性が高い）、
ゲート1の独立Codexレビューと完了ゲートのcc-chore委譲はそのまま使える。
契約清書も自分で行う（骨子止めはexecutorへ渡す場合の作法）。

### [4] Dispatch
- `references/dispatch.md` の手順で並列グループ単位に起動:
  - codex系worker → codex-protocol.md 実装形(3d)をバックグラウンド起動
  - cc-worker → Agentツールで coding-agent
- dispatchはevent駆動: タスク完了は「新たにdispatch可能になったタスクはないか」を即再判定するトリガー。バッチ完了を待たない。
- ☑ 全タスクがdispatch済み、または依存待ちとしてミッションファイルに記録済み

### [5] レビュー（タスク完了ごとに即実施）
- Codex実装分 → reviewerサブエージェント(opus)に契約と差分を渡す
  （新規コンテキスト・作者情報は伏せる）。契約違反(Allowed paths外の変更)は即FIX。
- coding-agent実装分 → 文書レビュー形(3a)で `team-code-reviewer` スキルを名指しし、
  契約＋対象パス範囲を渡してCodexレビュー（詳細はdispatch.md）。
- FIX → 同一セッションへ差し戻し（codex系=resume形(3c＋sandbox指定)、
  cc系=SendMessage）。上限 `limits.fix_rounds_task` ラウンド。
  差し戻し指示は**症状や方法ではなく満たすべき性質で書く**（「XXを使え」「先に実行しろ」ではなく
  「〜が失われないこと」「〜の前提を壊さないこと」）。方法を指定するとその方法の穴が
  そのまま実装される（実測: 修正指示が別の欠陥を生む連鎖5回。M-001）。
- 上限超過 → エスカレーション判定（dispatch.md §エスカレーション）: 再割当/再分解/cc-worker切替。
  同一workerセッションで上限+1ラウンド目に入らない（沼の強制切断）。
- **workerの最終報告を `queue/reports/T-xxx.md` に保存してからレビューに入る**
  （自己申告の後日検証を可能にする。M-011/M-012 では報告未保存のため
  「変異テスト実施済み」申告の真偽が事後検証不能だった）。
- テストを含むタスクは、契約の変異リストから**Orchestrator（またはexecutor）が
  抜き取りで1〜2件を自分で実施**し、workerの証跡と突き合わせる
  （worker申告の変異スモークを鵜呑みにしない。手順は test-policy 付録——
  `pass` 置換で当てる・落ちたテスト名まで確認・復元して `git status` クリーン確認。
  **他タスク並走中の判定方法は dispatch.md §並列実行の規律**——全体suiteでなく
  対象テストファイルの単体実行で前後比較する）。
- 合格 → **Orchestratorが** `git add <そのタスクのAllowed paths> && git commit -m "T-xxx: <summary>"`
  でtask commitを代行（Codexはsandboxでcommit不可）。**集約ファイルへの登録**
  （testリスト等。dispatch.md §並列実行の規律）**があればこのcommitに同梱する**。
- ☑ 全タスクに合格記録が `queue/reviews/` にあり、報告が `queue/reports/` に保存され、task commitが済んでいる

### [6] 完了ゲート（全タスクdone後、統合後HEADで）
- (a) 未コミット変更ゼロ（`git status`）
- (b) team.yaml `verify.post_change` 実行 → green
- (c) team.yaml `verify.smoke` 実行 → green
- (d) **変異スモーク抜き取り**（テストを書いたミッションのみ）: 各契約の変異リストから
  未実施分を中心に数件を統合後HEADで実施し、対応テストが落ちること（変異→落ちたテスト名）を
  確認して復元する。[5]で実施済みの分は再実施不要。証跡をミッションファイルに記録する。
- (b)(c)の実行はcc-choreエージェント(haiku/xhigh)へ委譲してよい（dispatch.md §雑務の委譲。
  exit code＋失敗時の末尾抜粋を証拠として要求）。lint/テストの大量出力をOrchestratorのコンテキストに直接浴びない。Codex workerには委譲しない
  （プロトコル§10: Codexのtest実行主張は完了ゲートの証拠にならない）。
- 失敗 → 原因タスクを特定して[5]の差し戻しへ。ゲートを緩めて通さない。
- ☑ (a)〜(c)＋該当時(d)の通過ログをミッションファイルに記録した

### [7] 受入・報告
- Acceptanceと証拠（reports/reviews/実挙動）を突き合わせる。
  フロントエンドはBrowserペイン/previewで実描画を確認する。
- diffの直読は**全量ではなく抜き取り検査**とする: レビュー合格（reviewer/executor審査）を
  前提に、Acceptanceに直結する箇所だけ抽出して確認する（二重の全量読みは
  品質向上に寄与が薄く、Orchestrator価格のトークンを消費するだけ）。
- 人間へ完了報告。PR希望時はミッション単位で1つ作成。
- 縮約（state-layer.md）: ミッションをSTATE.mdで1行の完了記録にし（**Logは1行厳守**）、
  ミッションファイルを `missions/closed/` へ移動。**縮約が済むまで完了報告を終わりにしない**。
- 教訓・罠は memory-ops の「記録の入口」に従う: 初出は `INBOX.md` に1行、同主題の再発は回数+1、
  回数3で昇格、人間の明示指示は `[人間指示 日付]` で直行。**MEMORY.md に直接追記しない。**
- `bash ~/.agents/skills/memory-ops/scripts/check-size.sh` を実行し、閾値超過があれば
  memory-ops の該当サブコマンドを実施してから状態をコミット。
- ☑ STATE.mdが「次のセッションが読めば分かる」状態で、かつ check-size.sh が閾値内を報告している

### [8] closeout（worktree/ブランチ後片付け・git-ops準拠）
- ミッションで作った worker worktree（Codex=`C:\tmp`、CCサブエージェント=`.claude/worktrees`）と、
  マージ済みの作業ブランチ（`team/M-xxx` 等）を closeout する。手順の正本は `git-ops` スキル（§2.5 / §3）。
- **未処理の worktree/ブランチを残したままミッションを「完了」にしない。** ロック等で消せないものは、
  保持理由と次の削除条件をミッションファイルに記録する（放置＝完了と扱わない）。
- 一括棚卸しは `bash ~/.agents/skills/git-ops/scripts/git-hygiene.sh`（ドライラン既定）で確認してよい。
- ☑ ミッション由来の worktree/ブランチが closeout 済み（or 保持理由を記録）

## init手順（/agent-team init）

1. ディレクトリ作成: `.agents/config` `.agents/state/missions/closed` `.agents/backlog`
   `.agents/queue/tasks` `.agents/queue/reports` `.agents/queue/reviews` `.agents/queue/research`
2. `references/templates/init/` の各ファイルを配置:
   STATE.md, MEMORY.md, INBOX.md → `.agents/state/`、BACKLOG.md → `.agents/backlog/`、
   team.yaml → `.agents/config/`
3. verifyコマンドの確定: プロジェクトのlint/型チェック/テスト/起動確認コマンドを
   ユーザーに確認し、team.yamlの `verify.post_change` / `verify.smoke` に記入する。
   未確定のまま放置しない（完了ゲートが機能しなくなる）。
4. AGENTS.md: 無ければ `init/AGENTS-section.md` を元に作成。有れば同内容の
   「Team Worker Rules」節を追記（Codexワーカーはこれをネイティブに読む）。
   この節は**グローバルスキルへのポインタ最小限**に保つ。ルール本文をプロジェクトへ
   複製しない（正本は `~/.agents/skills/team-*` と本スキル。更新の1発反映を守るため）。
5. CLAUDE.md: 無ければ `@AGENTS.md` 1行のimportで作成（symlinkは使わない=Windows対応）。
6. `.gitignore` に `.agents/tmp/` を追記。`.agents/` 本体はコミット対象
   （状態の永続化がB案の生命線）。
7. **敷設内容は既定ブランチ（main等）上でコミットし、リモートがあれば即push**する。
   initをミッションブランチやフィーチャーブランチの上で行わない——`.agents/` は
   インフラであり、特定ミッションの成果物に混ぜると、マージまで他セッションから
   見えず「未敷設」誤診の原因になる（実例: PR #101に敷設一式が同乗した）。
   フィーチャーブランチ上でinitを求められたら、既定ブランチへの切替（または
   敷設コミットだけ既定ブランチへ入れる段取り）を先に人間へ提案する。

## resume手順（/agent-team resume）

0. `bash ~/.agents/skills/memory-ops/scripts/check-size.sh` で行数を測る。閾値超過があれば
   **引き継ぎ作業に入る前に** memory-ops の該当サブコマンドを実施する（提案ではなく実施）。
1. STATE.mdを読み、activeなミッションを特定。複数あれば人間にどれを引き継ぐか確認。
2. 対象ミッションファイルの `Active session` 欄を確認 — 他セッションが記載されていれば
   二重運転の危険を人間に警告して停止。
3. 自セッションを `Active session` に記載し、ミッションファイルのTasks表・Logから
   現在地を再構築して工程の途中から続行。
4. dispatch済みで未回収のcodexセッションは、reportファイルとsession idから状態を確認する
   （codex-protocol.md §11: 非対話セッションの履歴とresume）。

## 禁則

- 完了ゲート・クロスレビューの省略（expressを含む）。
- workerへのgovernanceパス（`.agents/`, `AGENTS.md`, `CLAUDE.md`, `~/.claude/`配下）の変更許可。
- 契約なしのdispatch。散文プロンプトだけでcodex execに実装させない。
- `--dangerously-bypass-approvals-and-sandbox` 等、codex-protocol.md禁止フラグの使用。
- STATE.md/ミッションファイルへのworker・サブエージェントによる書き込み
  （書けるのはOrchestratorと、委任を受けたexecutor（[3.5]）だけ。
  workerの成果物はqueue/へ。STATE.mdの縮約はOrchestrator専任）。

## 詳細リファレンス

| ファイル | いつ読むか |
| --- | --- |
| `references/dispatch.md` | [3]ルーティング判定と[4][5]のdispatch・レビュー・差し戻しの実施時 |
| `references/express.md` | S判定となった依頼の実施時 |
| `references/state-layer.md` | init時・status・resume・[0][1][7]の状態操作時 |
| `~/.agents/skills/memory-ops/SKILL.md` | check-size.sh が閾値超過を報告したとき・教訓の書き先に迷ったとき・[7]の教訓記録時 |
| `references/templates/` | 契約・ミッションファイル作成時（GENERAL/EXPRESS/MISSION） |
