#!/bin/bash
# ============================================================
# validate_path.sh - パス検証ユーティリティ
# ============================================================
# ファイルパスがプロジェクト内の許可されたディレクトリかどうかを検証する
#
# 使用方法:
#   ./scripts/validate_path.sh <path> [--read|--write|--edit]
#   ./scripts/validate_path.sh queue/tasks/ashigaru1.yaml --write
#
# 戻り値:
#   0: 許可
#   1: 拒否
#   2: 確認必要
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
NC='\033[0m'

# ============================================================
# 許可されたディレクトリ・ファイル定義
# ============================================================

# 読み込み許可ディレクトリ（プロジェクトルートからの相対パス）
ALLOWED_READ_DIRS=(
    "queue"
    "status"
    "config"
    "memory"
    "instructions"
    "context"
    "templates"
    "scripts"
    "docs"
    "skills"
    "logs"
    "demo_output"
    ".claude"
)

# 書き込み許可ディレクトリ
ALLOWED_WRITE_DIRS=(
    "queue"
    "status"
    "config"
    "memory"
    "logs"
    "demo_output"
)

# 編集許可ディレクトリ
ALLOWED_EDIT_DIRS=(
    "queue"
    "status"
    "config"
    "memory"
)

# 許可されたルートファイル
ALLOWED_ROOT_FILES=(
    "dashboard.md"
    "CLAUDE.md"
    "README.md"
    "README_ja.md"
    ".gitignore"
)

# 書き込み許可ルートファイル
ALLOWED_WRITE_ROOT_FILES=(
    "dashboard.md"
)

# 絶対に拒否するパターン
DENIED_PATTERNS=(
    "^/"                    # 絶対パス（ルートから）
    "^~"                    # ホームディレクトリ
    "\.\."                  # ディレクトリトラバーサル
    "\.env"                 # 環境変数ファイル
    "credentials"           # 認証情報
    "secrets"               # シークレット
    "\.ssh"                 # SSH鍵
    "\.aws"                 # AWS認証情報
    "\.gnupg"               # GPG鍵
    "\.npmrc"               # npm認証情報
    "\.pypirc"              # PyPI認証情報
    "\.netrc"               # ネットワーク認証情報
    "id_rsa"                # SSH秘密鍵
    "id_ed25519"            # SSH秘密鍵
    "\.pem$"                # 証明書
    "\.key$"                # 秘密鍵
)

# ============================================================
# ヘルパー関数
# ============================================================

log_info() { echo -e "${BLUE}[INFO]${NC} $1" >&2; }
log_success() { echo -e "${GREEN}[ALLOWED]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[CONFIRM]${NC} $1" >&2; }
log_error() { echo -e "${RED}[DENIED]${NC} $1" >&2; }

# パスを正規化（相対パスに変換、..を解決）
normalize_path() {
    local path="$1"

    # 絶対パスをプロジェクト相対パスに変換（可能であれば）
    if [[ "$path" == "$SCRIPT_DIR"/* ]]; then
        path="${path#$SCRIPT_DIR/}"
    fi

    # 先頭の ./ を除去
    path="${path#./}"

    echo "$path"
}

# 拒否パターンに一致するかチェック
check_denied_patterns() {
    local path="$1"

    for pattern in "${DENIED_PATTERNS[@]}"; do
        if [[ "$path" =~ $pattern ]]; then
            return 0  # マッチした（拒否すべき）
        fi
    done

    return 1  # マッチしなかった
}

# ディレクトリが許可リストに含まれるかチェック
is_allowed_directory() {
    local path="$1"
    local operation="$2"  # read, write, edit
    local -n allowed_dirs_ref

    case "$operation" in
        read)
            allowed_dirs_ref=ALLOWED_READ_DIRS
            ;;
        write)
            allowed_dirs_ref=ALLOWED_WRITE_DIRS
            ;;
        edit)
            allowed_dirs_ref=ALLOWED_EDIT_DIRS
            ;;
        *)
            allowed_dirs_ref=ALLOWED_READ_DIRS
            ;;
    esac

    # パスの先頭ディレクトリを取得
    local first_dir="${path%%/*}"

    for dir in "${allowed_dirs_ref[@]}"; do
        if [[ "$first_dir" == "$dir" ]]; then
            return 0
        fi
    done

    return 1
}

# ルートファイルが許可されているかチェック
is_allowed_root_file() {
    local path="$1"
    local operation="$2"
    local -n allowed_files_ref

    # パスにスラッシュがない場合はルートファイル
    if [[ "$path" != *"/"* ]]; then
        case "$operation" in
            write|edit)
                allowed_files_ref=ALLOWED_WRITE_ROOT_FILES
                ;;
            *)
                allowed_files_ref=ALLOWED_ROOT_FILES
                ;;
        esac

        for file in "${allowed_files_ref[@]}"; do
            if [[ "$path" == "$file" ]]; then
                return 0
            fi
        done
    fi

    return 1
}

# ============================================================
# メイン検証関数
# ============================================================

validate_path() {
    local path="$1"
    local operation="${2:-read}"  # デフォルトは読み込み

    # パスを正規化
    local normalized_path
    normalized_path=$(normalize_path "$path")

    # 空のパスは拒否
    if [[ -z "$normalized_path" ]]; then
        log_error "空のパスは許可されません"
        return 1
    fi

    # 拒否パターンをチェック
    if check_denied_patterns "$normalized_path"; then
        log_error "禁止パターンに一致: $normalized_path"
        return 1
    fi

    # 絶対パス（プロジェクト外）をチェック
    if [[ "$normalized_path" == /* ]]; then
        log_error "プロジェクト外の絶対パス: $normalized_path"
        return 1
    fi

    # ルートファイルをチェック
    if is_allowed_root_file "$normalized_path" "$operation"; then
        log_success "許可されたルートファイル: $normalized_path ($operation)"
        return 0
    fi

    # 許可されたディレクトリをチェック
    if is_allowed_directory "$normalized_path" "$operation"; then
        log_success "許可されたディレクトリ: $normalized_path ($operation)"
        return 0
    fi

    # プロジェクト内だが許可リストにない場合は確認必要
    log_warn "確認が必要: $normalized_path ($operation)"
    return 2
}

# ============================================================
# バッチ検証
# ============================================================

validate_paths_batch() {
    local operation="$1"
    shift
    local paths=("$@")
    local all_allowed=true
    local results=()

    for path in "${paths[@]}"; do
        if validate_path "$path" "$operation"; then
            results+=("✅ $path")
        else
            results+=("❌ $path")
            all_allowed=false
        fi
    done

    echo ""
    echo "検証結果:"
    for result in "${results[@]}"; do
        echo "  $result"
    done

    if [ "$all_allowed" = true ]; then
        return 0
    else
        return 1
    fi
}

# ============================================================
# 外部プロジェクトへのアクセス追加
# ============================================================

add_external_project() {
    local project_path="$1"

    if [ -z "$project_path" ]; then
        log_error "プロジェクトパスを指定してください"
        return 1
    fi

    # 絶対パスに変換
    local abs_path
    abs_path=$(cd "$project_path" 2>/dev/null && pwd)

    if [ -z "$abs_path" ]; then
        log_error "無効なパス: $project_path"
        return 1
    fi

    log_info "外部プロジェクトを追加: $abs_path"
    log_warn "この機能は .claude/settings.json の externalAccess.allowedPatterns を手動で編集する必要があります"

    echo ""
    echo "以下を .claude/settings.json に追加してください:"
    echo "  \"allowedPatterns\": [\"$abs_path/*\"]"
}

# ============================================================
# ヘルプ表示
# ============================================================

show_help() {
    cat << 'EOF'
🔒 validate_path.sh - パス検証ユーティリティ

使用方法:
  ./scripts/validate_path.sh <path> [--read|--write|--edit]
  ./scripts/validate_path.sh --batch <operation> <path1> <path2> ...
  ./scripts/validate_path.sh --list
  ./scripts/validate_path.sh --add-external <project_path>

オプション:
  --read      読み込み操作として検証（デフォルト）
  --write     書き込み操作として検証
  --edit      編集操作として検証
  --batch     複数パスを一括検証
  --list      許可されたディレクトリ一覧を表示
  --add-external  外部プロジェクトへのアクセスを追加
  --help, -h  このヘルプを表示

戻り値:
  0: 許可
  1: 拒否
  2: 確認必要

例:
  # 読み込み検証
  ./scripts/validate_path.sh queue/tasks/ashigaru1.yaml

  # 書き込み検証
  ./scripts/validate_path.sh demo_output/result.md --write

  # バッチ検証
  ./scripts/validate_path.sh --batch write file1.md file2.md

EOF
}

show_allowed_list() {
    echo ""
    echo "📂 許可されたディレクトリ・ファイル一覧"
    echo ""
    echo "読み込み許可ディレクトリ:"
    for dir in "${ALLOWED_READ_DIRS[@]}"; do
        echo "  ✅ $dir/"
    done
    echo ""
    echo "書き込み許可ディレクトリ:"
    for dir in "${ALLOWED_WRITE_DIRS[@]}"; do
        echo "  ✅ $dir/"
    done
    echo ""
    echo "編集許可ディレクトリ:"
    for dir in "${ALLOWED_EDIT_DIRS[@]}"; do
        echo "  ✅ $dir/"
    done
    echo ""
    echo "許可されたルートファイル:"
    for file in "${ALLOWED_ROOT_FILES[@]}"; do
        echo "  ✅ $file"
    done
    echo ""
    echo "書き込み許可ルートファイル:"
    for file in "${ALLOWED_WRITE_ROOT_FILES[@]}"; do
        echo "  ✅ $file"
    done
}

# ============================================================
# メイン処理
# ============================================================

main() {
    local operation="read"
    local batch_mode=false
    local paths=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            --read)
                operation="read"
                shift
                ;;
            --write)
                operation="write"
                shift
                ;;
            --edit)
                operation="edit"
                shift
                ;;
            --batch)
                batch_mode=true
                shift
                if [[ $# -gt 0 && "$1" != -* ]]; then
                    operation="$1"
                    shift
                fi
                ;;
            --list)
                show_allowed_list
                exit 0
                ;;
            --add-external)
                add_external_project "$2"
                exit $?
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
                paths+=("$1")
                shift
                ;;
        esac
    done

    if [ ${#paths[@]} -eq 0 ]; then
        log_error "パスを指定してください"
        show_help
        exit 1
    fi

    if [ "$batch_mode" = true ]; then
        validate_paths_batch "$operation" "${paths[@]}"
        exit $?
    else
        validate_path "${paths[0]}" "$operation"
        exit $?
    fi
}

# ============================================================
# エクスポート（source時に利用可能にする）
# ============================================================

export -f normalize_path
export -f check_denied_patterns
export -f is_allowed_directory
export -f is_allowed_root_file
export -f validate_path

# スクリプトとして実行された場合
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
