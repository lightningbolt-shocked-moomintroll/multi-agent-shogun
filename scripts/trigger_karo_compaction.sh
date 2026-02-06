#!/bin/bash
# 家老のコンパクションを安全にトリガーし、完了を待つ
#
# 用途:
#   - 家老のコンテキストが枯渇したとき
#   - 将軍が家老に大量の指示を送る前
#
# 終了コード:
#   0 - コンパクション成功
#   1 - 失敗またはタイムアウト

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "🔧 家老のコンパクションを開始します"
echo ""

# 1. 不要な入力をクリア
echo "1/3: 不要な入力をクリア中..."
tmux send-keys -t multiagent:0 C-c
sleep 2

# プロンプトが表示されているか確認
output=$(tmux capture-pane -t multiagent:0 -p -S -10)
if echo "$output" | grep -q "❯"; then
  echo "  ✓ プロンプト確認"
else
  echo "  ⚠️ プロンプトが見えません。Enterを送信します"
  tmux send-keys -t multiagent:0 Enter
  sleep 2
fi

# 2. コンパクション実行
echo "2/3: コンパクション実行中..."
tmux send-keys -t multiagent:0 "/compact" Enter
echo "  ✓ /compact コマンド送信完了"
echo ""

# 3. 完了を待つ
echo "3/3: コンパクション完了を待機中..."
if "$SCRIPT_DIR/wait_for_karo_prompt.sh"; then
  echo ""
  echo "✅ 家老のコンパクションが完了しました"

  # コンテキスト残量を確認（あれば表示）
  context_info=$(tmux capture-pane -t multiagent:0 -p -S -30 | grep -i "context" || echo "")
  if [ -n "$context_info" ]; then
    echo "📊 コンテキスト残量: $context_info"
  fi

  exit 0
else
  echo ""
  echo "❌ 家老のコンパクションがタイムアウトしました"
  echo ""
  echo "【推奨アクション】"
  echo "1. 家老ウィンドウを確認: tmux select-window -t multiagent:0"
  echo "2. 必要に応じて手動でコンパクションを完了させてください"
  echo "3. dashboard.md に状況を記録してください"

  exit 1
fi
