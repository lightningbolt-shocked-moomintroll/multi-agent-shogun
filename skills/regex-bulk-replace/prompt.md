# Regex Bulk Replace - 実行時プロンプト

## Overview

このスキルは正規表現を使用してコードを一括置換する。
`print()` → `logging` への移行など、定型的な書き換え作業を効率化する。
Editツールによる逐次置換と比較して、トークン消費を約78%削減できる。

## 使用手順

### Step 1: 現状分析

まず置換対象を把握する：

```bash
# 置換対象の一覧を取得（例: print文）
grep -rn "print(" --include="*.py" . | head -50

# プレフィックスパターンの分析
grep "print(" target.py | grep -oE '\[[A-Za-z0-9 ]+\]' | sort | uniq -c
```

確認事項：
- 置換対象の総数
- パターンのバリエーション（f-string、シングル/ダブルクォート等）
- プレフィックスとロガーのマッピング（logging移行の場合）

### Step 2: 置換モードの選択

#### A. print-to-logging モード

print文をloggingに移行する専用モード。

```yaml
mode: print-to-logging
target_files: "app.py"
prefix_to_logger_map:
  "[RAG]": "rag"
  "[RSS]": "rss"
  "[RSS ALL]": "rss"
  "[SwitchBot]": "switchbot"
  "[SwitchBot DB]": "switchbot"
default_level: "info"
```

#### B. generic モード

汎用的な正規表現置換。

```yaml
mode: generic
target_files: "*.py"
replacement_rules:
  - pattern: 'old_function\((.*?)\)'
    replacement: 'new_function(\1)'
  - pattern: 'import old_module'
    replacement: 'import new_module'
```

### Step 3: ドライラン実行

**重要**: 必ずドライランで確認してから実行する。

```bash
python scripts/bulk_replace.py \
  --target "app.py" \
  --mode print-to-logging \
  --config config.yaml \
  --dry-run
```

出力内容：
- 置換対象の行一覧
- 置換後のプレビュー
- 統計情報（対象ファイル数、置換箇所数）

### Step 4: 確認と実行

ドライランの結果を確認後、実行：

```bash
python scripts/bulk_replace.py \
  --target "app.py" \
  --mode print-to-logging \
  --config config.yaml \
  --backup  # オプション：バックアップ作成
```

### Step 5: 検証

```bash
# 変更内容の確認
git diff app.py

# 構文エラーがないか確認
python -m py_compile app.py
```

## print-to-logging モード詳細

### プレフィックスマッピング

```python
PREFIX_TO_LOGGER = {
    '[RAG]': 'rag',
    '[RSS]': 'rss',
    '[RSS ALL]': 'rss',
    '[SAML]': 'saml',
    '[SwitchBot]': 'switchbot',
    '[SwitchBot DB]': 'switchbot',
    '[PDF抽出]': 'extract',
    '[Word抽出]': 'extract',
    '[権限]': 'auth',
}
```

### ログレベルの自動判定

メッセージ内容からログレベルを推測：

| パターン | ログレベル |
|----------|-----------|
| `エラー`, `error`, `Error`, `失敗` | `error` |
| `警告`, `warning`, `Warning` | `warning` |
| `デバッグ`, `debug`, `DEBUG` | `debug` |
| その他 | `info` |

### 変換例

```python
# Before
print(f"[RAG] ファイル処理完了: {filename}")
print(f"[RAG] エラー: {e}")
print("[RSS] データなし")

# After
get_logger('rag').info(f"ファイル処理完了: {filename}")
get_logger('rag').error(f"{e}")
get_logger('rss').info("データなし")
```

## 対応パターン

### サポートするprint形式

| パターン | 例 | 対応 |
|----------|-----|------|
| f-string (double quote) | `print(f"[X] {var}")` | OK |
| f-string (single quote) | `print(f'[X] {var}')` | OK |
| simple string | `print("[X] message")` | OK |
| 変数のみ | `print(var)` | 手動対応 |
| 複数引数 | `print(a, b, c)` | 手動対応 |

### エッジケース

1. **複数行print**: 現在未対応。手動で対応。
2. **ネストした括弧**: `{func(x)}` → 対応可能
3. **プレフィックスなし**: 手動でカテゴリを判断

## スクリプト使用方法

```bash
# 基本使用法
python scripts/bulk_replace.py --target FILE --mode MODE [OPTIONS]

# オプション
--target      対象ファイル（glob対応）
--mode        モード（generic / print-to-logging）
--config      設定ファイル（YAML）
--dry-run     ドライラン（変更しない）
--backup      バックアップ作成
--verbose     詳細出力
```

## 設定ファイル例

```yaml
# config.yaml
mode: print-to-logging
target_files:
  - "app.py"
  - "utils/*.py"
prefix_to_logger_map:
  "[RAG]": "rag"
  "[RSS]": "rss"
default_level: "info"
dry_run: true
backup: false
```

## チェックリスト

- [ ] 置換対象を grep で確認
- [ ] プレフィックスとロガーのマッピングを定義
- [ ] ドライランで変換結果を確認
- [ ] 構文エラーがないか確認
- [ ] git diff で最終確認
- [ ] 実行後にアプリが正常動作するかテスト

## 制約事項

- 複数行にまたがるprint文は手動対応
- AST解析が必要な複雑な変更には不向き
- 機械的な置換のみ。文脈判断が必要な場合はEditツール推奨
- dry_runでの事前確認を強く推奨
