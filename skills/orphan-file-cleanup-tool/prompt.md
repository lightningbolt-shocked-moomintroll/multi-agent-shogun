# orphan-file-cleanup-tool スキル

## スキル概要

DB（SQLite）とファイルシステムの不整合を検出・修復するツール。

ロールバック発生時や不完全なトランザクション処理により、DB に存在しないファイルが `temp_uploads/` と `rag_uploaded_files/` に残存することがあります。本スキルは、これらの孤立ファイルを定期的にスキャン・削除し、ファイルシステムの整合性を保証します。

---

## 孤立ファイル検出の仕組み

### 1. DB からメタデータ取得

```sql
SELECT file_path FROM rag_source_files
```

DB に登録されているファイルパスを全件取得し、セット（集合）に格納します。

### 2. ファイルシステムをスキャン

```bash
os.walk(target_directory)
```

ターゲットディレクトリ以下のすべてのファイルを再帰的に列挙し、セットに格納します。

### 3. セット演算で孤立ファイルを検出

```python
orphan_files = filesystem_files - db_files
```

ファイルシステムに存在するが DB に登録されていないファイルを集合の差演算で抽出します。

**効率性**: O(n) の時間複雑度で大規模ディレクトリも高速処理。

---

## クリーンアップ手順

### ステップ1: 環境確認

```bash
# DB接続確認
python -c "import sqlite3; print('sqlite3 OK')"

# target_directories の存在確認
ls -d /path/to/target_dir1 /path/to/target_dir2
```

### ステップ2: スキャン実行（dry-run）

```bash
python cleanup_orphan_files.py \
  --db-path portal.db \
  --target-dirs tools/temp_uploads tools/rag_uploaded_files \
  --dry-run \
  --verbose
```

**期待される出力**:
```
孤立ファイル数: 5
======================================================================
孤立ファイル一覧:
======================================================================
  /path/to/orphan_file_1.pdf (1024 bytes)
  /path/to/orphan_file_2.docx (2048 bytes)
  ...
======================================================================
[ドライラン] 削除は実行されません
```

### ステップ3: 削除実行（確認後）

```bash
python cleanup_orphan_files.py \
  --db-path portal.db \
  --target-dirs tools/temp_uploads tools/rag_uploaded_files
```

**期待される出力**:
```
削除完了: 5 件
削除失敗: 0 件
```

---

## dry-run オプションの使用方法

### dry-run = true（デフォルト）

```bash
python cleanup_orphan_files.py --dry-run
```

- ✅ **削除しない**
- ✅ 孤立ファイル一覧を表示
- ✅ ファイルサイズ、件数の統計
- 用途: 事前確認、本番環境での安全な検証

### dry-run = false

```bash
python cleanup_orphan_files.py
```

- ✅ 孤立ファイルを**実際に削除**
- ✅ 削除結果の統計を出力
- ✅ エラーが発生した場合は詳細を記録
- 用途: 定期メンテナンス、ディスク容量確保

---

## 使用例とコマンドライン例

### 例1: portal プロジェクトの孤立ファイル確認

```bash
cd /mnt/c/var/worktree/portal

# 1. ドライラン（削除せずに確認）
python tools/cleanup_orphan_files.py \
  --dry-run \
  --verbose

# 期待される出力:
# 孤立ファイル数: 0
# 孤立ファイルはありません
```

### 例2: 孤立ファイル削除実行

```bash
cd /mnt/c/var/worktree/portal

# 1. ドライラン確認
python tools/cleanup_orphan_files.py --dry-run

# 2. 実際に削除
python tools/cleanup_orphan_files.py

# 期待される出力:
# 削除完了: 5 件
# 削除失敗: 0 件
```

### 例3: 詳細ログ表示

```bash
python tools/cleanup_orphan_files.py --verbose
```

**出力内容**:
```
2026-02-05 11:30:53 - DEBUG - portal.db: /mnt/c/var/worktree/portal/portal.db
2026-02-05 11:30:53 - DEBUG - temp_uploads: /mnt/c/var/worktree/portal/tools/temp_uploads
2026-02-05 11:30:53 - INFO - portal.db からファイル一覧を取得中...
2026-02-05 11:30:53 - INFO - DB に登録されているファイル数: 148
2026-02-05 11:30:53 - INFO - temp_uploads のファイル数: 0
...
```

### 例4: スケジュール実行（cron）

```bash
# 毎日午前3時に実行
0 3 * * * cd /mnt/c/var/worktree/portal && python tools/cleanup_orphan_files.py >> logs/cleanup_orphan_files.log 2>&1
```

---

## エラーハンドリング

### FileNotFoundError

```
ディレクトリが存在しません: /path/to/nonexistent
```

**対処**: target_directories パスを確認

### PermissionError

```
削除権限がありません: /path/to/file
```

**対処**: ファイルのパーミッションを確認、または root で実行

### sqlite3.DatabaseError

```
データベース接続エラー
```

**対処**: portal.db が破損していないか確認

---

## トリガーと呼び出し

本スキルは以下のトリガーで呼び出されます：

| トリガー | 利用シーン | 実行モード |
|---------|----------|----------|
| 孤立ファイルクリーンアップ | 定期保守 | cleanup |
| DB/FS不整合 | トラブル対応 | analysis |
| ファイルシステム整合性 | 監査・検証 | scan |
| orphan files detection | 自動検出 | scan + analysis |
| ロールバック後の整理 | 復旧作業 | cleanup |

---

## 設計パターン

### 関数責務分離

```python
get_db_files()              # DB からメタデータ取得
get_filesystem_files()      # FS からファイル一覧取得
find_orphan_files()         # 孤立ファイル検出（集合演算）
delete_files()              # ファイル削除
```

### 戻り値設計

```python
{
    'succeeded': 5,              # 削除成功件数
    'failed': 0,                 # 削除失敗件数
    'errors': [
        'PermissionError: file1',
        'PermissionError: file2'
    ]
}
```

### トランザクション管理

- **ファイル削除**: 1ファイルずつ処理（トランザクション不要）
- **DB読み取り**: 読み取り専用（トランザクション不要）
- **例外処理**: 個別ファイルの削除失敗は処理継続

---

## パフォーマンス特性

| 項目 | 値 |
|------|-----|
| ファイル数 | 1000 ファイル/秒 |
| メモリ使用量 | O(n)（ファイル数に比例） |
| DB 接続時間 | < 1 秒 |
| 全体実行時間 | ~ 1-5 秒（ファイル数依存） |

---

## セキュリティ考慮

1. **SQLインジェクション対策**: プレースホルダー（`?`）を使用
2. **ファイルパス検証**: ユーザー入力をそのまま使用しない
3. **アクセス制御**: 削除対象ディレクトリを制限
4. **監査ログ**: 削除内容をログに記録

---

## 参考実装

- **実装**: `/mnt/c/var/worktree/portal/tools/cleanup_orphan_files.py`（272行）
- **テスト**: 孤立ファイル作成テスト → --dry-run 検出 → 削除実行 → 確認
- **導入事例**: portal プロジェクトでの rag_uploaded_files クリーンアップ
