#!/usr/bin/env bash
# Codex クラウドのキャッシュ再開後に実行する更新・配置確認。
#
# Setup が作成した Skill-Library、~/.agents、~/.codex と、Secret から生成済みの
# ~/.config/claude-subscription/oauth-token を確認する。Secret が Setup 後に消える
# 前提なので、認証ファイルは再生成せず、無ければ Setup の再実行を要求して失敗する。

set -euo pipefail
set +x

setup_script="${HOME}/.agents/cloud/codex-setup.sh"
[ -f "$setup_script" ] || {
  printf 'codex cloud maintenance: Setup 済みの ~/.agents/cloud/codex-setup.sh が見つかりません\n' >&2
  exit 1
}

exec bash "$setup_script" --maintenance
