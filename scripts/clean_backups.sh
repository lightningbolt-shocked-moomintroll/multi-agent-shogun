#!/bin/bash
# 🏯 バックアップクリーンアップスクリプト
# Backup Cleanup Script for multi-agent-shogun
#
# 使用方法:
#   ./scripts/clean_backups.sh --keep 10          # 最新10件を保持
#   ./scripts/clean_backups.sh --older-than 7     # 7日より古いものを削除

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
# オプション解析
# ═══════════════════════════════════════════════════════════════════════════════
KEEP=""
OLDER_THAN=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --keep)
            KEEP="$2"
            shift 2
            ;;
        --older-than)
            OLDER_THAN="$2"
            shift 2
            ;;
        -h|--help)
            echo ""
            echo "🏯 バックアップクリーンアップスクリプト"
            echo ""
            echo "使用方法: ./scripts/clean_backups.sh [オプション]"
            echo ""
            echo "オプション:"
            echo "  --keep N         最新N件のバックアップを保持（古いものを削除）"
            echo "  --older-than N   N日より古いバックアップを削除"
            echo "  -h, --help       このヘルプを表示"
            echo ""
            echo "例:"
            echo "  ./scripts/clean_backups.sh --keep 10"
            echo "  ./scripts/clean_backups.sh --older-than 7"
            echo ""
            exit 0
            ;;
        *)
            log_error "不明なオプション: $1"
            echo "./scripts/clean_backups.sh -h でヘルプを表示"
            exit 1
            ;;
    esac
done

if [ -z "$KEEP" ] && [ -z "$OLDER_THAN" ]; then
    log_error "オプションが指定されていません"
    echo "./scripts/clean_backups.sh -h でヘルプを表示"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════════
# バックアップ存在確認
# ═══════════════════════════════════════════════════════════════════════════════
if [ ! -d "./backups/sessions" ] || [ -z "$(ls -A ./backups/sessions 2>/dev/null)" ]; then
    log_info "バックアップが存在しません"
    exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════════
# クリーンアップ実行
# ═══════════════════════════════════════════════════════════════════════════════
echo ""

# --keep オプション
if [ -n "$KEEP" ]; then
    log_info "📦 最新 ${KEEP} 件のバックアップを保持します..."

    # バックアップ総数を確認
    TOTAL_COUNT=$(ls -1dt ./backups/sessions/* | wc -l)
    DELETE_COUNT=$((TOTAL_COUNT - KEEP))

    if [ "$DELETE_COUNT" -le 0 ]; then
        log_info "  └─ 削除対象なし（総数: $TOTAL_COUNT）"
    else
        log_info "  └─ 削除対象: $DELETE_COUNT 件（総数: $TOTAL_COUNT）"

        # 削除対象を表示
        ls -1dt ./backups/sessions/* | tail -n "$DELETE_COUNT" | while read -r backup_dir; do
            backup_name=$(basename "$backup_dir")
            log_info "     └─ 削除: $backup_name"
            rm -rf "$backup_dir"
        done

        log_success "✅ クリーンアップ完了"
    fi
fi

# --older-than オプション
if [ -n "$OLDER_THAN" ]; then
    log_info "📦 ${OLDER_THAN} 日より古いバックアップを削除します..."

    # N日前の日時を計算（秒単位）
    CUTOFF_TIME=$(date -d "${OLDER_THAN} days ago" +%s 2>/dev/null || date -v -${OLDER_THAN}d +%s)

    DELETE_COUNT=0

    # 各バックアップを確認
    ls -1dt ./backups/sessions/* | while read -r backup_dir; do
        backup_name=$(basename "$backup_dir")

        # metadata.yaml から作成日時を取得
        if [ -f "$backup_dir/metadata.yaml" ]; then
            created_at=$(grep "^created_at:" "$backup_dir/metadata.yaml" | sed 's/created_at: *"\(.*\)"/\1/' | sed 's/created_at: *//')

            if [ -n "$created_at" ]; then
                # 作成日時を秒単位に変換
                backup_time=$(date -d "$created_at" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$created_at" +%s 2>/dev/null)

                if [ -n "$backup_time" ] && [ "$backup_time" -lt "$CUTOFF_TIME" ]; then
                    log_info "  └─ 削除: $backup_name (作成: $created_at)"
                    rm -rf "$backup_dir"
                    DELETE_COUNT=$((DELETE_COUNT + 1))
                fi
            fi
        fi
    done

    if [ "$DELETE_COUNT" -eq 0 ]; then
        log_info "  └─ 削除対象なし"
    else
        log_success "✅ クリーンアップ完了（削除: $DELETE_COUNT 件）"
    fi
fi

echo ""

# latest リンクの整合性確認
if [ -L "./backups/latest" ]; then
    LATEST_TARGET=$(readlink "./backups/latest")
    if [ ! -d "./backups/$LATEST_TARGET" ]; then
        log_info "🔗 latest リンクの参照先が削除されました。リンクを更新します..."

        # 最新のバックアップを探す
        NEWEST_BACKUP=$(ls -1dt ./backups/sessions/* 2>/dev/null | head -1)

        if [ -n "$NEWEST_BACKUP" ]; then
            NEWEST_NAME=$(basename "$NEWEST_BACKUP")
            rm -f ./backups/latest
            ln -s "sessions/$NEWEST_NAME" ./backups/latest
            log_success "  └─ latest リンク更新: sessions/$NEWEST_NAME"
        else
            rm -f ./backups/latest
            log_info "  └─ バックアップが存在しないため latest リンクを削除"
        fi
    fi
fi

echo ""
