# RAG Document Format Analyzer - 実行時プロンプト

## Overview

このスキルは、RAGシステムに新しいドキュメント形式を追加する際の事前調査を体系的に実施する。
対象形式のテキスト抽出可能性、既存パイプラインとの統合方法、実装難易度を評価し、
実装判断の根拠となるレポートを生成する。

**対象プロジェクト例**: portal（Flask + RAG）

---

## 調査の5つのレイヤー

### Layer 1: 対応形式確認
- 現在対応しているファイル形式
- 処理フロー全体の把握
- 各形式のテキスト抽出方法

### Layer 2: 対象形式の調査
- テキスト抽出の実現可能性
- 対応ライブラリの比較
- メリット・デメリット分析

### Layer 3: ライブラリ選定
- Python標準ライブラリの確認
- 推奨される外部ライブラリ
- ライセンス・メンテナンス状況

### Layer 4: 実装設計
- 既存コードへの統合点
- 修正対象ファイルのリストアップ
- チャンク分割戦略の検討

### Layer 5: リスク・工数評価
- 実装難易度（🟢低/🟡中/🔴高）
- リスク要因と対策
- 段階的実装の提案

---

## 実行フロー: 5ステップ

### STEP 1: 現行システムの把握（15-30分）

**チェックリスト**:
- [ ] app.py の ALLOWED_EXTENSIONS を確認
- [ ] app.py のテキスト抽出関数一覧（extract_text_from_*）を抽出
- [ ] tools/ の バッチ処理スクリプトを確認
- [ ] database.py の RAG関連テーブルスキーマを確認
- [ ] 処理フロー図を描画

**出力ファイル**:
- `current_formats.txt` - 対応形式一覧
- `processing_flow_diagram.mmd` - 処理フロー図

**参考コマンド**:
```bash
# app.py の拡張子チェック
grep -n "ALLOWED_EXTENSIONS" app.py

# テキスト抽出関数の一覧
grep -n "^def extract_text_from_" app.py

# バッチスクリプト一覧
ls -la tools/bulk_*.py tools/reindex_*.py
```

---

### STEP 2: 対象形式の可能性調査（30-60分）

**調査項目**:

#### 2.1 テキスト抽出可能性
```
質問:
- このファイル形式からテキストを抽出できる Python ライブラリが存在するか？
- テキスト以外（表、画像、メタデータ）の抽出は？
- 複雑な階層構造はどう処理するか？
```

#### 2.2 Python ライブラリの比較
```yaml
# テンプレート例
libraries:
  option_1:
    name: "python-pptx"
    url: "https://github.com/scanny/python-pptx"
    version_latest: "1.0.0"
    installation: "pip install python-pptx"
    pros:
      - テキスト抽出が容易
      - メンテナンスが活発
    cons:
      - SmartArt未対応
    learning_curve: "低い（30分で習得可能）"
    confidence: "HIGH"

  option_2:
    name: "（代替案があれば）"
```

#### 2.3 抽出パターン分析
```
現行の PDF/Word パターンから学ぶ:
├── テキスト層: 段落、見出し、本文
├── 構造層: ページ番号、セクション、階層
├── メタデータ層: 作成者、更新日、サイズ
└── 例外処理: 破損ファイル、古い形式、エンコード問題
```

**出力ファイル**:
- `target_format_analysis.md` - 形式特性、抽出パターン
- `library_comparison_table.md` - ライブラリ比較表

---

### STEP 3: ライブラリ検証とサンプルコード（1-2時間）

**実施項目**:

#### 3.1 ライブラリのインストール確認
```bash
pip install python-pptx  # 例
python -c "import pptx; print(pptx.__version__)"
```

#### 3.2 サンプル抽出コードの作成
```python
# template: extract_text_from_<format>.py

def extract_text_from_pptx(pptx_path):
    """PowerPointファイルからテキストを抽出"""
    from pptx import Presentation

    prs = Presentation(pptx_path)
    extracted = []

    for slide_idx, slide in enumerate(prs.slides, 1):
        slide_content = {
            'slide_number': slide_idx,
            'text': [],
            'tables': []
        }

        # テキスト抽出
        for shape in slide.shapes:
            if shape.has_text_frame:
                text = shape.text_frame.text.strip()
                if text:
                    slide_content['text'].append(text)

            # 表抽出（あれば）
            if shape.has_table:
                table = shape.table
                table_data = []
                for row in table.rows:
                    row_data = [cell.text.strip() for cell in row.cells]
                    table_data.append(row_data)
                slide_content['tables'].append(table_data)

        if slide_content['text'] or slide_content['tables']:
            extracted.append(slide_content)

    return extracted
```

#### 3.3 既存コードとの互換性確認
```
チェック項目:
- [ ] 抽出結果の形式: テキスト文字列のリスト
- [ ] エラーハンドリング: try-except ブロック必須
- [ ] エンコード対応: UTF-8, Shift-JIS等
- [ ] チャンク化対応: 既存の split_text_into_chunks() で処理可能か
- [ ] ベクトル化対応: VectorStorePreparation で処理可能か
```

**出力ファイル**:
- `sample_extraction_code.py` - 動作確認済みサンプルコード
- `compatibility_checklist.md` - 互換性確認結果

---

### STEP 4: 実装統合計画（1-2時間）

**修正対象ファイルのマッピング**:

```yaml
修正ファイル:
  app.py:
    - ALLOWED_EXTENSIONS に '.pptx' を追加
    - extract_text_from_pptx() 関数を実装
    - 既存のテキスト抽出分岐に pptx ケースを追加

  tools/bulk_rag_upload.py:
    - SUPPORTED_EXTENSIONS に '.pptx' を追加
    - extract_text_from_pptx() を呼び出す分岐追加

  tools/reindex_rag_from_uploaded_files.py:
    - 同上

  database.py:
    - スキーマ変更: 不要（既存の file_type カラムで対応）
    - get_file_icon() の pptx 対応: 確認（多くの場合既実装）

  requirements.txt:
    - python-pptx >= 1.0.0 を追加
```

**段階的実装プラン**:

| フェーズ | 内容 | 工数 | リスク |
|---------|------|------|--------|
| Phase 1 | サンプル実装 + テスト | 2-4時間 | 低 |
| Phase 2 | app.py へのマージ | 1-2時間 | 低 |
| Phase 3 | バッチスクリプト対応 | 1-2時間 | 低 |
| Phase 4 | 本番環境テスト | 1-2時間 | 中 |

**出力ファイル**:
- `implementation_roadmap.md` - 実装手順書
- `integration_checklist.md` - 統合チェックリスト

---

### STEP 5: リスク評価と工数見積もり（30-60分）

**難易度評価基準**:

```
🟢 低（1-2時間）:
  ✓ テキスト抽出が簡単なAPI
  ✓ 複雑な処理が不要
  ✓ 既存コードとの統合が直線的
  例: PDFテキスト抽出（pdfplumber）

🟡 中（2-4時間）:
  ✓ テキスト抽出が複数ステップ
  ✓ 表や図表の処理が必要
  ✓ エラーハンドリングが複雑
  例: PowerPoint対応（python-pptx）、Word対応

🔴 高（4時間以上）:
  ✓ テキスト抽出自体が難しい
  ✓ OCR等の機械学習が必要
  ✓ フォーマット仕様が複雑
  例: SmartArt処理、画像内テキスト処理
```

**リスク要因と対策マトリックス**:

| リスク | 確率 | 影響 | 対策 |
|--------|------|------|------|
| エンコード問題 | 中 | 中 | UTF-8変換関数を実装 |
| 複雑な構造での情報損失 | 中 | 低 | メタデータを補足情報として保持 |
| RAG検索精度低下 | 低 | 中 | チャンク化戦略を工夫 |
| パフォーマンス低下 | 低 | 中 | 大規模ファイル時の処理時間計測 |

**出力ファイル**:
- `difficulty_assessment.md` - 難易度評価書
- `risk_analysis.md` - リスク分析と対策

---

## 実際の実行例: PPTX対応調査

### 例：Quick Scan（30分）

```bash
# Step 1: 現行形式の確認
grep -n "ALLOWED_EXTENSIONS\|extract_text_from_" /mnt/c/var/worktree/portal/app.py

# Step 2: PPTX対応可能性の判定
python3 << 'EOF'
# python-pptx が利用可能か確認
try:
    import pptx
    print("✓ python-pptx available")
except ImportError:
    print("✗ python-pptx not installed")
EOF

# Step 3: サンプルテスト（実際のPPTXファイルで動作確認）
# （テストファイルがあれば実施）

# Step 4: 簡易難易度判定
# python-pptx は良くメンテナンスされており、
# テキスト抽出API が十分に整備されている → 難易度: 低
```

### 結論（Quick Scan）
```
形式: PowerPoint (.pptx)
判定: 対応推奨
難易度: 🟢 低（1-2時間で実装可能）
ライブラリ: python-pptx >= 1.0.0
リスク: 低～中程度
```

---

## 報告書テンプレート

```yaml
skill_design: rag-document-format-analyzer

analysis_metadata:
  project: portal
  target_format: pptx
  scan_date: "2026-02-04"
  scan_type: "standard-analysis"
  analyst: "ashigaru6"

1_current_state:
  supported_formats:
    - txt
    - pdf
    - docx
    - doc
  processing_pipeline: |
    [Diagram of current flow]

2_target_format_analysis:
  format_name: "PowerPoint"
  format_extension: ".pptx"
  text_extraction_feasibility: "✓ High"
  recommended_library: "python-pptx"
  library_maturity: "Stable (v1.0.0+)"

3_implementation_guide:
  new_functions:
    - name: "extract_text_from_pptx()"
      location: "app.py"
      complexity: "🟢 Low"

  modified_functions:
    - name: "process_rag_file()"
      changes: "Add elif ext == '.pptx' branch"

  schema_changes: "❌ None required"

4_difficulty_assessment:
  overall: "🟢 Low (1-2 hours)"
  phases:
    - Phase 1: "Sample code: 30 min"
    - Phase 2: "Integration: 1 hour"
    - Phase 3: "Testing: 30 min"

5_risks_and_mitigation:
  - risk: "SmartArt objects not supported"
    probability: "Low"
    mitigation: "Document limitation, handle gracefully"

  - risk: "Performance on large presentations"
    probability: "Low"
    mitigation: "Pre-test with 100+ slide presentation"

recommendation: "推奨: 対応実装"
```

---

## チェックリスト（実行時）

スキル実行時に以下を確認すること：

**調査の準備**:
- [ ] 対象プロジェクトのパスが正しい
- [ ] git status で汚れていない（新しい調査は新しいブランチで）
- [ ] インターネット接続がある（ライブラリドキュメント確認用）

**STEP 1-2 の確認**:
- [ ] 現行形式の処理フロー図が作成できた
- [ ] 対象形式のテキスト抽出方法を2つ以上見つけた
- [ ] ライブラリの選定理由が明確

**STEP 3 の確認**:
- [ ] サンプルコードが実装できた
- [ ] 既存コードとの互換性が確認できた
- [ ] エラーハンドリングが実装されている

**STEP 4 の確認**:
- [ ] 修正対象ファイルが明確にリストアップされた
- [ ] 段階的実装計画が立てられた
- [ ] スキーマ変更の必要性が判定された

**STEP 5 の確認**:
- [ ] 難易度評価が根拠付きで記述されている
- [ ] リスク要因が5件以上列挙されている
- [ ] 推奨（実装すべき/スキップ）が明示されている

**出力形式の確認**:
- [ ] 報告書が YAML 形式で queue/reports/ashigaru{N}_report.yaml に保存
- [ ] サンプルコードが demo_output/ に保存
- [ ] 実装ロードマップが .md 形式で保存

---

## スキル化のメリット

このスキルが汎用化できる理由：

1. **パターンの再利用性**:
   - PDF/Word 調査と同じパターンで XLSX, CSV, JSON 等にも適用可能

2. **他プロジェクトへの応用**:
   - portal 以外でもドキュメント処理が必要なプロジェクトで使用可能
   - SAP, Slack, Salesforce等の API 連携調査にも転用可能

3. **段階的実装の原則**:
   - 調査だけで実装は別タスクに分離可能
   - 新しいメンバーのオンボーディングにも活用可能

4. **知識の蓄積**:
   - Memory MCP に蓄積され、同じ形式の調査が必要な際に検索可能
