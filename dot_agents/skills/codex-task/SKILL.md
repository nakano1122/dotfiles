---
name: codex-task
description: |
  Codex CLIワーカーエージェントを起動してタスクを実行する。
  Claude CodeがオーケストレーターとしてCodexを呼び出すハイブリッド構成。
  トリガー: 「Codexで実行」「Codexに任せて」「並列でCodex」「高速に処理」
---

# Codex Task - Codex CLIワーカー起動スキル

Claude CodeからCodex CLIワーカーエージェントを起動し、タスクを実行させる。

## アーキテクチャ

```
Claude Code (Orchestrator)
    │
    │ Agentツールでワーカー起動
    ▼
codex-worker Agent
    │
    │ Bashで codex exec 実行
    ▼
Codex CLI (Worker)
```

## 使い方

### 単一タスク実行

Agentツールでcodex-workerを起動:

```
Agent({
  name: "codex-worker",
  description: "Codex CLIでタスク実行",
  prompt: `あなたはCodex CLIを使ってタスクを実行するワーカーエージェントです。

## タスク
{ユーザーのタスク内容}

## 実行方法
以下のコマンドでCodex CLIを実行してください：

\`\`\`bash
codex exec "{タスク内容}" --full-auto
\`\`\`

結果を報告してください。`
})
```

### 並列タスク実行

複数のAgentを同時に起動して並列処理:

```
// 1つのメッセージで複数のAgentツールを呼び出す
Agent({ name: "codex-worker-1", prompt: "タスク1..." })
Agent({ name: "codex-worker-2", prompt: "タスク2..." })
Agent({ name: "codex-worker-3", prompt: "タスク3..." })
```

## Codex exec オプション

| オプション | 説明 |
|-----------|------|
| `--full-auto` | 完全自動実行（承認なし、sandbox有効） |
| `--sandbox read-only` | 読み取り専用sandbox |
| `--sandbox workspace-write` | ワークスペース書き込み可能 |
| `-m MODEL` | モデル指定（例: `-m o3`） |

## 使用例

### ファイル要約

```
Agent({
  name: "codex-summarizer",
  description: "Codexでファイル要約",
  prompt: `Codex CLIでタスクを実行してください。

## タスク
README.mdを読んで3行で要約

## 実行
\`\`\`bash
codex exec "README.mdを読んで3行で要約してください" --full-auto
\`\`\``
})
```

### コードレビュー

```
Agent({
  name: "codex-reviewer",
  description: "Codexでコードレビュー",
  prompt: `Codex CLIでコードレビューを実行してください。

## 実行
\`\`\`bash
codex exec review --full-auto
\`\`\``
})
```

## 注意事項

1. **Agent Teams連携**: TaskCreate/TaskUpdateでタスク管理と組み合わせ可能
2. **コスト**: Codex CLIは別途OpenAI APIコストが発生
3. **sandbox**: --full-autoはworkspace-write sandboxで実行される
4. **セッション**: 各Agentは独立したCodexセッションを起動
