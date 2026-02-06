# Security Audit - 実行時プロンプト

## Overview

このスキルはコードベースのセキュリティ監査を体系的に実施する。
権限過剰、情報漏洩、インジェクション脆弱性などのリスクを評価し、
優先度付きの推奨対策を含むレポートを生成する。

## 監査手順

### Step 1: コードベース構造の把握

まずプロジェクト全体の構造を理解する：

```bash
# ディレクトリ構造
find . -type f -name "*.py" -o -name "*.js" -o -name "*.sh" | head -50

# 設定ファイルの存在確認
ls -la *.yaml *.json *.toml .env* 2>/dev/null
```

確認事項：
- 主要な言語・フレームワーク
- エントリーポイント（main.py, app.py, index.js等）
- 設定ファイルの場所
- スクリプト類の有無

### Step 2: カテゴリ別セキュリティチェック

#### A. 権限過剰チェック (Permissions)

```bash
# 危険なフラグの使用
grep -rn "dangerously-skip" --include="*.sh" --include="*.md" .
grep -rn "sudo" --include="*.sh" .
grep -rn "chmod 777" --include="*.sh" .

# ワイルドカード権限
grep -rn '"\*"' --include="*.json" .
grep -rn "Read(\*)" --include="*.json" .
grep -rn "Write(\*)" --include="*.json" .

# 管理者権限の要求
grep -rn "Administrator\|root\|net session" --include="*.sh" --include="*.bat" .
```

**リスク評価基準：**
| パターン | リスク | 説明 |
|----------|--------|------|
| `--dangerously-skip-permissions` | Critical | 全権限バイパス |
| `sudo` (対話的) | High | 権限昇格 |
| `chmod 777` | High | 過剰なファイル権限 |
| ワイルドカード権限 | Medium | 無制限アクセス |

#### B. 機密情報チェック (Secrets)

```bash
# ハードコードされた認証情報
grep -rn "password\s*=\s*['\"]" --include="*.py" --include="*.js" .
grep -rn "api_key\s*=\s*['\"]" --include="*.py" --include="*.js" .
grep -rn "secret\s*=\s*['\"]" --include="*.py" --include="*.js" .

# トークン・キーのパターン
grep -rn "sk-[a-zA-Z0-9]\{20,\}" .
grep -rn "ghp_[a-zA-Z0-9]\{36\}" .
grep -rn "xox[baprs]-[a-zA-Z0-9]\{10,\}" .

# 環境変数の直接使用（コマンドラインで露出）
grep -rn "TOKEN=\|KEY=\|SECRET=" --include="*.sh" .

# .gitignore の確認
cat .gitignore | grep -E "\.env|secret|credential|key"
```

**リスク評価基準：**
| パターン | リスク | 説明 |
|----------|--------|------|
| ハードコードされたパスワード | Critical | 即座に露出 |
| APIキーのハードコード | Critical | サービス悪用リスク |
| トークンのコミット | High | 履歴に残存 |
| 環境変数のログ出力 | Medium | ログ経由で露出 |

#### C. インジェクション脆弱性 (Injection)

```bash
# コマンドインジェクション
grep -rn "os.system\|subprocess.call\|subprocess.run" --include="*.py" .
grep -rn "exec(\|eval(" --include="*.py" --include="*.js" .
grep -rn "shell=True" --include="*.py" .

# SQLインジェクション
grep -rn "execute.*%s\|execute.*format\|execute.*f\"" --include="*.py" .
grep -rn "query.*\+.*\|\`.*\$" --include="*.js" .

# XSS
grep -rn "innerHTML\|dangerouslySetInnerHTML\|v-html" --include="*.js" --include="*.vue" .

# tmux send-keys（未サニタイズ入力）
grep -rn "send-keys.*\$" --include="*.sh" .
```

**リスク評価基準：**
| パターン | リスク | 説明 |
|----------|--------|------|
| `eval()` + ユーザー入力 | Critical | 任意コード実行 |
| `shell=True` + 外部入力 | Critical | コマンドインジェクション |
| SQL文字列連結 | High | SQLインジェクション |
| `innerHTML` | Medium | XSS（コンテキスト依存） |

#### D. ファイルアクセスチェック (File Access)

```bash
# ディレクトリトラバーサル
grep -rn "\.\./" --include="*.py" --include="*.js" .
grep -rn "path.join.*\.\." --include="*.py" --include="*.js" .

# 機密ファイルアクセス
grep -rn "/etc/passwd\|/etc/shadow\|\.ssh/\|\.aws/" .

# ファイルパスの動的生成
grep -rn "open(.*\+\|open(f\"" --include="*.py" .
```

#### E. ネットワークセキュリティ (Network)

```bash
# 安全でない通信
grep -rn "http://" --include="*.py" --include="*.js" . | grep -v "localhost\|127.0.0.1"

# CORS設定
grep -rn "Access-Control-Allow-Origin.*\*" .
grep -rn "CORS.*origin.*True" --include="*.py" .

# 公開バインド
grep -rn "0.0.0.0\|host='0.0.0.0'" --include="*.py" .
```

#### F. 依存関係チェック (Dependencies)

```bash
# 古い依存関係の確認
pip list --outdated 2>/dev/null | head -20
npm outdated 2>/dev/null | head -20

# 脆弱性スキャン（利用可能な場合）
pip-audit 2>/dev/null || echo "pip-audit not available"
npm audit 2>/dev/null || echo "npm audit not available"
```

### Step 3: レポート生成

#### リスクレベル判定基準

| レベル | 条件 |
|--------|------|
| Critical | 権限バイパス、ハードコード認証情報、任意コード実行 |
| High | 権限昇格、インジェクション脆弱性、機密ファイルアクセス |
| Medium | 過剰な権限、安全でない通信、XSSリスク |
| Low | ベストプラクティス違反、古い依存関係 |
| Safe | 重大なリスクなし |

#### レポート構成

```markdown
# セキュリティ監査レポート

## 概要
- 対象: {project_name}
- 日時: {timestamp}
- 総合評価: {risk_level}

## 重大なリスク
（Critical/Highの問題を列挙）

## リスク詳細
（カテゴリ別の問題一覧）

## 権限評価表
（現状 vs 推奨の比較表）

## 推奨対策
### 即座に対処すべき事項
### 中期的な改善
### 長期的な検討事項

## 良い点
（セキュリティ上の好ましい実装）

## 結論
```

### Step 4: 推奨対策の提示

問題ごとに具体的な修正方法を提示：

```python
# Before (リスク)
os.system(f"echo {user_input}")

# After (修正後)
import shlex
subprocess.run(["echo", shlex.quote(user_input)])
```

## スコープ別実行

### quick (クイック監査)

最小限のチェックで素早く評価：

```
- 危険なフラグの使用
- ハードコードされた認証情報
- .gitignore の確認
```

### permissions (権限監査)

権限関連に特化：

```
- 危険なフラグ
- sudo/root使用
- ファイル権限
- ワイルドカード権限
```

### secrets (機密情報監査)

機密情報漏洩に特化：

```
- ハードコードされた認証情報
- APIキー/トークン
- 環境変数の取り扱い
- .gitignoreの設定
```

### injection (インジェクション監査)

インジェクション脆弱性に特化：

```
- コマンドインジェクション
- SQLインジェクション
- XSS
- 入力サニタイズ
```

### full (完全監査)

全カテゴリを網羅的にチェック。

## チェックリスト

- [ ] コードベース構造を把握した
- [ ] 権限過剰チェックを実施した
- [ ] 機密情報チェックを実施した
- [ ] インジェクション脆弱性チェックを実施した
- [ ] ファイルアクセスチェックを実施した
- [ ] ネットワークセキュリティチェックを実施した
- [ ] 依存関係チェックを実施した
- [ ] リスクレベルを判定した
- [ ] 推奨対策を優先度付きで提示した
- [ ] レポートを生成した

## 注意事項

- 本監査はコード静的解析に基づく。動的テスト（ペネトレーションテスト）は含まない
- 誤検知の可能性あり。検出結果は文脈を考慮して評価すること
- 依存関係の脆弱性スキャンには専用ツール（pip-audit, npm audit等）の併用を推奨
- 本番環境での使用前には、専門家によるレビューを推奨
