#!/bin/bash
# 🏯 セッションバックアップスクリプト
# Session Backup Script for multi-agent-shogun
#
# 使用方法:
#   ./scripts/backup_session.sh [--notes "メモ"]

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
NOTES=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --notes)
            NOTES="$2"
            shift 2
            ;;
        -h|--help)
            echo ""
            echo "🏯 セッションバックアップスクリプト"
            echo ""
            echo "使用方法: ./scripts/backup_session.sh [オプション]"
            echo ""
            echo "オプション:"
            echo "  --notes \"メモ\"  バックアップに付けるメモ"
            echo "  -h, --help       このヘルプを表示"
            echo ""
            echo "例:"
            echo "  ./scripts/backup_session.sh"
            echo "  ./scripts/backup_session.sh --notes \"スキル化候補3件あり\""
            echo ""
            exit 0
            ;;
        *)
            log_error "不明なオプション: $1"
            echo "./scripts/backup_session.sh -h でヘルプを表示"
            exit 1
            ;;
    esac
done

# ═══════════════════════════════════════════════════════════════════════════════
# バックアップディレクトリ作成
# ═══════════════════════════════════════════════════════════════════════════════
TIMESTAMP=$(date "+%Y-%m-%d-%H%M%S")
BACKUP_DIR="$PROJECT_DIR/backups/sessions/$TIMESTAMP"

log_info "📦 バックアップを作成中: $TIMESTAMP"

mkdir -p "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR/ashigaru_logs"

# ═══════════════════════════════════════════════════════════════════════════════
# dashboard.md のコピー
# ═══════════════════════════════════════════════════════════════════════════════
if [ -f "./dashboard.md" ]; then
    cp ./dashboard.md "$BACKUP_DIR/dashboard.md"
    log_info "  └─ dashboard.md をコピー"
else
    log_error "  └─ dashboard.md が見つかりません"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 足軽ログの取得（tmux が起動中の場合のみ）
# ═══════════════════════════════════════════════════════════════════════════════
if tmux has-session -t multiagent 2>/dev/null; then
    log_info "  └─ 足軽ログを取得中..."
    for i in {1..8}; do
        tmux capture-pane -t "multiagent:$i" -p -S -10000 > "$BACKUP_DIR/ashigaru_logs/ashigaru${i}.log" 2>/dev/null || echo "[ログ取得失敗]" > "$BACKUP_DIR/ashigaru_logs/ashigaru${i}.log"
    done
    log_info "     └─ 足軽ログ取得完了（8名分）"
else
    log_info "  └─ multiagent セッションが起動していません（ログスキップ）"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# metadata.yaml の生成
# ═══════════════════════════════════════════════════════════════════════════════
cat > "$BACKUP_DIR/metadata.yaml" << EOF
timestamp: "$TIMESTAMP"
created_at: "$(date "+%Y-%m-%d %H:%M:%S")"
notes: "$NOTES"
files:
  dashboard: dashboard.md
  ashigaru_logs: ashigaru_logs/
backup_type: auto
EOF

log_info "  └─ メタデータ生成完了"

# ═══════════════════════════════════════════════════════════════════════════════
# latest シンボリックリンク更新
# ═══════════════════════════════════════════════════════════════════════════════
LATEST_LINK="$PROJECT_DIR/backups/latest"
rm -f "$LATEST_LINK"
ln -s "sessions/$TIMESTAMP" "$LATEST_LINK"

log_success "✅ バックアップ完了: $BACKUP_DIR"
log_info "   └─ latest リンク更新: backups/latest -> sessions/$TIMESTAMP"

echo ""
echo "  バックアップ内容:"
echo "  ┌──────────────────────────────────────────┐"
echo "  │  📄 dashboard.md                         │"
echo "  │  📋 ashigaru_logs/ (足軽ログ×8)          │"
echo "  │  📝 metadata.yaml                        │"
echo "  └──────────────────────────────────────────┘"
echo ""
