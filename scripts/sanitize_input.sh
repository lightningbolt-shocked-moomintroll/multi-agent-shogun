#!/bin/bash
# ============================================================
# sanitize_input.sh - 入力サニタイズユーティリティ
# ============================================================
# tmux send-keys に渡す入力を安全にサニタイズする関数群
#
# 使用方法:
#   source scripts/sanitize_input.sh
#   sanitized=$(sanitize_for_tmux "ユーザー入力")
# ============================================================

# 色定義
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ============================================================
# 危険なパターンの定義
# ============================================================

# コマンドインジェクションに使われる可能性のある文字/パターン
DANGEROUS_PATTERNS=(
    '`'           # バッククォート（コマンド置換）
    '$('          # コマンド置換
    '${'          # 変数展開
    '|'           # パイプ
    ';'           # コマンド連結
    '&&'          # AND連結
    '||'          # OR連結
    '>'           # リダイレクト
    '<'           # 入力リダイレクト
    '\n'          # 改行
    '\r'          # キャリッジリターン
)

# ============================================================
# サニタイズ関数
# ============================================================

# tmux send-keys 用にエスケープ
# シングルクォート内で安全に使用できるようにする
sanitize_for_tmux() {
    local input="$1"
    local sanitized="$input"

    # 1. シングルクォートをエスケープ（' → '\''）
    sanitized="${sanitized//\'/\'\\\'\'}"

    # 2. バッククォートを削除または無効化
    sanitized="${sanitized//\`/}"

    # 3. $( を無効化（コマンド置換防止）
    sanitized="${sanitized//\$\(/\\\$\(}"

    # 4. ${ を無効化（変数展開防止）
    sanitized="${sanitized//\$\{/\\\$\{}"

    # 5. 制御文字を削除
    # 改行、キャリッジリターン、タブ以外の制御文字を削除
    sanitized=$(echo "$sanitized" | tr -d '\000-\010\013-\037')

    echo "$sanitized"
}

# より厳格なサニタイズ（コマンド実行の可能性を完全に排除）
sanitize_strict() {
    local input="$1"
    local sanitized="$input"

    # 1. 許可する文字のみ残す（英数字、日本語、基本的な記号）
    # 注: 日本語を保持するため、LC_ALL=C は使用しない

    # 2. 危険なパターンを削除
    sanitized="${sanitized//\`/}"      # バッククォート
    sanitized="${sanitized//\$\(/}"    # コマンド置換
    sanitized="${sanitized//\$\{/}"    # 変数展開
    sanitized="${sanitized//|/}"       # パイプ
    sanitized="${sanitized//;/}"       # セミコロン
    sanitized="${sanitized//&&/}"      # AND
    sanitized="${sanitized//||/}"      # OR（文字列としての || を削除）
    sanitized="${sanitized//>/}"       # リダイレクト
    sanitized="${sanitized//</}"       # 入力リダイレクト

    # 3. シングルクォートをエスケープ
    sanitized="${sanitized//\'/\'\\\'\'}"

    # 4. 制御文字を削除
    sanitized=$(echo "$sanitized" | tr -d '\000-\010\013-\037')

    echo "$sanitized"
}

# 入力の検証（危険なパターンが含まれているかチェック）
validate_input() {
    local input="$1"
    local has_danger=false
    local warnings=()

    # バッククォートチェック
    if [[ "$input" == *'`'* ]]; then
        has_danger=true
        warnings+=("バッククォート (\`) が含まれています")
    fi

    # コマンド置換チェック
    if [[ "$input" == *'$('* ]]; then
        has_danger=true
        warnings+=("コマンド置換 (\$()) が含まれています")
    fi

    # 変数展開チェック
    if [[ "$input" == *'${'* ]]; then
        has_danger=true
        warnings+=("変数展開 (\${}) が含まれています")
    fi

    # パイプチェック
    if [[ "$input" == *'|'* ]]; then
        has_danger=true
        warnings+=("パイプ (|) が含まれています")
    fi

    # セミコロンチェック
    if [[ "$input" == *';'* ]]; then
        has_danger=true
        warnings+=("セミコロン (;) が含まれています")
    fi

    # 結果を出力
    if [ "$has_danger" = true ]; then
        echo "DANGEROUS"
        for warning in "${warnings[@]}"; do
            echo "  - $warning" >&2
        done
        return 1
    else
        echo "SAFE"
        return 0
    fi
}

# YAMLファイルパスの検証
validate_yaml_path() {
    local path="$1"

    # 許可されたディレクトリパターン
    local allowed_patterns=(
        "^queue/.*\.yaml$"
        "^config/.*\.yaml$"
        "^status/.*\.yaml$"
    )

    for pattern in "${allowed_patterns[@]}"; do
        if [[ "$path" =~ $pattern ]]; then
            echo "VALID"
            return 0
        fi
    done

    echo "INVALID"
    return 1
}

# ============================================================
# ヘルパー関数
# ============================================================

# 安全なログ出力（サニタイズ済み）
safe_log() {
    local message="$1"
    local sanitized=$(sanitize_for_tmux "$message")
    echo "[LOG] $sanitized"
}

# 危険な入力の警告表示
warn_dangerous_input() {
    local input="$1"
    echo -e "${RED}[SECURITY WARNING]${NC} 危険な入力パターンを検出しました" >&2
    echo -e "${YELLOW}入力内容:${NC} ${input:0:50}..." >&2
    validate_input "$input" >/dev/null
}

# ============================================================
# エクスポート（source時に利用可能にする）
# ============================================================

export -f sanitize_for_tmux
export -f sanitize_strict
export -f validate_input
export -f validate_yaml_path
export -f safe_log
export -f warn_dangerous_input
