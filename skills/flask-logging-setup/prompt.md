# Flask Logging Setup - 実行時プロンプト

## Overview

このスキルは Flask/Python アプリケーションに構造化されたロギングシステムを導入する。
`print()` 文によるデバッグを Python `logging` モジュールに移行し、
カテゴリ別のログファイル出力を実現する。

## 使用手順

### Step 1: 現状分析

まずプロジェクトの現状を確認する：

```bash
# print() 文の一覧を取得
grep -rn "print(" --include="*.py" . | head -50
```

確認事項：
- 既存の print() プレフィックスパターン（例: `[RAG]`, `[AUTH]`）
- 主要な機能カテゴリ
- ログ出力が必要な処理

### Step 2: ユーザーへの質問

以下を確認：

1. **アプリケーション名**
   - ルートロガーの名前に使用（例: `portal`, `myapp`）

2. **ログカテゴリ**
   - どの機能カテゴリでログを分けるか
   - 例: `auth`, `api`, `db`, `cache`, `task`

3. **ログレベル**
   - 開発環境: DEBUG
   - 本番環境: INFO or WARNING

4. **出力先**
   - ファイル出力: 必要 / 不要
   - コンソール出力: 必要 / 不要

5. **ログディレクトリ**
   - デフォルト: `logs/`

### Step 3: テンプレートのカスタマイズ

`templates/logging_config.py` をベースに、ユーザーの回答に合わせてカスタマイズ：

1. `{{APP_NAME}}` → アプリケーション名
2. `{{CATEGORIES}}` → ログカテゴリ辞書
3. `{{LOG_DIR}}` → ログディレクトリパス
4. `{{DEFAULT_LEVEL}}` → デフォルトログレベル

### Step 4: ファイル配置

```
project_root/
├── logging_config.py   # 生成したファイル
├── logs/               # 自動作成される
│   ├── {app_name}.log  # 全ログ統合
│   ├── {category1}.log
│   └── {category2}.log
└── .gitignore          # logs/ を追加
```

### Step 5: 使用方法の案内

```python
# app.py での使用例
from logging_config import setup_logging, get_logger

# アプリ起動時に一度だけ呼び出し
setup_logging()

# 各モジュールでロガー取得
logger = get_logger('auth')
logger.info('ログイン成功')
logger.error('認証エラー')
```

## 移行ガイド

既存の print() を logging に置き換える際の対応表を提供：

```python
# Before
print(f"[AUTH] ログイン成功: {user}")

# After
from logging_config import get_logger
auth_logger = get_logger('auth')
auth_logger.info(f'ログイン成功: {user}')
```

### ログレベルの選択基準

| レベル | 用途 |
|--------|------|
| DEBUG | 詳細なデバッグ情報、変数の値など |
| INFO | 正常な処理の記録、状態変化 |
| WARNING | 予期しないが続行可能な状況 |
| ERROR | エラー発生、機能が動作しない |
| CRITICAL | 致命的エラー、システム停止 |

## オプション: ログローテーション

大量のログが予想される場合は `RotatingFileHandler` を使用：

```python
from logging.handlers import RotatingFileHandler

handler = RotatingFileHandler(
    file_path,
    maxBytes=10*1024*1024,  # 10MB
    backupCount=5,
    encoding='utf-8'
)
```

## チェックリスト

- [ ] アプリケーション名を決定
- [ ] ログカテゴリを洗い出し
- [ ] logging_config.py を配置
- [ ] .gitignore に logs/ を追加
- [ ] アプリ起動時に setup_logging() を呼び出し
- [ ] 既存の print() を段階的に移行
