---
name: git-ops
description: Git運用のCodex固有設定。正本 ~/.agents/skills/git-ops/SKILL.md を読んだ上で、sandbox・承認付き外部実行・GitHub操作・一時worktree置き場を定義する。Git操作前に正本と併せて読む。
---

# git-ops — Codex ハーネス固有設定

**正本 `~/.agents/skills/git-ops/SKILL.md` を最初に読み、全項目に従うこと。**
このファイルは Codex 固有の動作のみを定義し、正本 §1.5 を埋める。
グローバル `AGENTS.md` の「## PR Review Worktrees」とも矛盾しない（あちらはレビュー用worktreeの扱い、正本はPR/worktree全般のライフサイクル）。

## 実行能力

- 通常実行はsandbox内。作業ファイルを書けても `.git` とネットワークが制限される場合がある。
- ユーザーの依頼範囲内で対象が明確なら、`require_escalated` により同じコマンドの承認付き外部実行を申請できる。拒否時は迂回しない。
- `cannot lock ref`、`index.lock`、`Permission denied` は破損と断定せず、権限制約を確認して必要なら承認付きで再実行する。
- 一時/自動生成worktreeは `C:\tmp\...`・`~/.codex/worktrees/`、自動生成ブランチは `codex/<名>`。

## GitHub操作

ユーザーがpush・PR・mergeを明示依頼した場合、次の順で進める。

1. `git remote get-url origin` と `gh repo view --json nameWithOwner,visibility,url,defaultBranchRef` で送信先を照合する。
2. sandbox内の `gh auth status` が失敗したら、再ログインを案内する前に承認付きで再確認する。
3. HEAD・stage対象・base/headを確認し、push、PR、CI確認、squash mergeを各コマンド単位で承認申請する。
4. MERGEDを確認してから、最新`main`への更新と正本 §3 のcloseoutを完了する。

GitHub設定変更や複数ブランチの一括削除は通常のPR依頼から推定せず、別途明示承認を得る。

## 委譲と棚卸し

- 非対話のClaude Code `coding-agent` はpush承認に応答できない場合がある。事前承認済みの専用経路が確認できない限り、リモートGit操作の委譲先にしない。
- 一時worktreeだけを正本 §3 に従って削除する。ユーザー保有worktreeは削除しない。
- 過去・複数・所有者不明の棚卸しは正本の `git-hygiene.sh` を使う。`--remote` は承認付き外部実行が可能な場合だけ使う。
