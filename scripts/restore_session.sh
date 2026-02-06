#!/bin/bash
# 🏯 セッション復元スクリプト
# Session Restore Script for multi-agent-shogun
#
# 使用方法:
#   ./scripts/restore_session.sh [バックアップディレクトリ]
#   ./scripts/restore_session.sh                    # インタラクティブモード
#   ./scripts/restore_session.sh latest            # 最新バックアップから復元
#   ./scripts/restore_session.sh 2026-02-05-110132 # 指定バックアップから復元

set -e

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

# 色付きログ関数
log_info() {
    echo -e "\033[1;33m【報】\033[0m $1"
}

log_success() {
    echo -e "\033[1;32m【成】\033[0m $1"
}

log_error() {
    echo -e "\033[1;31m【警】\033[0m $1"
}

# ═══════════════════════════════════════════════════════════════════════════════
# バックアップ一覧表示
# ═══════════════════════════════════════════════════════════════════════════════
show_backup_list() {
    echo ""
    echo "  ┌────────────────────────────────────────────────────────────────────────┐"
    echo "  │  📦 バックアップ一覧 (Session Backups)                                  │"
    echo "  └────────────────────────────────────────────────────────────────────────┘"
    echo ""

    if [ ! -d "./backups/sessions" ] || [ -z "$(ls -A ./backups/sessions 2>/dev/null)" ]; then
        echo "  バックアップが存在しません"
        echo ""
        return 1
    fi

    # テーブルヘッダー
    printf "  %-3s  %-20s  %-30s\n" "No" "タイムスタンプ" "メモ"
    echo "  ────────────────────────────────────────────────────────────────────────"

    # バックアップを新しい順にリスト
    local counter=1
    while IFS= read -r backup_dir; do
        local backup_name=$(basename "$backup_dir")

        # metadata.yaml からメモを取得
        local notes=""
        if [ -f "$backup_dir/metadata.yaml" ]; then
            notes=$(grep "^notes:" "$backup_dir/metadata.yaml" | sed 's/notes: *"\(.*\)"/\1/' | sed 's/notes: *//')
            [ "$notes" = '""' ] && notes=""
        fi

        # latest リンクのマーク
        local latest_mark=""
        if [ -L "./backups/latest" ]; then
            local latest_target=$(readlink "./backups/latest")
            if [ "sessions/$backup_name" = "$latest_target" ]; then
                latest_mark=" ★"
            fi
        fi

        printf "  %-3s  %-20s  %-30s\n" "$counter" "$backup_name$latest_mark" "$notes"

        # 配列に保存（後で選択時に使用）
        BACKUP_DIRS[$counter]="$backup_name"
        counter=$((counter + 1))
    done < <(ls -1dt ./backups/sessions/*)

    echo ""
    echo "  ★ = 最新バックアップ (latest)"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# 復元実行
# ═══════════════════════════════════════════════════════════════════════════════
restore_backup() {
    local backup_name="$1"
    local backup_dir="./backups/sessions/$backup_name"

    if [ ! -d "$backup_dir" ]; then
        log_error "バックアップが見つかりません: $backup_name"
        return 1
    fi

    log_info "📦 バックアップから復元中: $backup_name"

    # dashboard.md を復元
    if [ -f "$backup_dir/dashboard.md" ]; then
        cp "$backup_dir/dashboard.md" ./dashboard.md
        log_info "  └─ dashboard.md 復元完了"
    else
        log_error "  └─ dashboard.md が見つかりません"
        return 1
    fi

    # メタデータ表示
    if [ -f "$backup_dir/metadata.yaml" ]; then
        local created_at=$(grep "^created_at:" "$backup_dir/metadata.yaml" | sed 's/created_at: *"\(.*\)"/\1/' | sed 's/created_at: *//')
        local notes=$(grep "^notes:" "$backup_dir/metadata.yaml" | sed 's/notes: *"\(.*\)"/\1/' | sed 's/notes: *//')

        log_info "  └─ バックアップ日時: $created_at"
        [ -n "$notes" ] && [ "$notes" != '""' ] && log_info "  └─ メモ: $notes"
    fi

    log_success "✅ 復元完了"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# メイン処理
# ═══════════════════════════════════════════════════════════════════════════════

# 引数がある場合は直接復元
if [ $# -ge 1 ]; then
    if [ "$1" = "latest" ]; then
        # latest から実際のディレクトリ名を取得
        if [ -L "./backups/latest" ]; then
            LATEST_TARGET=$(readlink "./backups/latest")
            BACKUP_NAME=$(basename "$LATEST_TARGET")
            restore_backup "$BACKUP_NAME"
        else
            log_error "latest バックアップが見つかりません"
            exit 1
        fi
    else
        restore_backup "$1"
    fi
    exit $?
fi

# インタラクティブモード
declare -A BACKUP_DIRS

if ! show_backup_list; then
    exit 1
fi

echo "  復元するバックアップを選択してください:"
echo "  ┌──────────────────────────────────────────┐"
echo "  │  1-N) バックアップ番号を入力             │"
echo "  │  q)   キャンセル                        │"
echo "  └──────────────────────────────────────────┘"
echo ""
read -p "  選択: " choice

case "$choice" in
    q|Q)
        echo ""
        log_info "キャンセルしました"
        exit 0
        ;;
    [0-9]|[0-9][0-9])
        if [ -n "${BACKUP_DIRS[$choice]}" ]; then
            echo ""
            restore_backup "${BACKUP_DIRS[$choice]}"
        else
            log_error "無効な選択です: $choice"
            exit 1
        fi
        ;;
    *)
        log_error "無効な入力です: $choice"
        exit 1
        ;;
esac
