# トークン使用量トラッキング

> **Phase 1**: Memory MCP 活用の効果測定
> **作成日**: 2026-02-03

---

## 概要

Phase 1（Memory MCP 活用）の効果を測定するため、トークン使用量を記録する。

---

## ログフォーマット

### ファイル: logs/token_usage.csv

```csv
date,time,agent_id,task_id,input_tokens,output_tokens,total_tokens,cost_usd,notes
```

### フィールド説明

| フィールド | 説明 | 例 |
|-----------|------|-----|
| date | 日付 | 2026-02-03 |
| time | 時刻 | 14:30:00 |
| agent_id | エージェントID | ashigaru1, karo, shogun |
| task_id | タスクID | subtask_001, cmd_001 |
| input_tokens | 入力トークン数 | 20000 |
| output_tokens | 出力トークン数 | 5000 |
| total_tokens | 合計トークン数 | 25000 |
| cost_usd | コスト（USD） | 0.00625 |
| notes | 備考 | "Memory検索あり" 等 |

---

## 記録方法

### 手動記録（現状）

各エージェントのセッション終了時に、Claude Code が表示するトークン使用量を記録。

```bash
# セッション終了時に表示される例:
# Token usage: 20000 input, 5000 output

# 手動で CSV に追記
echo "2026-02-03,14:30:00,ashigaru1,subtask_001,20000,5000,25000,0.00625,Memory検索あり" >> logs/token_usage.csv
```

### 自動記録（将来の拡張）

Claude Code の API ログからトークン使用量を自動抽出。

---

## 効果測定の方法

### 1週間ごとの集計

```bash
# Phase 1 導入前（ベースライン）
# 2026-02-03 〜 2026-02-10 のデータ

# Phase 1 導入後
# 2026-02-11 〜 2026-02-18 のデータ
```

### 平均トークン数の計算

```bash
# 足軽の平均入力トークン数
awk -F, '$3 ~ /^ashigaru/ {sum+=$5; count++} END {print "平均:", sum/count}' logs/token_usage.csv

# 出力例: 平均: 18500
```

### 削減率の計算

```bash
# ベースライン平均: 20000トークン
# Phase 1 平均: 18500トークン
# 削減率: ((20000-18500)/20000)*100 = 7.5%

echo "削減率: $(awk 'BEGIN {print ((20000-18500)/20000)*100}')%"
```

### コスト削減額の計算

```bash
# haiku モデル: $0.25 / 1M input tokens

# ベースライン（100タスク）: 20000 * 100 * 0.25 / 1000000 = $0.50
# Phase 1（100タスク）: 18500 * 100 * 0.25 / 1000000 = $0.46
# 削減額: $0.04

awk -F, '{sum+=$8} END {print "総コスト: $" sum}' logs/token_usage.csv
```

---

## サンプルデータ

### logs/token_usage_sample.csv

```csv
date,time,agent_id,task_id,input_tokens,output_tokens,total_tokens,cost_usd,notes
2026-02-03,10:00:00,ashigaru1,subtask_001,20000,5000,25000,0.00625,ベースライン
2026-02-03,10:30:00,ashigaru2,subtask_002,21000,4500,25500,0.00650,ベースライン
2026-02-03,11:00:00,ashigaru1,subtask_003,19500,5200,24700,0.00618,ベースライン
2026-02-10,14:00:00,ashigaru1,subtask_004,18000,5000,23000,0.00575,Memory検索あり
2026-02-10,14:30:00,ashigaru2,subtask_005,18500,4800,23300,0.00588,Memory検索あり
2026-02-10,15:00:00,ashigaru1,subtask_006,17500,5100,22600,0.00563,Memory検索あり、経験者割当
```

---

## 分析スクリプト

### scripts/analyze_token_usage.sh

```bash
#!/bin/bash
# トークン使用量の分析スクリプト

LOG_FILE="logs/token_usage.csv"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "トークン使用量分析"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ベースライン期間（Memory導入前）
BASELINE_START="2026-02-03"
BASELINE_END="2026-02-10"

# Phase 1 期間（Memory導入後）
PHASE1_START="2026-02-11"
PHASE1_END="2026-02-18"

# ベースライン平均
BASELINE_AVG=$(awk -F, -v start="$BASELINE_START" -v end="$BASELINE_END" \
  '$1 >= start && $1 <= end && $3 ~ /^ashigaru/ {sum+=$5; count++} \
  END {if(count>0) print sum/count; else print 0}' "$LOG_FILE")

echo "ベースライン平均（$BASELINE_START 〜 $BASELINE_END）: $BASELINE_AVG トークン"

# Phase 1 平均
PHASE1_AVG=$(awk -F, -v start="$PHASE1_START" -v end="$PHASE1_END" \
  '$1 >= start && $1 <= end && $3 ~ /^ashigaru/ {sum+=$5; count++} \
  END {if(count>0) print sum/count; else print 0}' "$LOG_FILE")

echo "Phase 1 平均（$PHASE1_START 〜 $PHASE1_END）: $PHASE1_AVG トークン"

# 削減率
if (( $(echo "$BASELINE_AVG > 0" | bc -l) )); then
  REDUCTION=$(echo "scale=2; (($BASELINE_AVG - $PHASE1_AVG) / $BASELINE_AVG) * 100" | bc)
  echo "削減率: $REDUCTION%"
fi

# コスト削減額（haiku: $0.25/1M tokens）
BASELINE_COST=$(echo "scale=5; $BASELINE_AVG * 0.25 / 1000000" | bc)
PHASE1_COST=$(echo "scale=5; $PHASE1_AVG * 0.25 / 1000000" | bc)
COST_SAVED=$(echo "scale=5; $BASELINE_COST - $PHASE1_COST" | bc)

echo "1タスクあたりコスト削減: \$${COST_SAVED}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

---

## 効果判定基準

### 成功基準（Phase 2 への移行を検討）

- [ ] トークン削減率が **5%以上**
- [ ] タスク完了時間が変わらないか短縮
- [ ] 品質（エラー率）が変わらないか向上
- [ ] 家老の負担が許容範囲内

### 改善が必要

- トークン削減率が 5%未満 → Memory 検索の精度を改善
- タスク完了時間が増加 → 割り当てロジックを見直し
- 品質が低下 → 経験者割り当ての基準を見直し

---

## ダッシュボード

### dashboard.md に追加すべき情報

```markdown
## 📊 Phase 1 効果測定（Memory MCP 活用）

### トークン削減状況

| 期間 | 平均トークン数 | 削減率 | コスト削減 |
|------|--------------|--------|-----------|
| ベースライン（2/3-2/10） | 20,000 | - | - |
| Phase 1（2/11-2/18） | 18,500 | 7.5% | $0.04/100タスク |

### 経験者割り当ての効果

| 足軽 | 専門分野 | タスク完了数 | 平均トークン削減率 |
|------|---------|------------|------------------|
| ashigaru1 | React | 5回 | 12% |
| ashigaru2 | Node.js | 3回 | 8% |
| ashigaru3 | PostgreSQL | 2回 | 5% |

### 次回レビュー

- **日付**: 2026-02-18
- **判断**: Phase 2 への移行可否
```

---

## トラブルシューティング

### Q: ログファイルが巨大になった

**A**: 定期的にアーカイブ。

```bash
# 月次でアーカイブ
mv logs/token_usage.csv logs/token_usage_2026-02.csv
touch logs/token_usage.csv
```

### Q: 手動記録が面倒

**A**: 将来的には Claude Code API からの自動抽出を検討。

---

**作成者**: 将軍（Phase 1 実装）
**更新日**: 2026-02-03
