#!/bin/bash
# トークン使用量の分析スクリプト

set -euo pipefail

LOG_FILE="logs/token_usage.csv"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "トークン使用量分析"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ファイル存在チェック
if [ ! -f "$LOG_FILE" ]; then
  echo "❌ ログファイルが見つかりません: $LOG_FILE"
  echo "   logs/token_usage.csv を作成してください。"
  exit 1
fi

# データ行数チェック（ヘッダーを除く）
DATA_COUNT=$(tail -n +2 "$LOG_FILE" | wc -l)
if [ "$DATA_COUNT" -eq 0 ]; then
  echo "⚠️  ログファイルにデータがありません。"
  echo "   タスク実行後にトークン使用量を記録してください。"
  exit 0
fi

echo "📊 データ行数: $DATA_COUNT 件"
echo ""

# ベースライン期間（Memory導入前）
BASELINE_START=${BASELINE_START:-"2026-02-03"}
BASELINE_END=${BASELINE_END:-"2026-02-10"}

# Phase 1 期間（Memory導入後）
PHASE1_START=${PHASE1_START:-"2026-02-11"}
PHASE1_END=${PHASE1_END:-"2026-02-18"}

echo "期間設定:"
echo "  ベースライン: $BASELINE_START 〜 $BASELINE_END"
echo "  Phase 1:      $PHASE1_START 〜 $PHASE1_END"
echo ""

# ベースライン平均（足軽のみ）
BASELINE_AVG=$(awk -F, -v start="$BASELINE_START" -v end="$BASELINE_END" \
  '$1 >= start && $1 <= end && $3 ~ /^ashigaru/ {sum+=$5; count++} \
  END {if(count>0) printf "%.0f", sum/count; else print 0}' "$LOG_FILE")

BASELINE_COUNT=$(awk -F, -v start="$BASELINE_START" -v end="$BASELINE_END" \
  '$1 >= start && $1 <= end && $3 ~ /^ashigaru/ {count++} \
  END {print count}' "$LOG_FILE")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ベースライン（Memory MCP 導入前）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  タスク数: $BASELINE_COUNT 件"
echo "  平均入力トークン数: $BASELINE_AVG トークン"
echo ""

# Phase 1 平均（足軽のみ）
PHASE1_AVG=$(awk -F, -v start="$PHASE1_START" -v end="$PHASE1_END" \
  '$1 >= start && $1 <= end && $3 ~ /^ashigaru/ {sum+=$5; count++} \
  END {if(count>0) printf "%.0f", sum/count; else print 0}' "$LOG_FILE")

PHASE1_COUNT=$(awk -F, -v start="$PHASE1_START" -v end="$PHASE1_END" \
  '$1 >= start && $1 <= end && $3 ~ /^ashigaru/ {count++} \
  END {print count}' "$LOG_FILE")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 1（Memory MCP 導入後）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  タスク数: $PHASE1_COUNT 件"
echo "  平均入力トークン数: $PHASE1_AVG トークン"
echo ""

# 削減率の計算
if [ "$BASELINE_AVG" -gt 0 ] && [ "$PHASE1_AVG" -gt 0 ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "効果測定"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # 削減トークン数
  REDUCED=$(echo "$BASELINE_AVG - $PHASE1_AVG" | bc)
  echo "  削減トークン数: $REDUCED トークン/タスク"

  # 削減率
  REDUCTION=$(echo "scale=2; (($BASELINE_AVG - $PHASE1_AVG) / $BASELINE_AVG) * 100" | bc)
  echo "  削減率: $REDUCTION%"

  # コスト削減額（haiku: $0.25/1M tokens）
  BASELINE_COST=$(echo "scale=6; $BASELINE_AVG * 0.25 / 1000000" | bc)
  PHASE1_COST=$(echo "scale=6; $PHASE1_AVG * 0.25 / 1000000" | bc)
  COST_SAVED=$(echo "scale=6; $BASELINE_COST - $PHASE1_COST" | bc)

  echo "  1タスクあたりコスト削減: \$${COST_SAVED}"

  # 100タスクあたりコスト削減
  COST_SAVED_100=$(echo "scale=4; $COST_SAVED * 100" | bc)
  echo "  100タスクあたりコスト削減: \$${COST_SAVED_100}"

  echo ""

  # 判定
  REDUCTION_INT=$(echo "$REDUCTION" | awk '{printf "%d", $1}')
  if [ "$REDUCTION_INT" -ge 5 ]; then
    echo "✅ 成功基準達成（削減率 5%以上）"
    echo "   → Phase 2（モジュール式専門化）への移行を検討"
  else
    echo "⚠️  削減率が 5%未満"
    echo "   → Memory 検索精度の改善、または Phase 2 への移行を検討"
  fi
elif [ "$PHASE1_COUNT" -eq 0 ]; then
  echo "⚠️  Phase 1 期間のデータがありません。"
  echo "   Memory MCP 導入後のタスクを実行してください。"
elif [ "$BASELINE_COUNT" -eq 0 ]; then
  echo "⚠️  ベースライン期間のデータがありません。"
  echo "   比較のため、導入前のデータを記録してください。"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "エージェント別集計"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
printf "%-12s %8s %12s\n" "エージェント" "タスク数" "平均トークン"
echo "────────────────────────────────────"

for agent in ashigaru1 ashigaru2 ashigaru3 ashigaru4 ashigaru5 ashigaru6 ashigaru7 ashigaru8; do
  agent_count=$(awk -F, -v agent="$agent" '$3 == agent {count++} END {print count+0}' "$LOG_FILE")
  if [ "$agent_count" -gt 0 ]; then
    agent_avg=$(awk -F, -v agent="$agent" '$3 == agent {sum+=$5; count++} END {if(count>0) printf "%.0f", sum/count; else print 0}' "$LOG_FILE")
    printf "%-12s %8d %12s\n" "$agent" "$agent_count" "$agent_avg"
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "分析完了"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
