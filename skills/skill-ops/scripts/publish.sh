#!/usr/bin/env bash
# publish.sh — ~/.agents（GitHub: Itsuki-Ueda/Skill-Library の clone）の変更を GitHub へ公開する。
# skill-ops スキルの正本ツール。手順を1コマンドに固定し、gh アカウントの戻し忘れを構造的に防ぐ。
#
# 使い方:
#   bash ~/.agents/skills/skill-ops/scripts/publish.sh "<type>: <日本語で変更内容>"
#   bash ~/.agents/skills/skill-ops/scripts/publish.sh --dry-run   # 何がコミット・push されるか表示のみ
#   bash ~/.agents/skills/skill-ops/scripts/publish.sh --status    # 同期状態の表示のみ
#
# 自動でやること:
#   - author（local 設定）が Itsuki-Ueda であることの確認
#   - core.hooksPath=.githooks の確認と自動設定（clone 直後の初期化を兼ねる）
#   - gh のアクティブアカウントを Itsuki-Ueda へ切替 → 終了時（異常終了・中断含む）に必ず元へ復帰
#   - 秘密ファイル（.env / *.pem / *.key）の混入チェック
#   - 非公開情報の全文検査（publish-guard.sh。public repo のため。ヒットしたら中断）
#   - commit（pre-commit が .codex-plugin/plugin.json の version を自動更新）
#   - git fetch → 必要なら pull --rebase → push → 同期確認
set -euo pipefail

REPO="$HOME/.agents"
EXPECTED_REMOTE="Itsuki-Ueda/Skill-Library"
EXPECTED_NAME="Itsuki-Ueda"
EXPECTED_EMAIL="73779819+Itsuki-Ueda@users.noreply.github.com"
PUBLISH_ACCOUNT="Itsuki-Ueda"
BRANCH="main"

die() { echo "エラー: $*" >&2; exit 1; }
info() { echo "$*"; }

MODE="publish"
MESSAGE=""
for a in "$@"; do
  case "$a" in
    --dry-run) MODE="dry-run" ;;
    --status)  MODE="status" ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    --*) die "不明なオプション: $a" ;;
    *)
      [ -n "$MESSAGE" ] && die "コミットメッセージは1つだけ指定してください（全体を \" \" で囲む）"
      MESSAGE="$a"
      ;;
  esac
done

# ---- 事前チェック ----
[ -d "$REPO/.git" ] || die "$REPO は git リポジトリではありません（clone されていない可能性があります）"

remote_url="$(git -C "$REPO" remote get-url origin 2>/dev/null || true)"
case "$remote_url" in
  *"$EXPECTED_REMOTE"*) : ;;
  "") die "$REPO に remote origin がありません" ;;
  *) die "remote origin が想定外です: $remote_url（期待: $EXPECTED_REMOTE）" ;;
esac

cfg_name="$(git -C "$REPO" config user.name || true)"
cfg_email="$(git -C "$REPO" config user.email || true)"
if [ "$cfg_name" != "$EXPECTED_NAME" ] || [ "$cfg_email" != "$EXPECTED_EMAIL" ]; then
  echo "エラー: このリポジトリの実効 author が想定と違います。" >&2
  echo "  現在: ${cfg_name:-(未設定)} <${cfg_email:-(未設定)}>" >&2
  echo "  期待: $EXPECTED_NAME <$EXPECTED_EMAIL>" >&2
  echo "  対処: git-setup スキル §1-1（author の設定）を参照し、この repo に local 設定してください。" >&2
  echo "        グローバル設定は変更しないこと（既定は仕事用）。" >&2
  exit 1
fi

cur_branch="$(git -C "$REPO" rev-parse --abbrev-ref HEAD)"
[ "$cur_branch" = "$BRANCH" ] || die "現在のブランチが $cur_branch です。$BRANCH で作業してください（この repo は main 直編集が正）。"

hooks_path="$(git -C "$REPO" config core.hooksPath || true)"
if [ "$hooks_path" != ".githooks" ]; then
  git -C "$REPO" config core.hooksPath .githooks
  info "初期化: core.hooksPath を .githooks に設定しました（pre-commit の Codex version 自動更新が有効になります）。"
fi

# ---- gh アカウント切替（trap で必ず復帰）----
# public repo だが push には Itsuki-Ueda の credential が要る。
# 既定の active は仕事用のため、ここで切り替えて終了時に必ず戻す。
ORIGINAL_ACCOUNT="$(gh auth status --active 2>/dev/null | sed -n 's/.*Logged in to github.com account \([^ ]*\).*/\1/p' | head -1 || true)"
SWITCHED=0
restore_account() {
  if [ "$SWITCHED" = "1" ] && [ -n "$ORIGINAL_ACCOUNT" ]; then
    if gh auth switch --user "$ORIGINAL_ACCOUNT" >/dev/null 2>&1; then
      echo "gh アカウントを $ORIGINAL_ACCOUNT に戻しました。"
    else
      echo "警告: gh アカウントを $ORIGINAL_ACCOUNT に戻せませんでした。手動で 'gh auth switch --user $ORIGINAL_ACCOUNT' を実行してください。" >&2
    fi
  fi
}
trap restore_account EXIT INT TERM

if [ -z "$ORIGINAL_ACCOUNT" ]; then
  info "警告: gh のアクティブアカウントを判定できませんでした（gh 未ログイン？）。切替せずに続行します。"
elif [ "$ORIGINAL_ACCOUNT" = "$PUBLISH_ACCOUNT" ]; then
  info "gh アクティブアカウントは既に $PUBLISH_ACCOUNT です（切替不要）。"
else
  gh auth switch --user "$PUBLISH_ACCOUNT" >/dev/null 2>&1 \
    || die "gh auth switch --user $PUBLISH_ACCOUNT に失敗しました（$PUBLISH_ACCOUNT で gh auth login 済みか確認してください）"
  SWITCHED=1
  info "gh アクティブアカウントを $ORIGINAL_ACCOUNT → $PUBLISH_ACCOUNT に切り替えました（終了時に自動で戻します）。"
fi

# ---- 現状の把握 ----
git -C "$REPO" fetch origin --quiet 2>/dev/null \
  || info "警告: git fetch に失敗しました（ネットワーク不通の可能性）。以降の同期判定は古い情報です。"

dirty="$(git -C "$REPO" status --porcelain -uall)"
ahead="$(git -C "$REPO" rev-list --count "origin/$BRANCH..HEAD" 2>/dev/null || echo 0)"
behind="$(git -C "$REPO" rev-list --count "HEAD..origin/$BRANCH" 2>/dev/null || echo 0)"

show_state() {
  echo "対象リポジトリ: $REPO"
  echo "ブランチ: $cur_branch / author: $cfg_name <$cfg_email>"
  echo "origin との差: ahead=$ahead behind=$behind"
  if [ -n "$dirty" ]; then
    echo "未コミットの差分:"
    echo "$dirty" | sed 's/^/  /'
  else
    echo "未コミットの差分: なし"
  fi
  if [ "$ahead" -gt 0 ]; then
    echo "未 push のコミット:"
    git -C "$REPO" log --oneline "origin/$BRANCH..HEAD" | sed 's/^/  /'
  else
    echo "未 push のコミット: なし"
  fi
}

if [ "$MODE" = "status" ]; then
  show_state
  if [ -z "$dirty" ] && [ "$ahead" -eq 0 ] && [ "$behind" -eq 0 ]; then
    echo "→ 同期済み（GitHub と一致）"
  else
    echo "→ 未同期。publish.sh \"<メッセージ>\" で公開してください。"
  fi
  exit 0
fi

# ---- 秘密ファイルの混入チェック ----
secrets="$(git -C "$REPO" status --porcelain -uall | cut -c4- \
  | grep -Ei '(^|/)\.env(\.|$)|\.pem$|\.key$' || true)"
if [ -n "$secrets" ]; then
  echo "エラー: 秘密情報らしきファイルが変更対象に含まれています。コミットを中止します。" >&2
  echo "$secrets" | sed 's/^/  /' >&2
  exit 1
fi

# ---- 非公開情報の全文検査（public repo）----
bash "$REPO/skills/skill-ops/scripts/publish-guard.sh" || die "非公開情報の疑いがあるため公開を中止しました（上の一覧を修正してください）"

if [ "$MODE" = "dry-run" ]; then
  show_state
  echo "--- dry-run: 実際のコミット・push は行いません ---"
  if [ -n "$dirty" ]; then
    echo "コミット予定メッセージ: ${MESSAGE:-(未指定 — 本番実行時は必須)}"
  fi
  exit 0
fi

# ---- 本番 ----
if [ -n "$dirty" ] && [ -z "$MESSAGE" ]; then
  echo "エラー: コミットメッセージが指定されていません。" >&2
  echo '  例: bash ~/.agents/skills/skill-ops/scripts/publish.sh "feat(skill-ops): 公開手順を追加"' >&2
  exit 1
fi

if [ -z "$dirty" ] && [ "$ahead" -eq 0 ] && [ "$behind" -eq 0 ]; then
  echo "同期済み: 変更も未 push コミットもありません。何もしません。"
  exit 0
fi

if [ -n "$dirty" ]; then
  git -C "$REPO" add -A
  git -C "$REPO" commit -m "$MESSAGE"
else
  info "未コミットの差分はありません。commit をスキップします。"
fi

# ---- 取り込み（別マシンからの更新を想定）----
git -C "$REPO" fetch origin --quiet
behind="$(git -C "$REPO" rev-list --count "HEAD..origin/$BRANCH" 2>/dev/null || echo 0)"
if [ "$behind" -gt 0 ]; then
  info "origin/$BRANCH に $behind 件の未取り込みコミットがあります。rebase して取り込みます。"
  if ! git -C "$REPO" pull --rebase origin "$BRANCH"; then
    git -C "$REPO" rebase --abort >/dev/null 2>&1 || true
    echo "エラー: rebase で競合が発生したため中断しました（作業ツリーは rebase 前に戻しています）。" >&2
    echo "  対処: git -C $REPO pull --rebase origin $BRANCH を手動で実行し、競合を解決してから再度 publish してください。" >&2
    exit 1
  fi
fi

# ---- push ----
git -C "$REPO" push origin "$BRANCH"

# ---- 同期確認 ----
git -C "$REPO" fetch origin --quiet
sb="$(git -C "$REPO" status -sb | head -1)"
echo "$sb"
if [ "$sb" != "## $BRANCH...origin/$BRANCH" ]; then
  die "push 後も origin と同期していません: $sb"
fi
sha="$(git -C "$REPO" rev-parse --short HEAD)"
subject="$(git -C "$REPO" log -1 --pretty=%s)"
echo "公開完了: $sha $subject"
