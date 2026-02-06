#!/bin/bash
# ============================================================
# safe_send_keys.sh - 安全な tmux send-keys ラッパー
# ============================================================
# tmux send-keys を安全に実行するためのラッパースクリプト
# 入力をサニタイズしてからtmuxに渡す
#
# 使用方法:
#   ./scripts/safe_send_keys.sh <target_pane> <message>
#   ./scripts/safe_send_keys.sh multiagent:0 "任務完了でござる"
#
# オプション:
#   --strict    厳格モード（より多くの文字を除去）
#   --no-enter  Enterキーを送信しない
#   --validate  検証のみ（実行しない）
#   --help      ヘルプを表示
# ============================================================

set -e

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# サニタイズ関数を読み込み
source "$SCRIPT_DIR/sanitize_input.sh"

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# デフォルト設定
STRICT_MODE=false
SEND_ENTER=true
VALIDATE_ONLY=false
VERBOSE=false

# ログ関数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# ヘルプ表示
show_help() {
    cat << 'EOF'
🔐 safe_send_keys.sh - 安全な tmux send-keys ラッパー

使用方法:
  ./scripts/safe_send_keys.sh [オプション] <target_pane> <message>

引数:
  target_pane   送信先のtmuxペイン (例: multiagent:0, shogun)
  message       送信するメッセージ

オプション:
  --strict      厳格モード（より多くの特殊文字を除去）
  --no-enter    メッセージ送信後にEnterを送らない
  --validate    検証のみ実行（tmuxには送信しない）
  --verbose     詳細出力
  --help, -h    このヘルプを表示

例:
  # 通常の使用
  ./scripts/safe_send_keys.sh multiagent:0 "任務完了でござる"

  # 厳格モードで送信
  ./scripts/safe_send_keys.sh --strict multiagent:1 "報告書を確認せよ"

  # 検証のみ
  ./scripts/safe_send_keys.sh --validate shogun "テスト入力"

セキュリティ:
  このスクリプトは以下の危険なパターンを除去/エスケープします:
  - コマンド置換: `command`, $(command)
  - 変数展開: ${variable}
  - パイプ・リダイレクト: |, >, <
  - コマンド連結: ;, &&, ||
  - 制御文字

EOF
}

# 引数解析
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --strict)
                STRICT_MODE=true
                shift
                ;;
            --no-enter)
                SEND_ENTER=false
                shift
                ;;
            --validate)
                VALIDATE_ONLY=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            -*)
                log_error "不明なオプション: $1"
                show_help
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done

    # 残りの引数を取得
    if [ $# -lt 2 ]; then
        log_error "引数が不足しています"
        echo "使用方法: $0 [オプション] <target_pane> <message>"
        exit 1
    fi

    TARGET_PANE="$1"
    MESSAGE="$2"
}

# ターゲットペインの検証
validate_target_pane() {
    local pane="$1"

    # 許可されたペインパターン
    local allowed_patterns=(
        "^shogun(:[0-9]+\.[0-9]+)?$"
        "^multiagent:[0-9]+$"           # ウィンドウ番号のみ (例: multiagent:0, multiagent:1-8)
        "^multiagent:[0-9]+\.[0-9]+$"   # ペイン分割 (例: multiagent:0.0)
        "^multiagent$"
    )

    for pattern in "${allowed_patterns[@]}"; do
        if [[ "$pane" =~ $pattern ]]; then
            return 0
        fi
    done

    log_error "無効なターゲットペイン: $pane"
    log_error "許可されるペイン: shogun, multiagent:0-8 (ウィンドウ), multiagent:0.0-0.8 (ペイン)"
    return 1
}

# メイン処理
main() {
    parse_args "$@"

    # ターゲットペインを検証
    if ! validate_target_pane "$TARGET_PANE"; then
        exit 1
    fi

    # 入力を検証
    local validation_result
    validation_result=$(validate_input "$MESSAGE")

    if [ "$validation_result" = "DANGEROUS" ]; then
        log_warn "危険なパターンが検出されました。サニタイズを実行します。"
    fi

    # サニタイズ実行
    local sanitized_message
    if [ "$STRICT_MODE" = true ]; then
        sanitized_message=$(sanitize_strict "$MESSAGE")
        [ "$VERBOSE" = true ] && log_info "厳格モードでサニタイズしました"
    else
        sanitized_message=$(sanitize_for_tmux "$MESSAGE")
    fi

    # 変更があったか確認
    if [ "$MESSAGE" != "$sanitized_message" ]; then
        log_warn "入力がサニタイズされました"
        if [ "$VERBOSE" = true ]; then
            log_info "元の入力: ${MESSAGE:0:50}..."
            log_info "サニタイズ後: ${sanitized_message:0:50}..."
        fi
    fi

    # 検証のみモードの場合はここで終了
    if [ "$VALIDATE_ONLY" = true ]; then
        log_info "検証モード: 実際の送信はスキップされました"
        log_info "ターゲット: $TARGET_PANE"
        log_info "メッセージ: $sanitized_message"
        exit 0
    fi

    # tmuxセッションの存在確認
    local session_name
    session_name=$(echo "$TARGET_PANE" | cut -d: -f1)
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        log_error "tmuxセッション '$session_name' が存在しません"
        exit 1
    fi

    # tmux send-keys を実行（2回に分けて）
    if [ "$VERBOSE" = true ]; then
        log_info "送信先: $TARGET_PANE"
        log_info "メッセージ: $sanitized_message"
    fi

    # メッセージを送信（シングルクォートで囲む）
    tmux send-keys -t "$TARGET_PANE" "$sanitized_message"

    # Enterを送信
    if [ "$SEND_ENTER" = true ]; then
        tmux send-keys -t "$TARGET_PANE" Enter
    fi

    [ "$VERBOSE" = true ] && log_success "送信完了"
}

# スクリプトとして実行された場合
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
