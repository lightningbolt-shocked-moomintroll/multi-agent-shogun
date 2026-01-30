# 🔐 multi-agent-shogun 権限管理ガイド

## 概要

multi-agent-shogun v2.0 では、セキュリティ強化のため権限確認モードがデフォルトになりました。
エージェントが特定の操作を実行する際、ユーザーに確認を求めます。

## 権限の種類

### 1. 自動許可 (Allow)
確認なしで実行される操作。`.claude/settings.json` の `allow` リストに定義。

### 2. 自動拒否 (Deny)
常にブロックされる操作。`.claude/settings.json` の `deny` リストに定義。

### 3. 確認必要
上記以外の操作。実行時にユーザーに確認を求めます。

## ユーザー確認時の選択肢

エージェントが許可リストにない操作を実行しようとすると、以下の選択肢が表示されます：

| 選択 | 説明 |
|------|------|
| `y` | 今回のみ許可 |
| `n` | 拒否 |
| `a` | 常に許可（設定に追加） |
| `d` | 常に拒否（設定に追加） |

## 権限設定ファイル

### 場所
```
.claude/settings.json
```

### 構造
```json
{
  "permissions": {
    "allow": [
      "Bash(date:*)",
      "Bash(tmux send-keys:*)",
      "Read(*)",
      "Write(queue/*)"
    ],
    "deny": [
      "Bash(rm -rf /*)",
      "Bash(sudo:*)",
      "Write(~/.ssh/*)"
    ]
  }
}
```

## パターン記法

### Bash コマンド
```
Bash(コマンド:引数パターン)

例:
Bash(npm:*)        - npm の全コマンド
Bash(git:*)        - git の全コマンド
Bash(rm -rf:*)     - rm -rf の全パターン（危険）
```

### ファイル操作
```
Read(パスパターン)
Write(パスパターン)
Edit(パスパターン)

例:
Read(*)            - 全ファイル読み込み
Write(src/*)       - src/ 以下への書き込み
Edit(*.md)         - Markdownファイルの編集
```

### ワイルドカード
- `*` - 任意の文字列にマッチ
- パスは相対パスまたは絶対パスで指定

## 権限管理スクリプト

### 対話モード
```bash
./scripts/manage_permissions.sh
```

### コマンドラインオプション
```bash
# 現在の権限を表示
./scripts/manage_permissions.sh --list

# 許可ルールを追加
./scripts/manage_permissions.sh --add-allow "Bash(npm:*)"

# 拒否ルールを追加
./scripts/manage_permissions.sh --add-deny "Bash(rm -rf:*)"

# 許可ルールを削除
./scripts/manage_permissions.sh --remove-allow "Bash(npm:*)"

# デフォルトにリセット
./scripts/manage_permissions.sh --reset
```

## デフォルト設定

### 自動許可される操作

| カテゴリ | 操作 |
|---------|------|
| 基本コマンド | `date`, `pwd`, `ls`, `cat`, `head`, `tail`, `wc` |
| tmux 操作 | `send-keys`, `capture-pane`, `display-message`, `list-*` |
| ファイル読み込み | すべてのファイル |
| キュー書き込み | `queue/*`, `status/*`, `config/*` |
| ダッシュボード | `dashboard.md` |
| メモリ | `memory/*` |

### 自動拒否される操作

| カテゴリ | 操作 | 理由 |
|---------|------|------|
| 危険な削除 | `rm -rf /`, `rm -rf ~/` | システム破壊防止 |
| 権限変更 | `chmod 777` | セキュリティリスク |
| 特権昇格 | `sudo`, `su` | 意図しない権限昇格防止 |
| 機密ファイル | `~/.ssh/*`, `~/.aws/*` | 認証情報保護 |

## 推奨設定

### 開発プロジェクト向け
```bash
# 開発用コマンドを許可
./scripts/manage_permissions.sh --add-allow "Bash(npm:*)"
./scripts/manage_permissions.sh --add-allow "Bash(git:*)"
./scripts/manage_permissions.sh --add-allow "Bash(node:*)"
./scripts/manage_permissions.sh --add-allow "Write(src/*)"
./scripts/manage_permissions.sh --add-allow "Edit(src/*)"
```

### 最小権限モード
```bash
# リセットしてデフォルトのみ使用
./scripts/manage_permissions.sh --reset
```

## トラブルシューティング

### 頻繁に確認が出る場合
よく使うコマンドを許可リストに追加してください：
```bash
./scripts/manage_permissions.sh  # 対話モードで追加
```

### 権限設定が効かない場合
1. `.claude/settings.json` の JSON 構文を確認
2. パターンの記法を確認（Bash, Read, Write, Edit）
3. ワイルドカードの位置を確認

### 設定を初期化したい場合
```bash
./scripts/manage_permissions.sh --reset
```

## セキュリティに関する注意

1. **過度な許可は避ける**: `Bash(*)` のような広範な許可は危険です
2. **定期的な見直し**: 不要になった許可は削除してください
3. **deny リストを活用**: 絶対に実行させたくない操作を明示的に拒否
4. **チーム共有**: `.claude/settings.json` はバージョン管理に含まれます

## ディレクトリアクセス制限

### 概要
エージェントはプロジェクトディレクトリ外へのアクセスが制限されています。
これにより、意図しないファイルアクセスや機密情報の漏洩を防ぎます。

### 許可されたディレクトリ

#### 読み書き可能
| ディレクトリ | 用途 |
|-------------|------|
| `queue/` | タスク・報告キュー |
| `status/` | ステータス管理 |
| `config/` | 設定ファイル |
| `memory/` | Memory MCP データ |
| `logs/` | ログファイル |
| `demo_output/` | 成果物出力 |

#### 読み取りのみ
| ディレクトリ | 用途 |
|-------------|------|
| `instructions/` | エージェント指示書 |
| `context/` | プロジェクトコンテキスト |
| `templates/` | テンプレート |
| `scripts/` | ユーティリティスクリプト |
| `docs/` | ドキュメント |
| `skills/` | スキル定義 |

### 禁止されたアクセス

| パターン | 説明 | 理由 |
|---------|------|------|
| `/*` | 絶対パス | システムファイル保護 |
| `~/*` | ホームディレクトリ | 個人情報保護 |
| `../*` | ディレクトリトラバーサル | サンドボックス脱出防止 |
| `**/.env` | 環境変数ファイル | 機密情報保護 |
| `**/.ssh/*` | SSH鍵 | 認証情報保護 |
| `**/.aws/*` | AWS認証情報 | クラウド認証情報保護 |
| `**/credentials*` | 認証情報ファイル | 機密情報保護 |
| `**/secrets*` | シークレットファイル | 機密情報保護 |

### ディレクトリ制限の管理

```bash
# 現在の設定を表示
./scripts/manage_permissions.sh --show-dirs

# 制限の有効/無効切り替え
./scripts/manage_permissions.sh --toggle-dirs

# 許可ディレクトリを追加
./scripts/manage_permissions.sh --add-dir src

# パスの検証
./scripts/validate_path.sh queue/tasks/test.yaml --write
```

### 外部プロジェクトへのアクセス

外部プロジェクトへのアクセスが必要な場合：

```bash
# 特定のプロジェクトを許可
./scripts/manage_permissions.sh --add-external "/path/to/project/*"

# 対話モードで追加
./scripts/manage_permissions.sh
# → 0) 外部プロジェクトへのアクセスを許可
```

### パス検証スクリプト

```bash
# 基本的な使用
./scripts/validate_path.sh <path> [--read|--write|--edit]

# 例
./scripts/validate_path.sh queue/tasks/ashigaru1.yaml --read   # ✅ 許可
./scripts/validate_path.sh /etc/passwd --read                   # ❌ 拒否
./scripts/validate_path.sh ../secret.txt --read                 # ❌ 拒否

# 許可リスト表示
./scripts/validate_path.sh --list

# バッチ検証
./scripts/validate_path.sh --batch write file1.md file2.md
```

---

## 入力サニタイズ

### 概要
tmux send-keys に渡す入力はコマンドインジェクションの危険があります。
外部入力を含む場合は必ずサニタイズしてください。

### 危険なパターン
| パターン | 説明 | 危険性 |
|---------|------|--------|
| \`command\` | バッククォート | コマンド実行 |
| `$(command)` | コマンド置換 | コマンド実行 |
| `${variable}` | 変数展開 | 情報漏洩 |
| `|` | パイプ | 出力リダイレクト |
| `;` | セミコロン | コマンド連結 |
| `&&`, `\|\|` | 論理演算子 | コマンド連結 |
| `>`, `<` | リダイレクト | ファイル操作 |

### 安全な送信方法

```bash
# 方法1: safe_send_keys.sh を使用（推奨）
./scripts/safe_send_keys.sh multiagent:0 "メッセージ"

# 方法2: 厳格モード（より多くの文字を除去）
./scripts/safe_send_keys.sh --strict multiagent:0 "メッセージ"

# 方法3: 手動でサニタイズ
source ./scripts/sanitize_input.sh
sanitized=$(sanitize_for_tmux "$raw_input")
tmux send-keys -t multiagent:0 "$sanitized"
tmux send-keys -t multiagent:0 Enter
```

### サニタイズ関数

| 関数 | 説明 |
|------|------|
| `sanitize_for_tmux` | 基本的なサニタイズ |
| `sanitize_strict` | 厳格なサニタイズ（より多くの文字を除去） |
| `validate_input` | 危険なパターンの検出 |
| `validate_yaml_path` | YAMLパスの検証 |

### 検証のみ実行
```bash
# 実際に送信せずに検証
./scripts/safe_send_keys.sh --validate multiagent:0 "テスト入力"
```

## 関連ファイル

- `.claude/settings.json` - 権限設定
- `scripts/manage_permissions.sh` - 権限管理スクリプト
- `scripts/safe_send_keys.sh` - 安全な send-keys ラッパー
- `scripts/sanitize_input.sh` - サニタイズユーティリティ
- `.gitignore` - `.claude/settings.json` は共有される設定

## 旧バージョンからの移行

v1.x では `--dangerously-skip-permissions` フラグを使用していました。
v2.0 では権限確認モードがデフォルトです。

移行手順：
1. `./first_setup.sh` を再実行
2. 必要な権限を `./scripts/manage_permissions.sh` で追加
3. 動作確認
