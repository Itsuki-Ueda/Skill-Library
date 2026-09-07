---
name: handoff
description: ClaudeとCodexの間でタスクを受け渡すハンドオフ・プロトコルを運用する。設計→実装→レビューの往復をリポジトリ内 .handoff/ の連番Markdown文書で進め、Codexへの指示文をクリップボードに自動投入する。`/handoff new|design|review|status|init`。「Codexで実装」「Codexに渡して」「設計をCodexに」「ハンドオフ」などで使う。
---

# handoff — Claude ↔ Codex ハンドオフ運用スキル

ClaudeとCodexがコードリポジトリ内 `.handoff/<タスクID>/` の連番Markdown文書でタスクを受け渡す。
あなた（Claude）はこのスキルで、設計・レビューの成果物を文書化し、Codexへの指示文をクリップボードに載せる。
仕様の正本: `G:\マイドライブ\04_Obsidian\Vault-GDrive\11_開発\Claude-Codexのやり取り\PROTOCOL.md`（以下「母艦」）。

## 不変条件（必ず守る）
- **ターン制**: 一度に動くのは1工程だけ。Codexの番の作業を先回りしない。
- **承認ゲート**: 設計・レビューは必ず**先に人間へ提示して承認を得てから**、ハンドオフ文書を確定し、
  Codexへの指示文をクリップボードに載せる。承認前にクリップボード投入しない。
- **連番**: ファイルは `.handoff/<タスクID>/<2桁連番>-<phase>.<agent>.md`。連番は00から通し、フロントマターの `seq` と一致させる。

## 共通: リポジトリと連番の解決
1. **リポジトリルート**: `git rev-parse --show-toplevel` で取得。gitでなければ現在の作業ディレクトリ。
2. **タスクの解決**: 引数でタスクIDが与えられればそれ。なければ `.handoff/` 配下で**最終更新が最も新しいタスクフォルダ**を対象にする。曖昧なら `/handoff status` の結果を見せて確認する。
3. **次の連番**: 対象フォルダ内の既存 `NN-*.md` の最大番号 +1。ゼロ詰め2桁（`01`,`02`,…）。
4. **日時**: タスクIDの日付と `created` はシステム日付（`Get-Date`）から。タスクID = `<YYYY-MM-DD>-<スラッグ>`。

## フロントマター雛形
```yaml
---
task: <タスクID>
seq: <連番>
from: <claude|codex|human>
to: <claude|codex>
phase: <request|design|implement|review|fix|question|done>
status: <ready|done|blocked>
gate: <pending|approved|changes-requested>
created: <ISO8601>
---
```

---

## サブコマンド

引数の第1語をサブコマンドとして分岐する: `init` / `new` / `design` / `review` / `status` / （無引数 or `help`）。

### `init`
そのリポジトリにハンドオフの足場を用意する（初回のみ・冪等）。
1. リポジトリルートを解決。
2. `.handoff/` を作成（既存なら何もしない）。
3. `AGENTS.md`:
   - 既存で文字列「Claude↔Codex ハンドオフ規約」を**含むなら何もしない**。
   - 含まないなら、母艦の `templates\AGENTS.section.md` の内容を**末尾に追記**。
   - `AGENTS.md` が無ければ、その内容で新規作成。
4. `CLAUDE.md` が無ければ `@AGENTS.md を参照してください。` の1行で作成（既存なら触らない）。
5. 作成・更新したファイルを報告し、「次は `/handoff new <スラッグ> <依頼>`」と案内。

### `new <スラッグ> <依頼内容...>`
新しいタスクを開始する。
1. タスクID = `<今日(YYYY-MM-DD)>-<スラッグ>`（スラッグ未指定なら依頼から短い英数スラッグを生成、無理なら `task`）。
2. `.handoff/<タスクID>/` を作成。
3. `00-request.md` を作成。フロントマター: `from: human` / `to: claude` / `phase: request` / `status: ready` / `gate: approved` / `seq: 0`。本文に依頼内容をそのまま記載し、分かる範囲で「背景 / 完了条件」を補う。
4. タスクIDを報告し、「次は `/handoff design`」と案内。

### `design [タスクID]`  ← ゲート①
Claudeが設計し、承認後にCodexへ渡す。**二段**で進める。
1. 対象タスクを解決し、`00-request.md`（と関連コード）を読んで依頼を理解する。
2. 設計を行い、**チャットに提示**する（構成・方針・対象ファイル・完了条件・やらないこと・残論点）。
   この時点では**まだ文書を書かない**。「この設計でCodexに実装させてよいですか？」と承認を求めてターンを終える。
3. **ユーザーが承認したら**（修正要望があれば直して再提示）、次の連番で `NN-design.claude.md` を書く:
   `from: claude` / `to: codex` / `phase: design` / `status: ready` / `gate: approved`。本文は提示した設計。
4. **Codexへの指示文をクリップボードに投入**（下記「クリップボード投入」）。実装報告の想定ファイル名は `<NN+1>-impl.codex.md`。
5. 「クリップボードにCodexへの指示を入れました。Codexに切り替えて1回ペーストしてください。実装が終わったら `/handoff review`」と案内。

### `review [タスクID]`  ← ゲート②
Codexの報告とコード差分をレビューする。**二段**で進める。
1. 対象タスクの最新の `*.codex.md`（`NN-impl.codex.md` / `NN-fix.codex.md`）を読む。
2. **実際のコード変更を必ず確認**する（`git diff` や対象ファイルのRead）。報告と実体の差を見る。
3. レビュー結果を**チャットに提示**: 良い点 / 問題点（重大度付き） / 必須修正 / 任意改善 / 判定（done か 要修正か）。文書はまだ書かない。承認を求めてターンを終える。
4. **ユーザーが承認したら**、次の連番で `NN-review.claude.md` を書く（`from: claude` / `to: codex` / `phase: review`）。
   - **要修正**なら `gate: changes-requested`。本文に修正指示。**Codexへの修正指示文をクリップボードへ**（報告想定 `<NN+1>-fix.codex.md`）。
   - **done**なら `phase: done` / `status: done` / `gate: approved` の文書を書き、タスク完了を報告（クリップボード投入なし）。

### `status [タスクID]`
1. タスクID指定あり: そのフォルダの全 `NN-*.md` を連番順に列挙。最新文書の `to:` から「今は誰の番か」、`gate:` から承認状態を示す。
2. 指定なし: `.handoff/` 配下の全タスクフォルダについて、最新 phase・誰の番か・gate を1行ずつ一覧。

### 無引数 / `help`
サブコマンド一覧と典型フロー（`init → new → design →（Codexペースト）→ review → …`）を短く示し、続けて `/handoff status` 相当の現状を表示する。

---

## クリップボード投入（Codexへの「1ペースト」）
PowerShellツールで `Set-Clipboard` を実行する。プレースホルダ（`<TASKID>` `<NN>` `<NN+1>`）は実値に置換する。

**設計 → 実装**:
```
Set-Clipboard -Value @'
.handoff/<TASKID>/<NN>-design.claude.md を読んで、その設計に従って実装してください。
完了したら .handoff/<TASKID>/<NN+1>-impl.codex.md に、AGENTS.md のハンドオフ規約のフロントマター付きで
報告（実装サマリ / 変更ファイル一覧 / テスト結果 / 残課題・確認事項）を書いてください。
対象範囲・完了条件・やらないことは設計文書に従い、範囲外のファイルは触らないこと。書いたら止まってください。
'@
```

**レビュー → 修正**:
```
Set-Clipboard -Value @'
.handoff/<TASKID>/<NN>-review.claude.md を読んで、指摘に従って修正してください。
完了したら .handoff/<TASKID>/<NN+1>-fix.codex.md に規約のフロントマター付きで報告を書いてください。
範囲外は触らず、書いたら止まってください。
'@
```

投入後は、クリップボードに入れた指示文の全文をチャットにも表示し（手動コピーのフォールバック）、ペーストを促す。
