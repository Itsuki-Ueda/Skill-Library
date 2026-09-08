---
name: agent-team
description: Codexでagent-teamを実行するためのラッパー。「/agent-team」「チームで開発」「分解して並列で」「ミッション」「Codex部隊に」「複数モジュールにまたがる開発」、init/status/resumeで共通本体と併読する。
---

# agent-team — Codex実行経路

共通本体 `~/.agents/skills/agent-team/SKILL.md` を読む。共通本体が直接ロードされた場合も本書を使う。
実行時に必要なdispatch/express/state-layerだけを読む。native起動にCLIプロトコル全量は不要。

## 設定・起動
- `~/.agents/skills/agent-team/references/defaults.yaml` のcodex_routingを、プロジェクトteam.yamlのcodex_routingで項目単位に上書きする。limitsも同様。未知キーは無視する。
- `agent:` は名前指定のcustom agentをspawnする。model/effortは `~/.agents/codex/agents/` のtomlが正本。yamlのmodel/effortで上書きしない。
- `cc:` はCCゲートウェイへ解決済みyamlのmodel/effortを渡す。別経路のroutingへ暗黙フォールバックしない。経路未定義は親へ返す。
- 事前定義を使い、毎dispatchの設定照合・人間確認は行わない。設定変更時に対応経路と定義を確認する。黙ったagent代替は禁止（`~/.agents/codex/AGENTS.md`）。
- nativeは同じagentへ追加入力して継続する。CCゲートウェイは新規呼び出しなので契約・前回記録・前回版からの差分を同梱する。
- 入れ子の `codex exec` は使わない。executor/cc-choreへ委譲せず、親が進行管理・完了ゲート・commitを担当する。

## 担当
| 対象 | codex_routingの担当 |
| --- | --- |
| 通常/express実装 | worker / express |
| 難度・環境レーン | hard-worker / cc-worker |
| 調査 | research |
| 親の計画 | plan-review（team-plan-reviewer）＋初回plan-probe |
| native worker実装 | review（team-code-reviewer） |
| CCゲートウェイ実装 | codex-review（team-code-reviewer） |
| expressレビュー | 親のdiff直読だけ。同一ベンダーでも正規の合格条件 |

役割スキルの正本パスと契約/対象版を明記する。非交差タスクだけ並列spawnし、完了通知・waitで回収する。
レビューの版・再確認・証拠は `~/.agents/skills/agent-team/references/dispatch.md` に従う。

## CCゲートウェイ・権限
- 使用するときだけ `~/.agents/codex/skills/autodev/references/claude-code-bridge.md` を読む。認証・起動コマンド・禁止事項はそこが正本。
- UTF-8（BOMなし）プロンプト作成、ゲートウェイ単独実行、一時ファイル削除を別tool callにする。
- ゲートウェイへ直接実行以外の認証方式で迂回しない。秘密情報・不要な個人情報を送らない。
- Gitの権限制約は `~/.agents/codex/skills/git-ops/SKILL.md` に従う。許可された承認付き実行を使い、拒否を迂回しない。
- Windowsのgit `ref:path` はPowerShellで全体を引用する。

## 利用不可
生のエラーを確認してから判断する。hard-worker/cc-workerを量産workerへ黙って落とさず、BLOCKEDとして親から報告する。
review/plan-reviewのCC経路が利用不可ならnative reviewerによる補助レビューは可能だが、別ベンダー未達をBlockersへ残し、共通dispatchの回復待ち/例外受入を適用する。
native researchが利用不可なら親が権限内の読み取り調査を引き取る。未実行を調査済みとしない。

## 記録・報告
Active sessionには実際のセッションIDを記す。成果物保存は親が行う。
報告は使用した担当、ゲートウェイ結果、レビュー達成/例外、完了ゲートの実行証拠を簡潔に示す。
expressにはクロスベンダー未達警告を出さない。
