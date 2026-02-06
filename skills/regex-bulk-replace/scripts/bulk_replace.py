#!/usr/bin/env python3
"""
Regex Bulk Replace - 正規表現による一括置換スクリプト

Usage:
    python bulk_replace.py --target FILE --mode MODE [OPTIONS]

Examples:
    # ドライラン（変更なし）
    python bulk_replace.py --target app.py --mode print-to-logging --dry-run

    # 実行（バックアップ付き）
    python bulk_replace.py --target app.py --mode print-to-logging --backup

    # 設定ファイル使用
    python bulk_replace.py --config config.yaml
"""

import argparse
import re
import sys
import shutil
from pathlib import Path
from datetime import datetime
from typing import Optional
import difflib

try:
    import yaml
    YAML_AVAILABLE = True
except ImportError:
    YAML_AVAILABLE = False


# =============================================================================
# プレフィックス → ロガー マッピング（print-to-logging モード用）
# =============================================================================
DEFAULT_PREFIX_TO_LOGGER = {
    '[RAG]': 'rag',
    '[RSS]': 'rss',
    '[RSS ALL]': 'rss',
    '[SAML]': 'saml',
    '[SAML SLS]': 'saml',
    '[SAML DEBUG]': 'saml',
    '[SwitchBot]': 'switchbot',
    '[SwitchBot DB]': 'switchbot',
    '[PDF抽出]': 'extract',
    '[Word抽出]': 'extract',
    '[権限]': 'auth',
    '[履歴]': 'session',
    '[app.py]': 'session',
    '[警告]': 'session',
    '[DEBUG]': 'session',
    '[ERROR]': 'session',
}

# ログレベル判定パターン
ERROR_PATTERNS = ['エラー', 'error', 'Error', 'ERROR', '失敗', 'exception', 'Exception']
WARNING_PATTERNS = ['警告', 'warning', 'Warning', 'WARNING']
DEBUG_PATTERNS = ['デバッグ', 'debug', 'Debug', 'DEBUG']


def determine_log_level(message: str) -> str:
    """メッセージ内容からログレベルを判定"""
    for pattern in ERROR_PATTERNS:
        if pattern in message:
            return 'error'
    for pattern in WARNING_PATTERNS:
        if pattern in message:
            return 'warning'
    for pattern in DEBUG_PATTERNS:
        if pattern in message:
            return 'debug'
    return 'info'


def convert_print_to_logging(line: str, prefix_map: dict, default_level: str = 'info') -> Optional[str]:
    """print文をlogging文に変換"""
    # f-string パターン: print(f"[PREFIX] message")
    pattern_fstring = r'print\((f?)(["\'])\[([^\]]+)\]\s*(.*)\2\)'

    match = re.search(pattern_fstring, line)
    if not match:
        return None

    is_fstring = match.group(1) == 'f'
    prefix = f'[{match.group(3)}]'
    message = match.group(4)

    # プレフィックスからロガー名を取得
    logger_name = prefix_map.get(prefix)
    if not logger_name:
        # マッピングにない場合はプレフィックスをそのままロガー名に
        logger_name = match.group(3).lower().replace(' ', '_')

    # ログレベル判定
    level = determine_log_level(message)
    if level == 'info':
        level = default_level

    # 変換後の文字列を生成
    indent = re.match(r'^(\s*)', line).group(1)

    if is_fstring:
        new_line = f"{indent}get_logger('{logger_name}').{level}(f\"{message}\")"
    else:
        new_line = f"{indent}get_logger('{logger_name}').{level}(\"{message}\")"

    return new_line


def apply_generic_rules(line: str, rules: list) -> str:
    """汎用置換ルールを適用"""
    result = line
    for rule in rules:
        pattern = rule.get('pattern')
        replacement = rule.get('replacement')
        if pattern and replacement:
            result = re.sub(pattern, replacement, result)
    return result


def process_file(
    file_path: Path,
    mode: str,
    prefix_map: dict = None,
    rules: list = None,
    default_level: str = 'info',
    dry_run: bool = True,
    backup: bool = False,
    verbose: bool = False
) -> dict:
    """ファイルを処理"""

    if prefix_map is None:
        prefix_map = DEFAULT_PREFIX_TO_LOGGER
    if rules is None:
        rules = []

    stats = {
        'file': str(file_path),
        'total_lines': 0,
        'modified_lines': 0,
        'changes': []
    }

    try:
        original_content = file_path.read_text(encoding='utf-8')
    except Exception as e:
        stats['error'] = str(e)
        return stats

    original_lines = original_content.splitlines(keepends=True)
    new_lines = []

    for i, line in enumerate(original_lines, 1):
        stats['total_lines'] += 1
        new_line = line

        if mode == 'print-to-logging':
            converted = convert_print_to_logging(line.rstrip('\n'), prefix_map, default_level)
            if converted:
                new_line = converted + '\n' if line.endswith('\n') else converted
                stats['modified_lines'] += 1
                stats['changes'].append({
                    'line_num': i,
                    'before': line.rstrip('\n'),
                    'after': new_line.rstrip('\n')
                })
        elif mode == 'generic':
            new_line = apply_generic_rules(line, rules)
            if new_line != line:
                stats['modified_lines'] += 1
                stats['changes'].append({
                    'line_num': i,
                    'before': line.rstrip('\n'),
                    'after': new_line.rstrip('\n')
                })

        new_lines.append(new_line)

    new_content = ''.join(new_lines)

    # diff生成
    diff = list(difflib.unified_diff(
        original_lines,
        new_lines,
        fromfile=f'a/{file_path}',
        tofile=f'b/{file_path}',
        lineterm=''
    ))
    stats['diff'] = '\n'.join(diff)

    # 実際の書き込み
    if not dry_run and stats['modified_lines'] > 0:
        if backup:
            backup_path = file_path.with_suffix(f'.{datetime.now().strftime("%Y%m%d_%H%M%S")}.bak')
            shutil.copy2(file_path, backup_path)
            stats['backup_path'] = str(backup_path)

        file_path.write_text(new_content, encoding='utf-8')
        stats['written'] = True
    else:
        stats['written'] = False

    return stats


def print_stats(stats: dict, verbose: bool = False):
    """統計情報を出力"""
    print(f"\n{'='*60}")
    print(f"File: {stats['file']}")
    print(f"Total lines: {stats['total_lines']}")
    print(f"Modified lines: {stats['modified_lines']}")

    if stats.get('backup_path'):
        print(f"Backup: {stats['backup_path']}")

    if stats.get('error'):
        print(f"Error: {stats['error']}")

    if stats.get('written'):
        print("Status: WRITTEN")
    else:
        print("Status: DRY RUN (no changes)")

    if verbose and stats.get('changes'):
        print(f"\n{'='*60}")
        print("Changes:")
        for change in stats['changes']:
            print(f"\nLine {change['line_num']}:")
            print(f"  - {change['before']}")
            print(f"  + {change['after']}")

    if stats.get('diff'):
        print(f"\n{'='*60}")
        print("Diff:")
        print(stats['diff'])


def load_config(config_path: str) -> dict:
    """設定ファイルを読み込み"""
    if not YAML_AVAILABLE:
        print("Error: PyYAML is not installed. Install with: pip install pyyaml")
        sys.exit(1)

    with open(config_path, 'r', encoding='utf-8') as f:
        return yaml.safe_load(f)


def main():
    parser = argparse.ArgumentParser(
        description='Regex Bulk Replace - 正規表現による一括置換',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )

    parser.add_argument('--target', '-t', help='置換対象ファイル')
    parser.add_argument('--mode', '-m', choices=['generic', 'print-to-logging'],
                        default='print-to-logging', help='置換モード')
    parser.add_argument('--config', '-c', help='設定ファイル (YAML)')
    parser.add_argument('--dry-run', '-n', action='store_true', default=True,
                        help='ドライラン（変更しない）')
    parser.add_argument('--execute', '-x', action='store_true',
                        help='実際に変更を適用')
    parser.add_argument('--backup', '-b', action='store_true',
                        help='バックアップを作成')
    parser.add_argument('--verbose', '-v', action='store_true',
                        help='詳細出力')

    args = parser.parse_args()

    # 設定の初期化
    config = {}
    if args.config:
        config = load_config(args.config)

    # コマンドライン引数で上書き
    target = args.target or config.get('target_files')
    mode = args.mode if args.mode != 'print-to-logging' else config.get('mode', 'print-to-logging')
    dry_run = not args.execute
    backup = args.backup or config.get('backup', False)
    verbose = args.verbose or config.get('verbose', False)
    prefix_map = config.get('prefix_to_logger_map', DEFAULT_PREFIX_TO_LOGGER)
    rules = config.get('replacement_rules', [])
    default_level = config.get('default_level', 'info')

    if not target:
        parser.error("--target or config file with target_files is required")

    # ファイル一覧を取得
    if isinstance(target, str):
        target = [target]

    all_files = []
    for pattern in target:
        path = Path(pattern)
        if path.exists() and path.is_file():
            all_files.append(path)
        else:
            # glob展開
            all_files.extend(Path('.').glob(pattern))

    if not all_files:
        print(f"Error: No files found matching: {target}")
        sys.exit(1)

    print(f"Mode: {mode}")
    print(f"Dry run: {dry_run}")
    print(f"Files to process: {len(all_files)}")

    # 処理実行
    total_modified = 0
    for file_path in all_files:
        stats = process_file(
            file_path,
            mode=mode,
            prefix_map=prefix_map,
            rules=rules,
            default_level=default_level,
            dry_run=dry_run,
            backup=backup,
            verbose=verbose
        )
        print_stats(stats, verbose)
        total_modified += stats['modified_lines']

    print(f"\n{'='*60}")
    print(f"Summary: {total_modified} lines would be modified in {len(all_files)} files")

    if dry_run:
        print("\nThis was a DRY RUN. Use --execute to apply changes.")


if __name__ == '__main__':
    main()
