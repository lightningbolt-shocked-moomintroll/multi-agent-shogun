# Memory MCP 初期化ガイド

> **Phase 1**: 足軽のエンティティ作成
> **作成日**: 2026-02-03

---

## 概要

Memory MCP に各足軽のエンティティを作成する。
初回のみ実行。既にエンティティが存在する場合はスキップ。

---

## 実行手順

### 1. 既存エンティティの確認

```javascript
// Memory MCP に足軽のエンティティが既に存在するか確認
mcp__memory__search_nodes({
  "query": "ashigaru"
})
```

**結果が空の場合**: 以下の初期化を実行
**結果がある場合**: 初期化不要（スキップ）

---

### 2. 各足軽のエンティティを作成

Claude Code で以下のツールを実行:

```javascript
mcp__memory__create_entities({
  "entities": [
    {
      "name": "ashigaru1",
      "entityType": "ashigaru",
      "observations": [
        "マルチエージェントシステムの足軽1号",
        "multiagent セッションのウィンドウ1に配置",
        "汎用的なタスクを実行可能"
      ]
    },
    {
      "name": "ashigaru2",
      "entityType": "ashigaru",
      "observations": [
        "マルチエージェントシステムの足軽2号",
        "multiagent セッションのウィンドウ2に配置",
        "汎用的なタスクを実行可能"
      ]
    },
    {
      "name": "ashigaru3",
      "entityType": "ashigaru",
      "observations": [
        "マルチエージェントシステムの足軽3号",
        "multiagent セッションのウィンドウ3に配置",
        "汎用的なタスクを実行可能"
      ]
    },
    {
      "name": "ashigaru4",
      "entityType": "ashigaru",
      "observations": [
        "マルチエージェントシステムの足軽4号",
        "multiagent セッションのウィンドウ4に配置",
        "汎用的なタスクを実行可能"
      ]
    },
    {
      "name": "ashigaru5",
      "entityType": "ashigaru",
      "observations": [
        "マルチエージェントシステムの足軽5号",
        "multiagent セッションのウィンドウ5に配置",
        "汎用的なタスクを実行可能"
      ]
    },
    {
      "name": "ashigaru6",
      "entityType": "ashigaru",
      "observations": [
        "マルチエージェントシステムの足軽6号",
        "multiagent セッションのウィンドウ6に配置",
        "汎用的なタスクを実行可能"
      ]
    },
    {
      "name": "ashigaru7",
      "entityType": "ashigaru",
      "observations": [
        "マルチエージェントシステムの足軽7号",
        "multiagent セッションのウィンドウ7に配置",
        "汎用的なタスクを実行可能"
      ]
    },
    {
      "name": "ashigaru8",
      "entityType": "ashigaru",
      "observations": [
        "マルチエージェントシステムの足軽8号",
        "multiagent セッションのウィンドウ8に配置",
        "汎用的なタスクを実行可能"
      ]
    }
  ]
})
```

---

### 3. 作成確認

```javascript
// 全足軽のエンティティを確認
mcp__memory__open_nodes({
  "names": ["ashigaru1", "ashigaru2", "ashigaru3", "ashigaru4",
            "ashigaru5", "ashigaru6", "ashigaru7", "ashigaru8"]
})
```

**期待される結果**: 各足軽のエンティティが表示される

---

### 4. グラフ全体の確認（オプション）

```javascript
// Memory MCP のグラフ全体を確認
mcp__memory__read_graph({})
```

---

## トラブルシューティング

### Q: エンティティ作成に失敗した

**A**: 既に存在する可能性があります。以下で確認:

```javascript
mcp__memory__search_nodes({
  "query": "ashigaru1"
})
```

### Q: 誤ったエンティティを作成した

**A**: 削除して再作成:

```javascript
// 削除
mcp__memory__delete_entities({
  "entityNames": ["ashigaru1"]
})

// 再作成
mcp__memory__create_entities({
  "entities": [
    {
      "name": "ashigaru1",
      "entityType": "ashigaru",
      "observations": ["..."]
    }
  ]
})
```

---

## 次のステップ

初期化完了後、以下を実行:

1. **足軽にタスクを割り当て**
2. **足軽が expertise_gained を報告**
3. **家老が Memory MCP に保存**
4. **次回タスク割り当て時に検索**

---

**初期化は1回のみ実行。以降は自動的に経験が蓄積される。**
