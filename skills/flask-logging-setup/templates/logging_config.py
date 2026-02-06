"""
{{APP_NAME}} ログ設定モジュール

Flask/Python アプリケーション用の構造化ロギング設定。
カテゴリ別のロガー階層構造とファイル出力を提供する。

使用方法:
    from logging_config import setup_logging, get_logger

    # アプリ起動時に一度だけ呼び出し
    setup_logging()

    # 各モジュールでロガー取得
    logger = get_logger('auth')  # {{APP_NAME}}.auth ロガー
    logger.info('ログイン成功')

カスタマイズ:
    1. APP_NAME: アプリケーション名（ルートロガー名）
    2. LOGGER_CONFIG: カテゴリ別ロガー設定
    3. LOG_DIR: ログ出力ディレクトリ
    4. LOG_FORMAT: ログフォーマット
"""
import logging
import os
from typing import Dict, Any

# =============================================================================
# 設定値（プロジェクトに合わせて編集）
# =============================================================================

# アプリケーション名（ルートロガー名）
APP_NAME = '{{APP_NAME}}'

# ログディレクトリ（相対パス or 絶対パス）
LOG_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '{{LOG_DIR}}')

# デフォルトログレベル
DEFAULT_LEVEL = logging.{{DEFAULT_LEVEL}}

# ロガー設定
# キー: カテゴリ名（short name）
# 値: file（出力ファイル名）, level（ログレベル）
LOGGER_CONFIG: Dict[str, Dict[str, Any]] = {
    # ルートロガー（全ログ統合）
    APP_NAME: {
        'file': f'{APP_NAME}.log',
        'level': DEFAULT_LEVEL,
    },
    # --- カテゴリ別ロガー（以下を編集） ---
    # {{CATEGORIES}}
    # 例:
    # f'{APP_NAME}.auth': {
    #     'file': 'auth.log',
    #     'level': logging.INFO,
    # },
    # f'{APP_NAME}.api': {
    #     'file': 'api.log',
    #     'level': logging.DEBUG,
    # },
}

# ログフォーマット
LOG_FORMAT = '%(asctime)s [%(levelname)s] %(name)s: %(message)s'
DATE_FORMAT = '%Y-%m-%d %H:%M:%S'

# 出力設定
ENABLE_FILE_OUTPUT = True
ENABLE_CONSOLE_OUTPUT = True

# =============================================================================
# ロギング関数（通常は編集不要）
# =============================================================================


def setup_logging() -> None:
    """ログ設定を初期化

    アプリケーション起動時に一度だけ呼び出すこと。
    ログディレクトリが存在しない場合は自動作成する。
    """
    if ENABLE_FILE_OUTPUT:
        os.makedirs(LOG_DIR, exist_ok=True)

    formatter = logging.Formatter(LOG_FORMAT, datefmt=DATE_FORMAT)

    for logger_name, config in LOGGER_CONFIG.items():
        logger = logging.getLogger(logger_name)
        logger.setLevel(config['level'])

        # 重複ハンドラ防止
        if logger.handlers:
            continue

        # ファイルハンドラ
        if ENABLE_FILE_OUTPUT:
            file_path = os.path.join(LOG_DIR, config['file'])
            file_handler = logging.FileHandler(file_path, encoding='utf-8')
            file_handler.setFormatter(formatter)
            file_handler.setLevel(config['level'])
            logger.addHandler(file_handler)

        # コンソールハンドラ
        if ENABLE_CONSOLE_OUTPUT:
            console_handler = logging.StreamHandler()
            console_handler.setFormatter(formatter)
            console_handler.setLevel(config['level'])
            logger.addHandler(console_handler)


def get_logger(category: str) -> logging.Logger:
    """カテゴリ名からロガーを取得

    Args:
        category: カテゴリ名（'auth', 'api', 'db' 等）
                  APP_NAME.{category} 形式のロガーを返す

    Returns:
        logging.Logger: 対応するロガーインスタンス

    Example:
        >>> logger = get_logger('auth')
        >>> logger.info('ログイン成功')
        # 出力: 2026-02-02 10:00:00 [INFO] myapp.auth: ログイン成功
    """
    return logging.getLogger(f'{APP_NAME}.{category}')


def get_root_logger() -> logging.Logger:
    """ルートロガー（全ログ統合）を取得

    Returns:
        logging.Logger: ルートロガーインスタンス
    """
    return logging.getLogger(APP_NAME)


# =============================================================================
# カテゴリ一覧（ヘルパー）
# =============================================================================

def get_available_categories() -> list:
    """利用可能なカテゴリ一覧を取得

    Returns:
        list: カテゴリ名のリスト
    """
    prefix = f'{APP_NAME}.'
    return [
        name.replace(prefix, '')
        for name in LOGGER_CONFIG.keys()
        if name.startswith(prefix)
    ]


# =============================================================================
# 使用例（このファイルを直接実行した場合のデモ）
# =============================================================================

if __name__ == '__main__':
    setup_logging()

    # ルートロガー
    root = get_root_logger()
    root.info('アプリケーション起動')

    # カテゴリ別ロガー
    # auth_logger = get_logger('auth')
    # auth_logger.info('ログインテスト')

    print(f'利用可能なカテゴリ: {get_available_categories()}')
    print(f'ログ出力先: {LOG_DIR}')
