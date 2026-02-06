#!/usr/bin/env python3
"""
孤立ファイルクリーンアップスクリプト テンプレート

このテンプレートは、orphan-file-cleanup-tool スキルの実装例を示します。
プロジェクト固有の要件に応じてカスタマイズしてください。

使用方法:
    python cleanup_orphan_files.py --dry-run      # ドライラン
    python cleanup_orphan_files.py                 # 実際に削除
    python cleanup_orphan_files.py --verbose       # 詳細ログ
"""

import argparse
import sqlite3
import os
import sys
from pathlib import Path
import logging

# ロギング設定
def setup_logging(verbose=False):
    """ロギング設定"""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format='%(asctime)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    return logging.getLogger(__name__)


def get_db_files(db_path, table_name='rag_source_files', column_name='file_path'):
    """
    DB からメタデータを取得

    Args:
        db_path (str): SQLite DB パス
        table_name (str): テーブル名
        column_name (str): ファイルパスカラム名

    Returns:
        set: DB に登録されているファイルパスのセット
    """
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        # テーブル存在確認
        cursor.execute(
            f"SELECT name FROM sqlite_master WHERE type='table' AND name='{table_name}'"
        )
        if not cursor.fetchone():
            return set()

        # ファイルパス取得
        cursor.execute(f'SELECT {column_name} FROM {table_name}')
        db_files = {row[0] for row in cursor.fetchall()}

        conn.close()
        return db_files
    except sqlite3.DatabaseError as e:
        logging.error(f"データベース接続エラー: {e}")
        raise


def get_filesystem_files(directory):
    """
    ファイルシステムからファイル一覧を取得

    Args:
        directory (str): 対象ディレクトリ

    Returns:
        set: ディレクトリ内のファイルパスのセット
    """
    if not os.path.isdir(directory):
        raise FileNotFoundError(f"ディレクトリが存在しません: {directory}")

    filesystem_files = set()
    for root, dirs, files in os.walk(directory):
        for file in files:
            file_path = os.path.join(root, file)
            filesystem_files.add(file_path)

    return filesystem_files


def find_orphan_files(db_files, filesystem_files):
    """
    孤立ファイルを検出

    Args:
        db_files (set): DB に登録されているファイルパス
        filesystem_files (set): ファイルシステムのファイルパス

    Returns:
        set: 孤立ファイルのセット
    """
    return filesystem_files - db_files


def delete_files(orphan_files, logger):
    """
    孤立ファイルを削除

    Args:
        orphan_files (set): 削除対象のファイルパス
        logger: ロガーインスタンス

    Returns:
        dict: 削除結果
    """
    result = {
        'succeeded': 0,
        'failed': 0,
        'errors': []
    }

    for file_path in sorted(orphan_files):
        try:
            if os.path.isfile(file_path):
                os.remove(file_path)
                logger.info(f"削除完了: {file_path}")
                result['succeeded'] += 1
            else:
                logger.warning(f"ファイルではありません: {file_path}")
                result['failed'] += 1
        except PermissionError as e:
            logger.error(f"削除権限がありません: {file_path}")
            result['failed'] += 1
            result['errors'].append(f"PermissionError: {file_path}")
        except Exception as e:
            logger.error(f"削除エラー: {file_path} - {e}")
            result['failed'] += 1
            result['errors'].append(f"{type(e).__name__}: {file_path}")

    return result


def main():
    """メイン処理"""
    parser = argparse.ArgumentParser(
        description='孤立ファイルクリーンアップツール',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
使用例:
  python cleanup_orphan_files.py --dry-run
  python cleanup_orphan_files.py
  python cleanup_orphan_files.py --verbose
        """
    )

    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='削除せずに孤立ファイルの一覧を表示のみ'
    )
    parser.add_argument(
        '--verbose',
        action='store_true',
        help='詳細なログを表示'
    )
    parser.add_argument(
        '--db-path',
        default='portal.db',
        help='SQLite DB パス（デフォルト: portal.db）'
    )
    parser.add_argument(
        '--target-dirs',
        nargs='+',
        default=['tools/temp_uploads', 'tools/rag_uploaded_files'],
        help='スキャン対象ディレクトリ（複数指定可）'
    )

    args = parser.parse_args()

    logger = setup_logging(args.verbose)

    # プロジェクトルートの確認
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)

    # パス構築
    db_path = args.db_path
    if not os.path.isabs(db_path):
        db_path = os.path.join(project_root, db_path)

    logger.info("孤立ファイルクリーンアップを開始します")
    logger.debug(f"portal.db: {db_path}")
    logger.debug(f"target_dirs: {args.target_dirs}")

    try:
        # DB からファイル一覧を取得
        logger.info(f"{os.path.basename(db_path)} からファイル一覧を取得中...")
        db_files = get_db_files(db_path)
        logger.info(f"DB に登録されているファイル数: {len(db_files)}")

        # ファイルシステムからファイル一覧を取得
        all_filesystem_files = set()
        for dir_path in args.target_dirs:
            if not os.path.isabs(dir_path):
                dir_path = os.path.join(project_root, dir_path)

            if os.path.isdir(dir_path):
                logger.info(f"{os.path.basename(dir_path)} からファイル一覧を取得中...")
                try:
                    filesystem_files = get_filesystem_files(dir_path)
                    all_filesystem_files.update(filesystem_files)
                    logger.info(f"{os.path.basename(dir_path)} のファイル数: {len(filesystem_files)}")
                except FileNotFoundError as e:
                    logger.warning(f"{e}")
            else:
                logger.warning(f"ディレクトリが存在しません: {dir_path}")

        # 孤立ファイルを検出
        orphan_files = find_orphan_files(db_files, all_filesystem_files)
        logger.info(f"孤立ファイル数: {len(orphan_files)}")

        if not orphan_files:
            logger.info("孤立ファイルはありません")
            return 0

        # 孤立ファイルを表示
        logger.info("=" * 70)
        logger.info("孤立ファイル一覧:")
        logger.info("=" * 70)
        for file_path in sorted(orphan_files):
            file_size = os.path.getsize(file_path) if os.path.exists(file_path) else 0
            logger.info(f"  {file_path} ({file_size} bytes)")

        # ドライランモード
        if args.dry_run:
            logger.info("=" * 70)
            logger.info("[ドライラン] 削除は実行されません")
            logger.info(f"実際に削除する場合は、--dry-run オプションなしで実行してください")
            return 0

        # 実際に削除
        logger.info("=" * 70)
        logger.info("孤立ファイルを削除中...")
        result = delete_files(orphan_files, logger)

        # 結果を表示
        logger.info("=" * 70)
        logger.info(f"削除完了: {result['succeeded']} 件")
        logger.info(f"削除失敗: {result['failed']} 件")

        if result['errors']:
            logger.error("エラー詳細:")
            for error in result['errors']:
                logger.error(f"  {error}")
            return 1

        return 0

    except FileNotFoundError as e:
        logger.error(f"ファイルエラー: {e}")
        return 1
    except sqlite3.DatabaseError as e:
        logger.error(f"データベースエラー: {e}")
        return 1
    except Exception as e:
        logger.error(f"予期しないエラー: {e}", exc_info=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())
