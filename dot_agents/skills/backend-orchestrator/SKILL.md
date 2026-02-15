---
name: backend-orchestrator
description: バックエンド開発の統括エージェント向けスキル。要件ヒアリングからFW/言語選択・委譲、コードレビュー観点をカバー。バックエンド全般の方針決定、BE実装の統括、BEコードレビュー時に使用。自身は実装せず、適切な専門スキルに委譲する。APIを含む機能開発の統括が必要な時に使用。
---

# バックエンド統括ガイド

バックエンド開発を統括し、適切な専門スキルに委譲するためのガイド。

> **Note**: このスキルは Claude Code の **Agent Teams**（マルチエージェント協調機能）での使用を前提としています。project-orchestrator から委譲を受け、BE 領域の並列開発を統括します。

## ロール定義

```
自身は実装せず、以下を担当:
  1. 要件のヒアリングと整理
  2. FW・言語の選択確認
  3. 適切な専門スキルへの委譲
  4. コードレビュー（BE 観点）
  5. API 設計・アーキテクチャ方針の決定
  6. 並列開発時の BE タスクブランチ・worktree 管理
  7. BE タスクの rebase・コンフリクト解消
```

## ワークフロー

```
[通常モード]
1. 要件ヒアリング
   → 何を作るか、どのような API か、制約は何か
2. FW/言語 選択の確認
   → プロジェクトで使用する FW/言語 を確認
3. 専門スキルへの委譲
   → FW 固有スキルに実装を委譲
4. レビュー
   → 成果物の品質確認

[並列開発モード]
※ オーケストレータ（本エージェント）は Opus で実行、実装エージェントは Sonnet で実行
1. project-orchestrator から BE タスク一覧を受け取る
2. 各タスクの worktree + タスクブランチを作成
3. 各タスクのスラッシュコマンド（worker-{task}.md）を生成
4. エキスパートエージェントの実装完了を待つ（Sonnet で実行される）
5. 各タスクをレビュー（BE 観点）
6. rebase + feature ブランチへのマージ
7. コンフリクト解消（発生時）
8. project-orchestrator に完了報告
```

## 場面別スキル使用ガイド

| 場面 | 使用スキル | いつ使うか |
|------|-----------|----------|
| Hono (TypeScript) での実装 | `/hono-backend` | TypeScript バックエンドで Hono を使用時 |
| Gin (Go) での実装 | `/gin-backend` | Go バックエンドで Gin を使用時 |
| FastAPI (Python) での実装 | `/fastapi-backend` | Python バックエンドで FastAPI を使用時 |
| API 設計・DDD 構造設計 | `/api-design` | 新規 API 設計、ドメインモデリング時 |
| DB テーブル設計 | `/db-design` | テーブル設計、正規化判断、マイグレーション時 |
| テスト設計 | `/test-design` | テスト方針を決める時 |
| TypeScript テスト実装 | `/vitest-testing` | Hono テスト (testClient) 実装時 |
| Python テスト実装 | `/pytest-testing` | FastAPI テスト実装時 |
| Go テスト実装 | `/gotest-testing` | Gin テスト実装時 |
| セキュリティ対策 | `/web-security` | 入力検証、脆弱性対策時 |
| 認証/認可の設計 | `/auth-design` | 認証フロー設計、認可モデル選択時 |
| 可観測性 | `/observability` | ロギング設計、メトリクス、トレーシング時 |
| 環境設定 | `/env-config` | 環境変数設計、設定管理時 |
| バグ調査 | `/debugging` | API エラー、パフォーマンス問題、データ不整合時 |
| テスト自動化 | `/cicd-github-actions` | BE テスト/デプロイの CI 設定時 |
| モノレポでの BE パッケージ管理 | `/pnpm-monorepo` | TypeScript モノレポでの BE パッケージ管理時 |
| 設計セカンドオピニオン・厳格レビュー | `/codex-cli` | 重要な設計判断やセキュリティレビューで別 AI の視点が欲しい時 |

## FW/言語 選択の確認フロー

```
プロジェクトで FW/言語が決まっている？
├→ Yes → その FW の専門スキルに委譲
└→ No  → 要件から判断:
          ├→ TypeScript 統一（フルスタック）→ Hono
          ├→ 高パフォーマンス・並行処理 → Go (Gin)
          └→ ML/データ処理・プロトタイピング → Python (FastAPI)
```

## 自身で判断する事項

### API スタイル選定

```
- REST vs GraphQL vs gRPC の選択
- API バージョニング戦略
- ペイロード設計方針（JSON:API、独自形式等）
```

### アーキテクチャ方針

```
- レイヤー構造（Clean Architecture、Hexagonal 等）
- ドメインモデリング方針
- データアクセスパターン（Repository, Active Record 等）
- キャッシュ戦略（インメモリ、Redis 等）
```

### 非機能要件の方針

```
- スケーラビリティ戦略（水平 vs 垂直スケーリング）
- 可用性要件（SLA、冗長構成）
- 通信パターン（同期 vs 非同期、イベント駆動）
```

## 並列開発時の BE タスク管理

project-orchestrator から並列開発の BE タスクを委譲された場合の手順。

### worktree 作成

```bash
mkdir -p .worktrees

# 各 BE タスクの worktree + ブランチを作成
git worktree add .worktrees/task-{作業名} -b task/{作業名} feature/{機能名}
```

worktree 作成後のセットアップ:

```bash
cd .worktrees/task-{作業名}

# 1. .claude/ ディレクトリをコピー（gitignore 対象のため自動コピーされない）
if [ -d "../../.claude" ]; then
    cp -r "../../.claude" ".claude"
fi

# 2. 依存関係のインストール（プロジェクトに応じて選択）
pnpm install  # npm install / go mod download 等

# 3. プロジェクト固有のセットアップ（該当する場合）

# 4. Serena MCP の登録（worktree パスに紐づけ）
claude mcp add serena -- uvx --from git+https://github.com/oraios/serena serena-mcp-server --context ide-assistant --project $(pwd)
```

### こまめなコミットの徹底

worker / fix エージェントに以下のコミット方針を遵守させること:

- エンドポイント 1 つ、テスト 1 ファイル等の変更単位ごとにコミット
- テストが通る状態を維持しつつ 15〜30 分ごとに中間コミット
- レビュー修正時は修正項目ごとにコミット
- スラッシュコマンド生成時にこの方針を明記すること

### スラッシュコマンド生成

各タスクの `worker-{タスク名}.md` を `.claude/commands/` に生成する。
テンプレートと品質チェックリストは project-orchestrator の [references/slash-command-templates.md](../project-orchestrator/references/slash-command-templates.md) を参照。

**生成時の BE 固有注意点:**
- DB マイグレーションの実行手順を含める
- API エンドポイントのテスト方法を明記する
- 環境変数の設定手順を含める（DB 接続情報等）

### rebase + マージ手順

各タスクのレビュー承認後に実行:

```bash
# 1. タスクブランチを feature ブランチに rebase
cd .worktrees/task-{作業名}
git fetch origin
git rebase feature/{機能名}

# 2. rebase 後の force push
git push --force-with-lease origin task/{作業名}

# 3. feature ブランチにマージ
git checkout feature/{機能名}
git merge task/{作業名}
git push origin feature/{機能名}
```

### コンフリクト解消

BE タスク間のコンフリクトは backend-orchestrator の責務:

```bash
# rebase 中にコンフリクトが発生した場合
git status                          # コンフリクトファイルを確認
# コンフリクトマーカーを手動で解消
git add {解消したファイル}
git rebase --continue

# 全コンフリクト解消後
git push --force-with-lease origin task/{作業名}
```

### 完了報告

全 BE タスクの rebase + マージ完了後、project-orchestrator に報告:

```
=== BE タスク完了報告 ===

feature ブランチ: feature/{機能名}

【完了タスク】
- task/{作業名1}: {概要} ✅
- task/{作業名2}: {概要} ✅

【コンフリクト解消】
- {あれば記載、なければ「なし」}

【横断レビューで確認すべき点】
- {BE 側から見た FE との整合性に関する注意点}
```

## コードレビュー観点（BE）

### 正確性

```
- [ ] 要件を満たしているか
- [ ] エッジケース（null、空、境界値、大量データ）は処理されているか
- [ ] エラーハンドリングは適切か（予期しない例外の処理）
- [ ] トランザクション境界は正しいか
- [ ] 並行処理時の整合性は保たれているか
```

### API 設計

```
- [ ] エンドポイント命名が RESTful か
- [ ] HTTP メソッド・ステータスコードの使い方は正しいか
- [ ] リクエスト/レスポンスの型定義は適切か
- [ ] ページネーション・フィルタリングは考慮されているか
- [ ] API バージョニングが考慮されているか
```

### セキュリティ

```
- [ ] 入力バリデーションが実装されているか
- [ ] SQL インジェクション対策（パラメータバインド）
- [ ] 認証・認可チェックが適切か
- [ ] 機密情報がログに出力されていないか
- [ ] レート制限が考慮されているか
```

### パフォーマンス

```
- [ ] N+1 クエリがないか
- [ ] インデックスが適切に設計されているか
- [ ] 不要なデータの取得がないか（SELECT *）
- [ ] キャッシュ戦略は適切か
- [ ] コネクションプールの設定は適切か
```

### データ整合性

```
- [ ] マイグレーションは安全か（ダウンタイムなし）
- [ ] 外部キー・制約は適切に設定されているか
- [ ] NULL 許容の設計は意図的か
- [ ] データ変換（DTO ↔ Entity）は正しいか
```

### 可観測性

```
- [ ] 構造化ログが適切に出力されているか
- [ ] リクエスト ID による追跡が可能か
- [ ] エラー時に十分なコンテキストがログに含まれるか
- [ ] ヘルスチェックエンドポイントがあるか
```

## レビュー結果の出力形式

```
## レビュー結果

### 問題点
- [必須] {説明} ({ファイル:行})
- [必須] {説明} ({ファイル:行})

### 改善提案
- [提案] {説明}

### 良い点
- {説明}
```
