#!/bin/bash
# 🏯 バックアップ一覧表示スクリプト
# List Backups Script for multi-agent-shogun

set -e

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

# 色付きログ関数
log_info() {
    echo -e "\033[1;33m【報】\033[0m $1"
}

# ═══════════════════════════════════════════════════════════════════════════════
# バックアップ一覧表示
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "  ┌────────────────────────────────────────────────────────────────────────┐"
echo "  │  📦 バックアップ一覧 (Session Backups)                                  │"
echo "  └────────────────────────────────────────────────────────────────────────┘"
echo ""

if [ ! -d "./backups/sessions" ] || [ -z "$(ls -A ./backups/sessions 2>/dev/null)" ]; then
    echo "  バックアップが存在しません"
    echo ""
    exit 0
fi

# テーブルヘッダー
printf "  %-3s  %-20s  %-30s\n" "No" "タイムスタンプ" "メモ"
echo "  ────────────────────────────────────────────────────────────────────────"

# バックアップを新しい順にリスト
counter=1
while IFS= read -r backup_dir; do
    backup_name=$(basename "$backup_dir")

    # metadata.yaml からメモを取得
    notes=""
    if [ -f "$backup_dir/metadata.yaml" ]; then
        notes=$(grep "^notes:" "$backup_dir/metadata.yaml" | sed 's/notes: *"\(.*\)"/\1/' | sed 's/notes: *//')
        [ "$notes" = '""' ] && notes=""
    fi

    # latest リンクのマーク
    latest_mark=""
    if [ -L "./backups/latest" ]; then
        latest_target=$(readlink "./backups/latest")
        if [ "sessions/$backup_name" = "$latest_target" ]; then
            latest_mark=" ★"
        fi
    fi

    printf "  %-3s  %-20s  %-30s\n" "$counter" "$backup_name$latest_mark" "$notes"
    counter=$((counter + 1))
done < <(ls -1dt ./backups/sessions/*)

echo ""
echo "  ★ = 最新バックアップ (latest)"
echo ""
