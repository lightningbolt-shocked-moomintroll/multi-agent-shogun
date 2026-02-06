# PPTX Text Extractor - 実行時プロンプト

## Overview

このスキルは PowerPoint（.pptx）ファイルからテキスト、発表者ノート、
テーブル、メタデータを自動抽出する。python-pptx ライブラリを使用し、
RAG（Retrieval-Augmented Generation）システムに対応した形式で出力可能。

portal の既存ドキュメント処理システム（PDF/Word）と統一的に処理でき、
企業内の複数形式資料を一括索引化する際の重要なスキルである。

## 使用開始前のチェックリスト

- [ ] python-pptx がインストールされているか確認
- [ ] 対象 PPTX ファイルが読み取り可能な形式か確認
- [ ] 出力先ディレクトリの書き込み権限確認
- [ ] メモリ容量確認（大きなプレゼンテーションの場合）

## ステップバイステップ実行手順

### Step 1: 環境確認

```bash
# python-pptx のインストール確認
python -c "from pptx import Presentation; print('python-pptx OK')"

# インストールされていない場合
pip install python-pptx

# バージョン確認
python -c "import pptx; print(pptx.__version__)"
```

### Step 2: 処理対象の確認

処理前に対象 PPTX ファイルを確認：

```bash
# 単一ファイル
ls -lh presentation.pptx

# 複数ファイル（glob パターン）
ls -lh *.pptx
ls -lh documents/*.pptx

# ファイルの有効性確認（簡易）
python -c "from pptx import Presentation; Presentation('target.pptx')" && echo "OK" || echo "ERROR"
```

### Step 3: 抽出モードの選択

実行目的に応じてモードを選択：

#### A. Basic モード（高速、軽量）

スライドテキストと発表者ノートのみを抽出。テーブルやメタデータは不要な場合。

```bash
python scripts/extract_pptx.py \
  --pptx presentation.pptx \
  --mode basic \
  --output output.json
```

**出力形式例:**
```json
{
  "slides": [
    {
      "slide_number": 1,
      "content": ["テキストボックス1", "テキストボックス2"],
      "notes": "発表者のメモ内容"
    },
    {
      "slide_number": 2,
      "content": ["別スライドのテキスト"],
      "notes": null
    }
  ]
}
```

#### B. Full モード（包括的）

テキスト、ノート、テーブル、メタデータをすべて抽出。

```bash
python scripts/extract_pptx.py \
  --pptx presentation.pptx \
  --mode full \
  --output output.json
```

**出力形式例:**
```json
{
  "metadata": {
    "title": "プレゼンテーションタイトル",
    "author": "作成者名",
    "created": "2026-02-04",
    "slide_count": 10
  },
  "slides": [
    {
      "slide_number": 1,
      "layout": "Title Slide",
      "content": ["タイトル", "サブタイトル"],
      "tables": [],
      "notes": "発表メモ",
      "metadata": {
        "position": "top-left",
        "has_animation": false
      }
    }
  ]
}
```

#### C. RAG-Compatible モード（推奨・RAG向け）

PDF/Word の既存処理との統一形式で出力。portal RAG システムへの
統合を想定。テキストはベクトル化に適した形式。

```bash
python scripts/extract_pptx.py \
  --pptx presentation.pptx \
  --mode rag-compatible \
  --output output.json
```

**出力形式例（PDF/Word との統一）:**
```json
{
  "pages": [
    {
      "page_number": 1,
      "page_type": "slide",
      "content": [
        "スライドテキスト1",
        "テキストボックス内容",
        "| ヘッダ1 | ヘッダ2 |\n| --- | --- |\n| セル1-1 | セル1-2 |"
      ],
      "metadata": {
        "source_format": "pptx",
        "speaker_notes": "発表者のメモ内容",
        "slide_layout": "Title and Content"
      },
      "text": "結合されたテキスト（RAG ベクトル化用）"
    }
  ]
}
```

### Step 4: オプション指定

実行時にオプションで処理内容をカスタマイズ：

```bash
# テーブルを含めない
python scripts/extract_pptx.py \
  --pptx presentation.pptx \
  --mode full \
  --no-tables \
  --output output.json

# 発表者ノートを含めない
python scripts/extract_pptx.py \
  --pptx presentation.pptx \
  --mode full \
  --no-notes \
  --output output.json

# メタデータを含める
python scripts/extract_pptx.py \
  --pptx presentation.pptx \
  --mode full \
  --include-metadata \
  --output output.json

# 最初の10スライドのみ処理
python scripts/extract_pptx.py \
  --pptx presentation.pptx \
  --mode full \
  --max-slides 10 \
  --output output.json

# Markdown 形式出力
python scripts/extract_pptx.py \
  --pptx presentation.pptx \
  --mode full \
  --output-format markdown \
  --output output.md

# 複数ファイルを一括処理
python scripts/extract_pptx.py \
  --pptx "*.pptx" \
  --mode rag-compatible \
  --output-dir results/
```

### Step 5: 処理実行と出力確認

実際に実行：

```bash
python scripts/extract_pptx.py \
  --pptx presentation.pptx \
  --mode rag-compatible \
  --output extracted.json \
  --verbose
```

出力を確認：

```bash
# JSON 形式の構文確認
python -m json.tool extracted.json | head -50

# ファイルサイズ確認
ls -lh extracted.json

# 抽出されたスライド数確認
python -c "import json; data=json.load(open('extracted.json')); print(f'Pages: {len(data[\"pages\"])}')"
```

### Step 6: エラーハンドリング

#### 一般的なエラーと対応

| エラー | 原因 | 対応 |
|--------|------|------|
| `FileNotFoundError` | ファイルが見つからない | ファイルパス確認、glob パターン確認 |
| `InvalidPptxFile` | 破損した PPTX | ファイルを別で開いて修復を試行 |
| `UnicodeDecodeError` | 文字コード問題 | 文字エンコーディング指定 |
| `MemoryError` | メモリ不足 | `--max-slides` で処理スライド数制限 |
| `NoSlideError` | スライドが存在しない | ファイルの有効性確認 |

#### 処理継続戦略

以下の場合は処理を継続し、統計情報に記録：

- 特定スライドのテキスト抽出失敗 → スキップして次に進む
- テーブル抽出失敗 → テーブル情報は空で、テキストは抽出
- メタデータ読み込み失敗 → メタデータは null で継続
- SmartArt 検出 → スキップし、警告を記録

```python
# 擬似コード例
for slide in presentation.slides:
    try:
        content = extract_text(slide)
    except SmartArtError:
        content = []
        warnings.append(f"Slide {n}: SmartArt detected, skipped")
        continue
    except Exception as e:
        content = []
        errors.append(f"Slide {n}: {str(e)}")
        continue
```

## 対応パターン詳細

### 対応するテキスト型

| パターン | 説明 | 対応 |
|----------|------|------|
| テキストボックス | `TextBox` 型シェイプ | ✅ 完全対応 |
| 図形テキスト | `Shape` 型で `has_text_frame=True` | ✅ 完全対応 |
| 段落・リスト | 複数段落のテキストフレーム | ✅ 完全対応 |
| テーブルセル | `Table` 内のセルテキスト | ✅ 完全対応 |
| 発表者ノート | スライド添付のメモ | ✅ 完全対応 |
| プレースホルダー | スライドレイアウトのプレースホルダー | ✅ 完全対応 |
| SmartArt | 特殊な図形オブジェクト | ❌ 未対応 |

### テーブル抽出の詳細

テーブルはスライド内に複数存在可能。Markdown 形式に変換：

```python
# 抽出前のテーブル構造
|Header 1|Header 2|Header 3|
|--------|--------|--------|
|Data 1-1|Data 1-2|Data 1-3|
|Data 2-1|Data 2-2|Data 2-3|

# 抽出後の Markdown 形式
| Header 1 | Header 2 | Header 3 |
| --- | --- | --- |
| Data 1-1 | Data 1-2 | Data 1-3 |
| Data 2-1 | Data 2-2 | Data 2-3 |
```

### SmartArt が検出された場合

SmartArt（組織図、プロセス図など）は python-pptx で未対応：

```json
{
  "slide_number": 3,
  "content": ["通常のテキスト"],
  "warnings": [
    "SmartArt detected on this slide. Content extraction not supported.",
    "Consider using Aspose.Slides or Spire.Presentation for SmartArt extraction."
  ],
  "smartart_count": 1
}
```

## 設定ファイル使用例

YAML 設定ファイルで複数の設定を管理可能：

### config.yaml

```yaml
# PPTX Text Extractor Configuration

# 入力ファイル
input:
  pptx_paths:
    - "presentations/*.pptx"
    - "docs/archive/*.pptx"
  max_slides: null              # null = 制限なし

# 抽出モード
extraction:
  mode: "rag-compatible"        # basic / full / rag-compatible
  include_tables: true
  include_notes: true
  include_metadata: false

# 出力形式
output:
  format: "json"                # json / text / markdown
  directory: "./results/"
  per_file: false               # true = ファイルごとに分割出力

# ロギング
logging:
  level: "info"                 # debug / info / warning / error
  file: "extraction.log"

# RAG 最適化（rag-compatible モード時）
rag_optimization:
  chunk_text: true              # テキストをチャンク化
  chunk_size: 512               # チャンク単位（トークン）
  overlap: 100                  # オーバーラップ幅
  remove_duplicates: true       # 重複テキスト除去
```

実行：

```bash
python scripts/extract_pptx.py --config config.yaml
```

## 検証・テスト手順

### 1. 基本動作確認

```bash
# テスト PPTX の生成
python -c "
from pptx import Presentation
from pptx.util import Inches, Pt

prs = Presentation()
slide_layout = prs.slide_layouts[0]
slide = prs.slides.add_slide(slide_layout)
title = slide.shapes.title
subtitle = slide.placeholders[1]
title.text = 'Test Slide'
subtitle.text = 'Test Content'
prs.save('test_sample.pptx')
print('Test PPTX created: test_sample.pptx')
"

# 抽出テスト
python scripts/extract_pptx.py \
  --pptx test_sample.pptx \
  --mode basic \
  --output test_output.json

# 結果確認
cat test_output.json
```

### 2. PDF/Word との形式統一確認

RAG-compatible モード出力が PDF/Word 出力と同じスキーマを持つことを確認：

```bash
# PDF 抽出結果と比較
diff <(python -m json.tool pdf_output.json) \
     <(python -m json.tool pptx_output.json) | head -20
```

### 3. 複雑なスライド構造のテスト

```bash
# 複数テーブル、複数テキストボックス、ノート付きの PPTX でテスト
python scripts/extract_pptx.py \
  --pptx complex_presentation.pptx \
  --mode full \
  --output complex_output.json \
  --verbose
```

### 4. メモリ効率テスト

大規模プレゼンテーション（100+ スライド）での処理：

```bash
# メモリ使用量モニタリング
python -u -c "
import psutil
import subprocess
import time

proc = psutil.Process()
start_mem = proc.memory_info().rss / 1024 / 1024

subprocess.run([
    'python', 'scripts/extract_pptx.py',
    '--pptx', 'large_presentation.pptx',
    '--mode', 'rag-compatible',
    '--output', 'large_output.json'
])

end_mem = proc.memory_info().rss / 1024 / 1024
print(f'Memory usage: {start_mem:.1f} MB -> {end_mem:.1f} MB')
"
```

## RAG システムへの統合

### portal での使用例

```python
# portal/tools/document_processor.py の統合例

def process_pptx(pptx_path):
    """PPTX ファイルを RAG 処理"""
    import subprocess
    import json

    # 抽出実行
    result = subprocess.run([
        'python', 'skills/pptx-text-extractor/scripts/extract_pptx.py',
        '--pptx', pptx_path,
        '--mode', 'rag-compatible',
        '--output-format', 'json'
    ], capture_output=True, text=True)

    if result.returncode != 0:
        raise Exception(f"PPTX extraction failed: {result.stderr}")

    # 出力をパース
    output = json.loads(result.stdout)

    # RAG ベクトル化処理（既存の PDF/Word 処理と統一）
    for page in output['pages']:
        # ベクトル化、DB 保存等
        rag_index.add_document(
            content=page['text'],
            source=pptx_path,
            page_num=page['page_number'],
            metadata=page['metadata']
        )
```

## 制約事項・既知の問題

1. **SmartArt 非対応**: 組織図やプロセス図（SmartArt）は抽出不可
   - 代替手段: Aspose.Slides（有料）、Spire.Presentation（有料）
   - 回避策: スライド内テキストが SmartArt に含まれている場合のみ抽出可能

2. **抽出順序の不規則性**: 複数テキストボックスがある場合、
   抽出順序が視覚的な配置と異なる可能性がある
   - 対応予定: 座標情報を使用したソート処理

3. **テーブル結合セル**: 複数行・列に渡る結合セルは構造が崩れる可能性
   - 対応予定: 結合セル情報の追跡

4. **メモリ制限**: 極めて大きなプレゼンテーション（500+ スライド）では
   メモリ不足の可能性
   - 対応策: `--max-slides` オプションで処理単位を分割

5. **文字化け**: 非 UTF-8 エンコーディングの PPTX ファイルでエラーの可能性
   - 回避策: PowerPoint で UTF-8 で保存し直す

## トラブルシューティング

### Q: python-pptx がインストールできない

```bash
# pip の更新
pip install --upgrade pip

# python-pptx のインストール（依存関係指定）
pip install python-pptx>=1.0.0 lxml
```

### Q: ファイルが読み込めない

```bash
# ファイル形式確認
file presentation.pptx

# PPTX は ZIP ファイル。解凍確認
unzip -t presentation.pptx
```

### Q: テーブルが正しく抽出されない

SmartArt ではなく通常テーブルであることを確認：

```bash
python -c "
from pptx import Presentation
prs = Presentation('presentation.pptx')
for slide_idx, slide in enumerate(prs.slides):
    for shape_idx, shape in enumerate(slide.shapes):
        if shape.has_table:
            print(f'Slide {slide_idx}: Table found at shape {shape_idx}')
"
```

### Q: 発表者ノートが抽出されない

ノートが存在することを確認：

```bash
python -c "
from pptx import Presentation
prs = Presentation('presentation.pptx')
for slide_idx, slide in enumerate(prs.slides):
    if slide.has_notes_slide:
        print(f'Slide {slide_idx}: Has notes')
    else:
        print(f'Slide {slide_idx}: No notes')
"
```

## チェックリスト

- [ ] python-pptx インストール済み
- [ ] 対象 PPTX ファイル確認済み
- [ ] 抽出モード選択済み（basic/full/rag-compatible）
- [ ] 出力形式決定済み（json/text/markdown）
- [ ] メモリ容量確認済み
- [ ] 出力先ディレクトリ作成済み
- [ ] 実行ログ出力設定済み
- [ ] エラーハンドリング確認済み
- [ ] RAG 統合の場合は形式統一確認済み
- [ ] テスト実行・動作確認済み

## 参考資料

- [python-pptx 公式ドキュメント](https://python-pptx.readthedocs.io/)
- [ashigaru2 の調査報告](queue/reports/ashigaru2_report.yaml) - 詳細な技術情報
- [regex-bulk-replace スキル](skills/regex-bulk-replace/) - スキル形式の参考
- [portal RAG システム](context/portal.md) - 統合先の詳細
