# セキュリティ監査レポート

> **対象**: {{PROJECT_NAME}}
> **日時**: {{TIMESTAMP}}
> **監査者**: {{AUDITOR}}
> **スコープ**: {{SCOPE}}

---

## 総合評価

| 評価項目 | 結果 |
|----------|------|
| 総合リスクレベル | {{RISK_LEVEL}} |
| 重大な問題 | {{CRITICAL_COUNT}}件 |
| 高リスク問題 | {{HIGH_COUNT}}件 |
| 中リスク問題 | {{MEDIUM_COUNT}}件 |
| 低リスク問題 | {{LOW_COUNT}}件 |

---

## 重大なリスク

{{#CRITICAL_ISSUES}}
### {{INDEX}}. {{TITLE}}

**場所**: `{{LOCATION}}`

**問題**:
```
{{CODE_SNIPPET}}
```

**リスク**: {{RISK_DESCRIPTION}}

**推奨対策**: {{RECOMMENDATION}}

---
{{/CRITICAL_ISSUES}}

## カテゴリ別リスク詳細

### 権限過剰 (Permissions)

| 問題 | 場所 | リスク | 状態 |
|------|------|--------|------|
{{#PERMISSION_ISSUES}}
| {{TITLE}} | `{{LOCATION}}` | {{RISK_LEVEL}} | {{STATUS}} |
{{/PERMISSION_ISSUES}}

### 機密情報 (Secrets)

| 問題 | 場所 | リスク | 状態 |
|------|------|--------|------|
{{#SECRET_ISSUES}}
| {{TITLE}} | `{{LOCATION}}` | {{RISK_LEVEL}} | {{STATUS}} |
{{/SECRET_ISSUES}}

### インジェクション脆弱性 (Injection)

| 問題 | 場所 | リスク | 状態 |
|------|------|--------|------|
{{#INJECTION_ISSUES}}
| {{TITLE}} | `{{LOCATION}}` | {{RISK_LEVEL}} | {{STATUS}} |
{{/INJECTION_ISSUES}}

### ファイルアクセス (File Access)

| 問題 | 場所 | リスク | 状態 |
|------|------|--------|------|
{{#FILE_ACCESS_ISSUES}}
| {{TITLE}} | `{{LOCATION}}` | {{RISK_LEVEL}} | {{STATUS}} |
{{/FILE_ACCESS_ISSUES}}

### ネットワーク (Network)

| 問題 | 場所 | リスク | 状態 |
|------|------|--------|------|
{{#NETWORK_ISSUES}}
| {{TITLE}} | `{{LOCATION}}` | {{RISK_LEVEL}} | {{STATUS}} |
{{/NETWORK_ISSUES}}

---

## 権限付与の評価

| カテゴリ | 現状 | リスク | 推奨 |
|----------|------|--------|------|
{{#PERMISSION_EVAL}}
| {{CATEGORY}} | {{CURRENT}} | {{RISK}} | {{RECOMMENDED}} |
{{/PERMISSION_EVAL}}

---

## 推奨対策

### 即座に対処すべき事項

{{#IMMEDIATE_ACTIONS}}
{{INDEX}}. **{{TITLE}}**
   - 問題: {{PROBLEM}}
   - 対策: {{SOLUTION}}
{{/IMMEDIATE_ACTIONS}}

### 中期的な改善

{{#MEDIUM_TERM_ACTIONS}}
{{INDEX}}. **{{TITLE}}**
   - 問題: {{PROBLEM}}
   - 対策: {{SOLUTION}}
{{/MEDIUM_TERM_ACTIONS}}

### 長期的な検討事項

{{#LONG_TERM_ACTIONS}}
{{INDEX}}. **{{TITLE}}**
   - 問題: {{PROBLEM}}
   - 対策: {{SOLUTION}}
{{/LONG_TERM_ACTIONS}}

---

## セキュリティ上の良い点

{{#GOOD_PRACTICES}}
| 項目 | 説明 |
|------|------|
| {{TITLE}} | {{DESCRIPTION}} |
{{/GOOD_PRACTICES}}

---

## 結論

{{CONCLUSION}}

### 本番環境での使用

| 評価項目 | 判定 |
|----------|------|
| 現在の状態 | {{PRODUCTION_READY}} |
| 必要な対策 | {{REQUIRED_ACTIONS}} |

---

## 付録

### 使用したチェック項目

- [{{PERM_CHECK}}] 権限過剰チェック
- [{{SECRET_CHECK}}] 機密情報チェック
- [{{INJECTION_CHECK}}] インジェクション脆弱性チェック
- [{{FILE_CHECK}}] ファイルアクセスチェック
- [{{NETWORK_CHECK}}] ネットワークセキュリティチェック
- [{{DEP_CHECK}}] 依存関係チェック

### 免責事項

本レポートはコード静的解析に基づくものであり、すべてのセキュリティリスクを網羅するものではありません。
本番環境での使用前には、専門家によるレビューおよび動的テストを推奨します。
