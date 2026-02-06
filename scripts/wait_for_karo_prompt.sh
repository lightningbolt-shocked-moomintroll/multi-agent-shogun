#!/bin/bash
# 家老のプロンプト表示を待つヘルパー関数
# 用途: コンパクション完了後、確実にプロンプトが表示されるまで待機
#
# 終了コード:
#   0 - プロンプト検出成功
#   1 - タイムアウト

set -e

MAX_ATTEMPTS=20  # 最大20回（200秒）
INTERVAL=10      # 10秒ごとにチェック

echo "⏳ 家老のプロンプト表示を待機中..."

for i in $(seq 1 $MAX_ATTEMPTS); do
  sleep $INTERVAL

  # 家老ウィンドウの履歴30行を取得
  output=$(tmux capture-pane -t multiagent:0 -p -S -30 2>/dev/null || echo "")

  # プロンプト文字列を検出
  if echo "$output" | grep -q "❯"; then
    echo "✓ 家老のプロンプトを検出（$((i*INTERVAL))秒経過）"

    # 最新の出力を表示（デバッグ用）
    echo "--- 最新の出力 ---"
    echo "$output" | tail -10
    echo "----------------"

    exit 0
  fi

  # 進捗表示
  elapsed=$((i*INTERVAL))
  remaining=$(((MAX_ATTEMPTS-i)*INTERVAL))
  echo "  [$i/$MAX_ATTEMPTS] $elapsed秒経過（残り最大${remaining}秒）"
done

# タイムアウト
echo "⚠️ タイムアウト: $((MAX_ATTEMPTS*INTERVAL))秒経過してもプロンプトを検出できませんでした"
echo ""
echo "【対処方法】"
echo "1. 家老ウィンドウ（multiagent:0）を確認してください"
echo "2. Claude Code が応答している場合は、そのまま続行してください"
echo "3. フリーズしている場合は、手動で Ctrl+C → Enter を試してください"
echo ""
echo "家老ウィンドウの確認: tmux select-window -t multiagent:0"

exit 1
