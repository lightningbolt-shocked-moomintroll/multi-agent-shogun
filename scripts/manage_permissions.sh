#!/bin/bash
# ============================================================
# manage_permissions.sh - multi-agent-shogun 権限管理スクリプト
# ============================================================
# 使用方法:
#   ./scripts/manage_permissions.sh           # 対話モード
#   ./scripts/manage_permissions.sh --list    # 現在の権限一覧
#   ./scripts/manage_permissions.sh --reset   # デフォルトにリセット
#   ./scripts/manage_permissions.sh --add-allow "Bash(npm:*)"
#   ./scripts/manage_permissions.sh --add-deny "Bash(rm -rf:*)"
# ============================================================

set -e

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS_FILE="$SCRIPT_DIR/.claude/settings.json"

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# ログ関数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# jq がインストールされているか確認
check_jq() {
    if ! command -v jq &> /dev/null; then
        log_error "jq がインストールされていません"
        echo ""
        echo "インストール方法:"
        echo "  Ubuntu/Debian: sudo apt-get install jq"
        echo "  macOS:         brew install jq"
        exit 1
    fi
}

# 設定ファイルが存在するか確認
check_settings() {
    if [ ! -f "$SETTINGS_FILE" ]; then
        log_warn "設定ファイルが見つかりません: $SETTINGS_FILE"
        read -p "デフォルト設定を作成しますか? [Y/n]: " REPLY
        REPLY=${REPLY:-Y}
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            create_default_settings
        else
            exit 1
        fi
    fi
}

# デフォルト設定を作成
create_default_settings() {
    mkdir -p "$(dirname "$SETTINGS_FILE")"
    cat > "$SETTINGS_FILE" << 'EOF'
{
  "permissions": {
    "allow": [
      "Bash(date:*)",
      "Bash(pwd)",
      "Bash(ls:*)",
      "Bash(cat:*)",
      "Bash(head:*)",
      "Bash(tail:*)",
      "Bash(wc:*)",
      "Bash(tmux send-keys:*)",
      "Bash(tmux capture-pane:*)",
      "Bash(tmux display-message:*)",
      "Bash(tmux list-sessions)",
      "Bash(tmux list-panes:*)",
      "Bash(mkdir -p:*)",
      "Bash(echo:*)",
      "Read(*)",
      "Write(queue/*)",
      "Write(status/*)",
      "Write(config/*)",
      "Write(dashboard.md)",
      "Write(memory/*)",
      "Edit(queue/*)",
      "Edit(status/*)",
      "Edit(config/*)",
      "Edit(dashboard.md)"
    ],
    "deny": [
      "Bash(rm -rf /*)",
      "Bash(rm -rf ~/*)",
      "Bash(chmod 777:*)",
      "Bash(sudo:*)",
      "Bash(su:*)",
      "Write(~/.ssh/*)",
      "Write(~/.aws/*)",
      "Write(~/.config/*)",
      "Read(~/.ssh/*)",
      "Read(~/.aws/*)"
    ]
  },
  "_comment": {
    "description": "multi-agent-shogun 権限設定",
    "version": "1.0.0"
  }
}
EOF
    log_success "デフォルト設定を作成しました: $SETTINGS_FILE"
}

# 現在の権限を表示
list_permissions() {
    check_jq
    check_settings

    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║  🔐 multi-agent-shogun 権限設定                              ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${GREEN}✅ 許可された操作 (自動承認):${NC}"
    echo "─────────────────────────────────────────────────────────────"
    jq -r '.permissions.allow[]' "$SETTINGS_FILE" 2>/dev/null | while read -r line; do
        echo "  • $line"
    done

    echo ""
    echo -e "${RED}❌ 拒否された操作 (常にブロック):${NC}"
    echo "─────────────────────────────────────────────────────────────"
    jq -r '.permissions.deny[]' "$SETTINGS_FILE" 2>/dev/null | while read -r line; do
        echo "  • $line"
    done

    echo ""
    echo -e "${YELLOW}⚠️  上記以外の操作: ユーザーに確認を求めます${NC}"
    echo ""
}

# 許可ルールを追加
add_allow() {
    check_jq
    check_settings

    local pattern="$1"
    if [ -z "$pattern" ]; then
        log_error "パターンを指定してください"
        exit 1
    fi

    # 既存の設定を読み込み、新しいルールを追加
    local temp_file=$(mktemp)
    jq --arg pat "$pattern" '.permissions.allow += [$pat] | .permissions.allow |= unique' "$SETTINGS_FILE" > "$temp_file"
    mv "$temp_file" "$SETTINGS_FILE"

    log_success "許可ルールを追加しました: $pattern"
}

# 拒否ルールを追加
add_deny() {
    check_jq
    check_settings

    local pattern="$1"
    if [ -z "$pattern" ]; then
        log_error "パターンを指定してください"
        exit 1
    fi

    local temp_file=$(mktemp)
    jq --arg pat "$pattern" '.permissions.deny += [$pat] | .permissions.deny |= unique' "$SETTINGS_FILE" > "$temp_file"
    mv "$temp_file" "$SETTINGS_FILE"

    log_success "拒否ルールを追加しました: $pattern"
}

# ルールを削除
remove_rule() {
    check_jq
    check_settings

    local rule_type="$1"
    local pattern="$2"

    if [ -z "$pattern" ]; then
        log_error "パターンを指定してください"
        exit 1
    fi

    local temp_file=$(mktemp)
    if [ "$rule_type" = "allow" ]; then
        jq --arg pat "$pattern" '.permissions.allow -= [$pat]' "$SETTINGS_FILE" > "$temp_file"
    else
        jq --arg pat "$pattern" '.permissions.deny -= [$pat]' "$SETTINGS_FILE" > "$temp_file"
    fi
    mv "$temp_file" "$SETTINGS_FILE"

    log_success "ルールを削除しました: $pattern"
}

# 設定をリセット
reset_settings() {
    read -p "本当にデフォルト設定にリセットしますか? [y/N]: " REPLY
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        create_default_settings
    else
        log_info "キャンセルしました"
    fi
}

# ディレクトリ制限の表示
show_directory_restrictions() {
    check_jq
    check_settings

    echo ""
    echo -e "${BOLD}📂 ディレクトリアクセス制限${NC}"
    echo "─────────────────────────────────────────────────────────────"

    local enabled
    enabled=$(jq -r '.directoryRestrictions.enabled // false' "$SETTINGS_FILE" 2>/dev/null)

    if [ "$enabled" = "true" ]; then
        echo -e "${GREEN}状態: 有効${NC}"
    else
        echo -e "${YELLOW}状態: 無効${NC}"
    fi

    echo ""
    echo -e "${GREEN}許可されたディレクトリ:${NC}"
    jq -r '.directoryRestrictions.allowedDirectories[]? // empty' "$SETTINGS_FILE" 2>/dev/null | while read -r dir; do
        echo "  ✅ $dir/"
    done

    echo ""
    echo -e "${GREEN}許可されたルートファイル:${NC}"
    jq -r '.directoryRestrictions.allowedFiles[]? // empty' "$SETTINGS_FILE" 2>/dev/null | while read -r file; do
        echo "  ✅ $file"
    done

    echo ""
    echo -e "${YELLOW}外部アクセス許可パターン:${NC}"
    local patterns
    patterns=$(jq -r '.directoryRestrictions.externalAccess.allowedPatterns[]? // empty' "$SETTINGS_FILE" 2>/dev/null)
    if [ -z "$patterns" ]; then
        echo "  (なし)"
    else
        echo "$patterns" | while read -r pattern; do
            echo "  🔗 $pattern"
        done
    fi
}

# ディレクトリ制限の有効/無効切り替え
toggle_directory_restrictions() {
    check_jq
    check_settings

    local current
    current=$(jq -r '.directoryRestrictions.enabled // false' "$SETTINGS_FILE" 2>/dev/null)

    local new_value
    if [ "$current" = "true" ]; then
        new_value="false"
        log_warn "ディレクトリ制限を無効化します"
    else
        new_value="true"
        log_success "ディレクトリ制限を有効化します"
    fi

    local temp_file=$(mktemp)
    jq --argjson val "$new_value" '.directoryRestrictions.enabled = $val' "$SETTINGS_FILE" > "$temp_file"
    mv "$temp_file" "$SETTINGS_FILE"
}

# 許可ディレクトリを追加
add_allowed_directory() {
    check_jq
    check_settings

    local dir="$1"
    if [ -z "$dir" ]; then
        log_error "ディレクトリ名を指定してください"
        return 1
    fi

    # 末尾のスラッシュを除去
    dir="${dir%/}"

    local temp_file=$(mktemp)
    jq --arg d "$dir" '.directoryRestrictions.allowedDirectories += [$d] | .directoryRestrictions.allowedDirectories |= unique' "$SETTINGS_FILE" > "$temp_file"
    mv "$temp_file" "$SETTINGS_FILE"

    log_success "許可ディレクトリを追加: $dir/"
}

# 外部プロジェクトパターンを追加
add_external_pattern() {
    check_jq
    check_settings

    local pattern="$1"
    if [ -z "$pattern" ]; then
        log_error "パターンを指定してください"
        return 1
    fi

    local temp_file=$(mktemp)
    jq --arg p "$pattern" '.directoryRestrictions.externalAccess.allowedPatterns += [$p] | .directoryRestrictions.externalAccess.allowedPatterns |= unique' "$SETTINGS_FILE" > "$temp_file"
    mv "$temp_file" "$SETTINGS_FILE"

    log_success "外部アクセスパターンを追加: $pattern"
}

# 対話モード
interactive_mode() {
    check_jq
    check_settings

    while true; do
        echo ""
        echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}║  🔐 multi-agent-shogun 権限管理                              ║${NC}"
        echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "  1) 現在の権限を表示"
        echo "  2) 許可ルールを追加"
        echo "  3) 拒否ルールを追加"
        echo "  4) ルールを削除"
        echo "  5) デフォルトにリセット"
        echo "  6) よく使う許可パターンを追加"
        echo "  ─────────────────────────────"
        echo "  7) ディレクトリ制限を表示"
        echo "  8) ディレクトリ制限の有効/無効切り替え"
        echo "  9) 許可ディレクトリを追加"
        echo "  0) 外部プロジェクトへのアクセスを許可"
        echo "  q) 終了"
        echo ""
        read -p "選択 [0-9/q]: " choice

        case $choice in
            1)
                list_permissions
                ;;
            2)
                echo ""
                echo "許可パターンの例:"
                echo "  Bash(npm:*)       - npm コマンド全般"
                echo "  Bash(git:*)       - git コマンド全般"
                echo "  Write(src/*)      - src/ 以下への書き込み"
                echo "  Read(*)           - すべてのファイル読み込み"
                echo ""
                read -p "許可パターン: " pattern
                if [ -n "$pattern" ]; then
                    add_allow "$pattern"
                fi
                ;;
            3)
                echo ""
                echo "拒否パターンの例:"
                echo "  Bash(rm -rf:*)    - 再帰的削除"
                echo "  Bash(sudo:*)      - sudo コマンド"
                echo "  Write(~/.ssh/*)   - SSH鍵への書き込み"
                echo ""
                read -p "拒否パターン: " pattern
                if [ -n "$pattern" ]; then
                    add_deny "$pattern"
                fi
                ;;
            4)
                echo ""
                echo "削除するルールのタイプ:"
                echo "  1) 許可ルール"
                echo "  2) 拒否ルール"
                read -p "選択 [1-2]: " rule_type
                read -p "削除するパターン: " pattern
                if [ "$rule_type" = "1" ] && [ -n "$pattern" ]; then
                    remove_rule "allow" "$pattern"
                elif [ "$rule_type" = "2" ] && [ -n "$pattern" ]; then
                    remove_rule "deny" "$pattern"
                fi
                ;;
            5)
                reset_settings
                ;;
            6)
                echo ""
                echo "よく使う許可パターン:"
                echo "  1) 開発用 (npm, git, node, python)"
                echo "  2) ファイル操作 (Write/Edit to src/, docs/)"
                echo "  3) Docker 操作"
                echo "  4) すべて追加"
                read -p "選択 [1-4]: " preset

                case $preset in
                    1)
                        add_allow "Bash(npm:*)"
                        add_allow "Bash(npx:*)"
                        add_allow "Bash(node:*)"
                        add_allow "Bash(git:*)"
                        add_allow "Bash(python:*)"
                        add_allow "Bash(python3:*)"
                        add_allow "Bash(pip:*)"
                        add_allow "Bash(pip3:*)"
                        ;;
                    2)
                        add_allow "Write(src/*)"
                        add_allow "Write(docs/*)"
                        add_allow "Write(tests/*)"
                        add_allow "Edit(src/*)"
                        add_allow "Edit(docs/*)"
                        add_allow "Edit(tests/*)"
                        ;;
                    3)
                        add_allow "Bash(docker:*)"
                        add_allow "Bash(docker-compose:*)"
                        ;;
                    4)
                        add_allow "Bash(npm:*)"
                        add_allow "Bash(npx:*)"
                        add_allow "Bash(node:*)"
                        add_allow "Bash(git:*)"
                        add_allow "Bash(python:*)"
                        add_allow "Bash(python3:*)"
                        add_allow "Bash(pip:*)"
                        add_allow "Bash(pip3:*)"
                        add_allow "Write(src/*)"
                        add_allow "Write(docs/*)"
                        add_allow "Write(tests/*)"
                        add_allow "Edit(src/*)"
                        add_allow "Edit(docs/*)"
                        add_allow "Edit(tests/*)"
                        add_allow "Bash(docker:*)"
                        add_allow "Bash(docker-compose:*)"
                        ;;
                esac
                ;;
            7)
                show_directory_restrictions
                ;;
            8)
                toggle_directory_restrictions
                ;;
            9)
                echo ""
                echo "プロジェクト内のディレクトリを追加します。"
                echo "例: src, tests, lib"
                echo ""
                read -p "ディレクトリ名: " dir_name
                if [ -n "$dir_name" ]; then
                    add_allowed_directory "$dir_name"
                fi
                ;;
            0)
                echo ""
                echo "外部プロジェクトへのアクセスを許可します。"
                echo ""
                echo "パターン例:"
                echo "  /mnt/c/projects/myapp/*    - 特定プロジェクト"
                echo "  /home/user/work/*          - 作業ディレクトリ"
                echo ""
                read -p "許可パターン: " ext_pattern
                if [ -n "$ext_pattern" ]; then
                    add_external_pattern "$ext_pattern"
                fi
                ;;
            q|Q)
                echo ""
                log_info "終了します"
                exit 0
                ;;
            *)
                log_warn "無効な選択です"
                ;;
        esac
    done
}

# ヘルプ表示
show_help() {
    echo ""
    echo "🔐 multi-agent-shogun 権限管理スクリプト"
    echo ""
    echo "使用方法: ./scripts/manage_permissions.sh [オプション]"
    echo ""
    echo "権限ルール管理:"
    echo "  (なし)              対話モードで起動"
    echo "  --list, -l          現在の権限一覧を表示"
    echo "  --reset             デフォルト設定にリセット"
    echo "  --add-allow PATTERN 許可ルールを追加"
    echo "  --add-deny PATTERN  拒否ルールを追加"
    echo "  --remove-allow PAT  許可ルールを削除"
    echo "  --remove-deny PAT   拒否ルールを削除"
    echo ""
    echo "ディレクトリ制限管理:"
    echo "  --show-dirs         ディレクトリ制限設定を表示"
    echo "  --toggle-dirs       ディレクトリ制限の有効/無効を切り替え"
    echo "  --add-dir DIR       許可ディレクトリを追加"
    echo "  --add-external PAT  外部アクセスパターンを追加"
    echo "  --validate PATH     パスの検証"
    echo ""
    echo "その他:"
    echo "  --help, -h          このヘルプを表示"
    echo ""
    echo "パターン例:"
    echo "  Bash(npm:*)         npm コマンド全般を許可"
    echo "  Bash(git:*)         git コマンド全般を許可"
    echo "  Write(src/*)        src/ 以下への書き込みを許可"
    echo "  Read(*)             すべてのファイル読み込みを許可"
    echo ""
    echo "設定ファイル: .claude/settings.json"
    echo ""
}

# メイン処理
case "${1:-}" in
    --list|-l)
        list_permissions
        ;;
    --reset)
        reset_settings
        ;;
    --add-allow)
        add_allow "$2"
        ;;
    --add-deny)
        add_deny "$2"
        ;;
    --remove-allow)
        remove_rule "allow" "$2"
        ;;
    --remove-deny)
        remove_rule "deny" "$2"
        ;;
    --show-dirs)
        show_directory_restrictions
        ;;
    --toggle-dirs)
        toggle_directory_restrictions
        ;;
    --add-dir)
        add_allowed_directory "$2"
        ;;
    --add-external)
        add_external_pattern "$2"
        ;;
    --validate)
        # パス検証スクリプトを呼び出し
        if [ -f "$SCRIPT_DIR/scripts/validate_path.sh" ]; then
            "$SCRIPT_DIR/scripts/validate_path.sh" "$2" "${3:---read}"
        else
            log_error "validate_path.sh が見つかりません"
            exit 1
        fi
        ;;
    --help|-h)
        show_help
        ;;
    "")
        interactive_mode
        ;;
    *)
        log_error "不明なオプション: $1"
        show_help
        exit 1
        ;;
esac
