# Batch RAG Processor - 実行時プロンプト

## Overview

このスキルはバッチ処理によるRAGシステム管理を実現する。複数のファイル形式
（TXT、PDF、DOCX、PPTX等）を一括処理し、テキスト抽出・チャンク化・ベクトル化
して、SQLiteデータベースに効率的に登録する。

### 特徴

- **マルチフォーマット対応**: TXT、PDF、DOCX、DOC、PPTX（拡張可能）
- **トランザクション管理**: 部分的な書き込みを防止
- **エラーハンドリング**: ファイル単位での失敗時も処理継続
- **スケーラビリティ**: 新形式追加時の拡張性を重視
- **ドライラン機能**: 本実行前のプレビュー確認

## 全体フロー

```
SOURCE DIRECTORY
  ├─ file1.pdf
  ├─ file2.docx
  ├─ file3.txt
  └─ file4.pptx
         ↓
   [1. FILE SCAN]
   ・ファイル一覧取得
   ・拡張子フィルタ
   ・既存確認（mode に応じて）
         ↓
   [2. TEXT EXTRACT]
   ・PDF  → pdfplumber or PyMuPDF
   ・DOCX → python-docx
   ・TXT  → utf-8 read
   ・PPTX → python-pptx
         ↓
   [3. CHUNK SPLIT]
   ・サイズ: 500文字（デフォルト）
   ・オーバーラップ: 50文字
   ・単位: 段落/スライド単位
         ↓
   [4. EMBEDDING]
   ・簡易版: SHA256 hash
   ・本番: sentence-transformers
         ↓
   [5. DB TRANSACTION]
   BEGIN TRANSACTION
   ├─ rag_source_files にメタデータ登録
   ├─ document_chunks にチャンク登録
   └─ COMMIT（成功時）/ ROLLBACK（エラー時）
         ↓
   RAG検索可能な状態に
```

## ステップ別詳細

### Step 1: ファイルスキャン

#### 1.1 スキャン対象の確認

```bash
# 対象ディレクトリ内のファイル一覧を取得
find /path/to/source \
  \( -name "*.txt" -o -name "*.pdf" -o -name "*.docx" \
     -o -name "*.doc" -o -name "*.pptx" \) \
  -type f | wc -l

# ファイル形式の分布を確認
find /path/to/source -type f -exec basename {} \; | \
  grep -oE '\.[^.]+$' | sort | uniq -c
```

#### 1.2 既存ファイル判定

```sql
-- portal.db の rag_source_files から検索
SELECT original_filename, file_hash, last_updated
FROM rag_source_files
WHERE original_filename IN (?, ?, ...)
```

**mode 別処理**:
- `scan`: 既存ファイルはスキップ
- `update`: 既存ファイルをリスト化（上書き対象）
- `rebuild`: 既存リストはクリア（すべて新規扱い）

#### 1.3 スキャン結果レポート

出力内容:
- 総ファイル数
- ファイル形式別の分布
- 新規/既存/更新の分類
- スキップ対象数

### Step 2: テキスト抽出

各ファイル形式に応じた統合抽出機能。

#### 2.1 PDF抽出（pdf2text_rag.py）

```python
def extract_text_from_pdf(pdf_path, logger):
    """
    PyMuPDF or pdfplumber を使用してテキスト抽出
    """
    # 主: pdfplumber
    # フォールバック: PyMuPDF
    # 出力: ページごとの構造化テキスト
```

**抽出内容**:
- テキスト
- 表データ
- ページメタデータ（ページ番号）

#### 2.2 Word抽出（word2text_rag.py）

```python
def extract_text_from_docx(docx_path, logger):
    """
    python-docx を使用してテキスト抽出
    """
    # 見出し階層を保持
    # Heading 1-6 + 日本語見出しに対応
    # 出力: 見出し + 段落のツリー構造
```

**抽出内容**:
- 見出し（Heading 1-6）
- 段落テキスト
- 表データ
- リスト構造

#### 2.3 テキスト抽出（txt）

```python
def extract_text_from_txt(txt_path, logger):
    """UTF-8 テキストをそのまま読み込み"""
    # エンコーディング自動判定
    # 改行制御
```

#### 2.4 PowerPoint抽出（pptx2text_rag.py）

```python
def extract_text_from_pptx(pptx_path, logger):
    """
    python-pptx を使用してスライド抽出
    """
    # スライドごとにテキスト抽出
    # 見出し・本文・表データを抽出
    # スライド番号を header_context に含める
```

**抽出内容**:
- スライド番号
- テキストボックス内テキスト
- 表データ
- 図形内テキスト

#### 2.5 エラーハンドリング

```python
try:
    text = extract_text_from_<format>(file_path, logger)
except Exception as e:
    logger.error(f"抽出失敗: {file_path}: {e}")
    return {
        "status": "failed",
        "file": file_path,
        "error": str(e),
        "retry_count": 0
    }
```

### Step 3: チャンク分割

#### 3.1 分割戦略

```python
def split_into_chunks(text, chunk_size=500, overlap=50):
    """
    テキストをチャンク分割

    Parameters:
    - chunk_size: デフォルト500文字
    - overlap: チャンク間オーバーラップ（デフォルト50文字）

    Strategy:
    - 単位: 段落単位（\n\n で分割）
    - サイズ: 指定サイズを超えた場合のみ分割
    - オーバーラップ: 前後のコンテキスト保持
    """
```

#### 3.2 分割例

```
Original Text: [1000文字]
  ↓
Chunk 1 (1-550文字): "...[先頭]...500文字...50文字オーバーラップ..."
Chunk 2 (501-1050文字): "[50文字前内容]...500文字...終了"
  ↓
[メタデータ付きチャンク]
```

#### 3.3 メタデータ付与

各チャンクに付与するメタデータ:

```python
chunk_metadata = {
    "source_file": "document.pdf",
    "page_number": 1,
    "chunk_index": 1,
    "chunk_start_char": 0,
    "header_context": "見出し1 > 見出し2"
}
```

### Step 4: ベクトル化（Embedding）

#### 4.1 本番環境

```python
def embed_chunk(chunk_text):
    """
    sentence-transformers を使用してベクトル生成
    """
    from sentence_transformers import SentenceTransformer

    model = SentenceTransformer("all-MiniLM-L6-v2")
    embedding = model.encode(chunk_text)
    return embedding.tolist()
```

#### 4.2 簡易版（開発・テスト）

```python
def embed_chunk_simple(chunk_text):
    """
    SHA256 ハッシュベースの簡易ベクトル
    """
    import hashlib
    hash_val = hashlib.sha256(chunk_text.encode()).digest()
    return list(hash_val[:32])  # 32次元ベクトル
```

### Step 5: DB トランザクション

#### 5.1 テーブル構成

**portal.db**:
```sql
CREATE TABLE rag_source_files (
    id INTEGER PRIMARY KEY,
    original_filename TEXT UNIQUE NOT NULL,
    file_hash TEXT,
    file_size INTEGER,
    uploaded_at TIMESTAMP,
    last_updated TIMESTAMP,
    content_type TEXT
);
```

**vectorstore.db**:
```sql
CREATE TABLE document_chunks (
    id INTEGER PRIMARY KEY,
    source_file TEXT NOT NULL,
    chunk_index INTEGER NOT NULL,
    chunk_text TEXT NOT NULL,
    chunk_size INTEGER,
    metadata JSON,
    created_at TIMESTAMP,
    FOREIGN KEY(source_file) REFERENCES rag_source_files(original_filename)
);

CREATE TABLE vec_chunks (
    id INTEGER PRIMARY KEY,
    chunk_id INTEGER NOT NULL,
    embedding BLOB,  -- sqlite-vec 拡張対応
    FOREIGN KEY(chunk_id) REFERENCES document_chunks(id)
);
```

#### 5.2 トランザクション処理（mode = 'update'）

```python
def process_file_with_transaction(file_path, mode):
    """トランザクション管理付き処理"""

    db = sqlite3.connect('portal.db')
    db.execute('PRAGMA foreign_keys = ON')

    try:
        # BEGIN TRANSACTION
        db.execute('BEGIN TRANSACTION')

        # Step 1: 既存ファイル削除（update モード）
        if mode == 'update':
            db.execute(
                'DELETE FROM rag_source_files WHERE original_filename = ?',
                (filename,)
            )
            db.execute(
                'DELETE FROM document_chunks WHERE source_file = ?',
                (filename,)
            )

        # Step 2: テキスト抽出
        text = extract_text(file_path)

        # Step 3: チャンク化
        chunks = split_into_chunks(text)

        # Step 4: ベクトル化
        embeddings = [embed_chunk(c) for c in chunks]

        # Step 5: DB登録
        # 5.1 rag_source_files に登録
        cursor = db.execute(
            '''INSERT INTO rag_source_files
               (original_filename, file_hash, file_size, uploaded_at, last_updated)
               VALUES (?, ?, ?, ?, ?)''',
            (filename, file_hash, file_size, now, now)
        )
        source_file_id = cursor.lastrowid

        # 5.2 document_chunks に登録
        for idx, (chunk, embedding) in enumerate(zip(chunks, embeddings)):
            cursor = db.execute(
                '''INSERT INTO document_chunks
                   (source_file, chunk_index, chunk_text, chunk_size, metadata)
                   VALUES (?, ?, ?, ?, ?)''',
                (filename, idx, chunk, len(chunk), json.dumps(metadata))
            )
            chunk_id = cursor.lastrowid

            # vec_chunks に登録
            db.execute(
                'INSERT INTO vec_chunks (chunk_id, embedding) VALUES (?, ?)',
                (chunk_id, embedding_blob)
            )

        # COMMIT
        db.commit()

        return {
            "status": "success",
            "file": filename,
            "chunks_created": len(chunks)
        }

    except Exception as e:
        # ROLLBACK
        db.rollback()
        logger.error(f"トランザクション失敗: {file_path}: {e}")
        return {
            "status": "failed",
            "file": filename,
            "error": str(e)
        }

    finally:
        db.close()
```

#### 5.3 外部キー制約

```sql
PRAGMA foreign_keys = ON;
```

- `rag_source_files` と `document_chunks` の関連付けを保証
- DELETE 時は自動カスケード削除
- エラー時は自動ロールバック

## 使用手順

### 使用例1: 初期インポート（scan モード）

```yaml
source_directory: "/path/to/documents"
mode: scan
file_types: [".txt", ".pdf", ".docx", ".pptx"]
chunk_size: 500
chunk_overlap: 50
dry_run: true  # まずプレビュー
```

**実行**:
```bash
python scripts/batch_processor.py \
  --source "/path/to/documents" \
  --mode scan \
  --config config.yaml \
  --dry-run
```

**出力**:
- スキャン対象: 125ファイル
- 新規追加: 120ファイル
- スキップ: 5ファイル
- チャンク数: 2,450チャンク（予測）

### 使用例2: ドキュメント更新（update モード）

```yaml
source_directory: "/path/to/documents"
mode: update
file_types: [".pdf", ".docx"]
dry_run: false
max_retries: 3
```

**実行**:
```bash
python scripts/batch_processor.py \
  --source "/path/to/documents" \
  --mode update \
  --max-retries 3
```

**出力**:
- 処理ファイル数: 45
- 新規作成チャンク: 1,200
- 失敗ファイル: 2
- 処理時間: 23.5秒

### 使用例3: DB 完全再構築（rebuild モード）

```yaml
source_directory: "/path/to/documents"
mode: rebuild
file_types: [".txt", ".pdf", ".docx", ".doc", ".pptx"]
dry_run: false
```

**実行**:
```bash
python scripts/batch_processor.py \
  --source "/path/to/documents" \
  --mode rebuild
```

**処理内容**:
1. portal.db の `rag_source_files` をクリア
2. vectorstore.db の `document_chunks`, `vec_chunks` をクリア
3. 全ファイル再スキャン・処理
4. DB新規構築完了

## エラーハンドリング戦略

### エラーの種類と対応

| エラー | 原因 | 対応 |
|--------|------|------|
| FileNotFound | ファイル削除済み | スキップ、ログ記録 |
| EncodeError | エンコーディング不正 | 文字コード自動判定、リトライ |
| PDFCorrupted | PDF破損 | PyMuPDF フォールバック試行 |
| DBLockedError | DB ロック | リトライ（指数バックオフ） |
| OutOfMemory | 大きなファイル | ファイル分割処理 |

### リトライ戦略

```python
def process_with_retry(file_path, max_retries=3):
    """指数バックオフによるリトライ"""
    for attempt in range(max_retries):
        try:
            return extract_and_process(file_path)
        except TemporaryError as e:
            wait_time = 2 ** attempt  # 1秒、2秒、4秒
            logger.warning(f"リトライ {attempt+1}/{max_retries}: {e}")
            time.sleep(wait_time)
        except PermanentError as e:
            logger.error(f"処理失敗（リトライ不可）: {e}")
            raise
```

### ロギング

```python
logger.info(f"ファイル処理開始: {filename}")
logger.debug(f"チャンク数: {len(chunks)}")
logger.warning(f"エラー検出（リトライ予定）: {e}")
logger.error(f"処理失敗: {filename}: {error_detail}")
```

## トランザクション管理

### ACID特性の保証

| 特性 | 実装 |
|------|------|
| **Atomicity** | BEGIN/COMMIT/ROLLBACK |
| **Consistency** | PRAGMA foreign_keys = ON |
| **Isolation** | SQLite の default (SERIALIZABLE) |
| **Durability** | fsync（SQLiteデフォルト） |

### デッドロック防止

- **ファイルごとのトランザクション**: 全体トランザクション禁止
- **タイムアウト設定**: `db.timeout = 30.0`
- **順序固定**: ファイル名でソート後処理

## パフォーマンス考慮

### メモリ効率

```python
def process_large_file_stream(file_path, chunk_size=10*1024*1024):
    """ストリーミング処理で大容量ファイル対応"""
    with open(file_path, 'rb') as f:
        while True:
            chunk = f.read(chunk_size)
            if not chunk:
                break
            yield process_chunk(chunk)
```

### 並列処理（将来検討）

```python
# 注: DB ロック考慮が必要
from concurrent.futures import ThreadPoolExecutor

with ThreadPoolExecutor(max_workers=4) as executor:
    futures = [
        executor.submit(process_file, f)
        for f in file_list
    ]
```

## 新形式追加時の手順

### PPTX 追加の例

1. **抽出関数作成**: `scripts/text_extractors.py` に `extract_text_from_pptx()` 追加
2. **バッチ処理エンジン更新**: `scripts/batch_processor.py` の `EXTRACTOR_MAP` に登録
3. **テスト**: `extract_text_from_pptx()` のユニットテスト作成
4. **ドキュメント更新**: prompt.md に新形式の説明追加

```python
# scripts/text_extractors.py に追加
EXTRACTOR_MAP = {
    '.txt': extract_text_from_txt,
    '.pdf': extract_text_from_pdf,
    '.docx': extract_text_from_docx,
    '.doc': extract_text_from_docx,
    '.pptx': extract_text_from_pptx,  # ← 新規追加
}
```

## チェックリスト

### 実行前確認

- [ ] `dry_run: true` でプレビュー実行
- [ ] ログファイル出力先を確認
- [ ] DB バックアップを取得
- [ ] ディスク空き容量を確認（最小 1GB 推奨）
- [ ] 処理予定時間を見積もり

### 実行中

- [ ] ログ出力を監視
- [ ] エラー内容を確認（リトライ判定）
- [ ] 処理進捗を追跡

### 実行後

- [ ] 統計情報を確認
  - 新規チャンク数
  - 失敗ファイル数
  - 処理時間
- [ ] DB 整合性を確認
  ```sql
  SELECT COUNT(*) FROM rag_source_files;
  SELECT COUNT(*) FROM document_chunks;
  SELECT COUNT(*) FROM vec_chunks;
  ```
- [ ] RAG検索で動作確認
- [ ] ログアーカイブ

## 制約事項

### サポート

- ✅ TXT、PDF、DOCX、DOC、PPTX（拡張可能）
- ✅ 500文字デフォルトチャンク分割
- ✅ トランザクション管理
- ✅ ドライラン確認

### 非サポート

- ❌ 古い PowerPoint 形式（.ppt）
- ❌ 画像内テキスト抽出（OCR）
- ❌ 暗号化 PDF（ユーザー定義パスワード）
- ❌ リアルタイム処理（バッチのみ）

### 本番環境への追加検討

- python-pptx ライブラリ追加
- requirements.txt 更新
- 大規模ファイル（100+スライド）の処理時間確認
- ベクトル化精度確認（新形式）

## 関連スクリプト設計

### 1. batch_processor.py（メインエンジン）

```python
class BatchRAGProcessor:
    """バッチ処理エンジン"""

    def __init__(self, config):
        self.config = config
        self.logger = get_logger('batch_processor')

    def process(self, source_dir, mode, dry_run=True):
        """メイン処理ループ"""
        # ファイルスキャン
        # 既存確認
        # テキスト抽出
        # チャンク化
        # DB登録
        # 統計出力
        pass
```

### 2. file_scanner.py（ファイルスキャン）

```python
class FileScanner:
    """ファイルスキャン・フィルタ機能"""

    def scan_directory(self, source_dir, extensions):
        """拡張子指定でスキャン"""
        pass

    def get_existing_files(self, filenames):
        """DB から既存ファイル取得"""
        pass
```

### 3. text_extractors.py（抽出統合）

```python
EXTRACTOR_MAP = {
    '.txt': extract_text_from_txt,
    '.pdf': extract_text_from_pdf,
    '.docx': extract_text_from_docx,
    '.pptx': extract_text_from_pptx,
}

def extract_text(file_path):
    """ファイル形式に応じて自動選択"""
    pass
```

### 4. chunk_splitter.py（チャンク分割）

```python
class ChunkSplitter:
    """チャンク分割機能"""

    def split(self, text, chunk_size, overlap):
        """段落単位でチャンク分割"""
        pass

    def add_metadata(self, chunks, source_info):
        """メタデータ付与"""
        pass
```

### 5. db_manager.py（DB トランザクション）

```python
class DatabaseManager:
    """DB 操作・トランザクション管理"""

    def process_with_transaction(self, file_info, chunks, embeddings):
        """トランザクション付きDB登録"""
        pass

    def cleanup_existing(self, filename, mode):
        """既存データクリア"""
        pass
```
