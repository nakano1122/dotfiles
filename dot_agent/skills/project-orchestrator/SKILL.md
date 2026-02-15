---
name: project-orchestrator
description: プロジェクト全体の統括エージェント向けスキル。要件整理から技術選定・アーキテクチャ設計・タスク分解・委譲までをカバー。git worktreeを活用した並列開発オーケストレーション（featureブランチ管理、BE/FE統括への委譲、横断レビュー）も担う。プロジェクト全体を俯瞰し、適切なエージェント/スキルに委譲する。新規プロジェクト立ち上げ、技術選定、全体設計、タスク分解・委譲、並列開発時に使用。
---

# プロジェクト統括ガイド

プロジェクト全体を俯瞰し、適切な専門スキルに委譲するためのガイド。

> **Note**: このスキルは Claude Code の **Agent Teams**（マルチエージェント協調機能、`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`）での使用を前提としています。

## ロール定義

```
自身は実装せず、以下を担当:
  1. 要件の整理と優先順位付け
  2. 技術選定の方針決定
  3. アーキテクチャの全体設計
  4. タスク分解と適切なスキルへの委譲
  5. プロジェクト横断的な品質基準の維持
  6. 並列開発の全体オーケストレーション（feature ブランチ管理、BE/FE 統括への委譲、横断レビュー）
```

## プロジェクト立ち上げワークフロー

```
1. 要件整理
   → 機能要件・非機能要件の整理、制約の確認
2. 技術選定
   → FW/言語・インフラ・アーキテクチャの選択
3. 全体設計
   → システム構成・データモデル・API 設計の方針
4. タスク分解
   → 実装タスクの洗い出しと優先順位付け
5. 委譲と進行管理
   → 専門スキルへの委譲、成果物の品質確認
6. 並列開発セットアップ（並列開発時）
   → feature ブランチ作成、worktree 基盤準備、BE/FE 統括への委譲
7. 横断レビューと統合（並列開発時）
   → BE/FE 成果物の整合性確認、feature → develop のマージ管理
```

## 場面別スキル使用ガイド

### 統括スキル

| 場面 | 使用スキル | 判断基準 |
|------|-----------|---------|
| フロントエンド全般の方針決定 | `/frontend-orchestrator` | UI を含む機能開発の統括が必要な時 |
| バックエンド全般の方針決定 | `/backend-orchestrator` | API/サーバー開発の統括が必要な時 |

### FW/ツール固有スキル

| 場面 | 使用スキル | 判断基準 |
|------|-----------|---------|
| Next.js App Router での実装 | `/nextjs-app-router` | FE 統括から委譲される |
| Hono (TypeScript) での実装 | `/hono-backend` | BE 統括から委譲される |
| Gin (Go) での実装 | `/gin-backend` | BE 統括から委譲される |
| FastAPI (Python) での実装 | `/fastapi-backend` | BE 統括から委譲される |
| Vitest でのテスト実装 | `/vitest-testing` | TypeScript テスト実装時 |
| pytest でのテスト実装 | `/pytest-testing` | Python テスト実装時 |
| go test でのテスト実装 | `/gotest-testing` | Go テスト実装時 |

### 横断的関心事スキル

| 場面 | 使用スキル | 判断基準 |
|------|-----------|---------|
| API 設計・DDD 構造設計 | `/api-design` | 新規 API やドメインモデル設計時 |
| DB テーブル設計 | `/db-design` | データモデル設計、マイグレーション時 |
| セキュリティ対策 | `/web-security` | 脆弱性レビュー、セキュリティ設計時 |
| 認証/認可の設計 | `/auth-design` | 認証フロー設計、認可モデル選択時 |
| ログ・メトリクス・トレース設計 | `/observability` | 可観測性の設計、ログ設計時 |
| アクセシビリティ設計 | `/accessibility` | WCAG 準拠、a11y 対応が必要な時 |
| 環境設定管理 | `/env-config` | 環境変数設計、設定管理方針の決定時 |
| テスト設計・戦略 | `/test-design` | テスト方針決定、テストレベル選択時 |
| バグ調査・問題切り分け | `/debugging` | 原因不明のバグ、パフォーマンス問題時 |
| CI/CD 構築 | `/cicd-github-actions` | パイプライン構築、自動化設定時 |
| モノレポ管理 | `/pnpm-monorepo` | ワークスペース設定、パッケージ追加時 |
| UI デザイン | `/frontend-design` | デザイン品質が重要な場面 |
| 設計セカンドオピニオン・厳格レビュー | `/codex-cli` | 重要な設計判断やセキュリティレビューで別 AI の視点が欲しい時 |

## タスク分解と委譲の原則

```
1. 機能単位で分解
   → 1 タスク = 1 機能 or 1 API エンドポイント
2. 依存関係を明確に
   → DB 設計 → API 設計 → BE 実装 → FE 実装
3. 適切な粒度
   → 大きすぎず（1 タスク = 半日〜1 日程度）
   → 小さすぎず（意味のある成果物がある単位）
4. 委譲時に伝える情報
   → 何を作るか、制約条件、関連するスキル/コンテキスト
```

### タスク粒度のガイドライン

```
目安:
  - 1 タスク = 変更量 200行以下（理想は 50〜100 行）
  - 1 ブランチの寿命 = 最長 1〜2 日
  - 1 タスク = 1 つの目的に集中（Single Purpose）
  - 独立してレビュー・マージ・デプロイ可能な単位

大きすぎるタスクの兆候:
  - 変更ファイル数が 10 以上
  - 複数の機能や関心事が混在
  - レビューに 30 分以上かかりそう
  → さらに分割を検討する

分割戦略:
  - 大きな機能 → 垂直スライス（1 API エンドポイント単位）
  - 共通部分 → 先行タスクとして切り出す（型定義、インターフェース、設定）
  - BE/FE → 領域ごとに分離
  - Feature Flag を活用し、未完成でもマージ可能にする
```

## 並列開発ワークフロー

### 前提条件

- GitHub リポジトリが存在すること
- `claude` コマンド（Claude Code CLI）が利用可能であること
- git worktree が使用可能であること
- git worktree の技術的な操作ガイドとして `/git-worktree` スキルを参照すること

### 並列開発の適用判断

```
タスク数が 2 以上 かつ ファイル競合なしで分割可能？
├→ Yes → 並列開発を適用
│         ├→ BE + FE に分かれる → BE/FE orchestrator に委譲
│         └→ 単一領域のみ → 該当 orchestrator に委譲
└→ No  → 通常の逐次委譲
```

### モデル使い分け

| 役割 | モデル | 理由 |
|------|--------|------|
| オーケストレータ（project/BE/FE） | **Opus** | 要件整理・設計判断・レビューなど高度な推論が必要 |
| 実装エージェント（worker/fix） | **Sonnet** | コード生成・定型実装に最適、コスト効率が良い |

```
claude 起動時のモデル指定:
  オーケストレータ: claude --model opus
  実装エージェント: claude --model sonnet
```

### 3フェーズ概要

| フェーズ | 担当 | モデル | 内容 |
|---------|------|--------|------|
| **Phase 1: 計画** | project-orchestrator + BE/FE orchestrator | Opus | 要件整理・タスク分割・worktree 作成・スラッシュコマンド生成 |
| **Phase 2: 実装** | エキスパートエージェント（非対話） | Sonnet | worktree 内で自律実装・品質ゲート・プッシュ |
| **Phase 3: レビュー** | BE/FE orchestrator → project-orchestrator | Opus | レビュー・fix 指示・rebase/マージ・横断レビュー |

詳細は [references/parallel-dev-workflow.md](references/parallel-dev-workflow.md) を参照。

※ Phase 1（設計判断）および Phase 3（レビュー）で、重要度が高い場面では `/codex-cli` を活用してセカンドオピニオンを取得する。

### PR 作成ワークフロー

各タスクブランチの作業完了後、PR を作成して feature ブランチにマージする:

```
1. 作業完了 → 最終コミット + push
2. rebase で feature ブランチの最新を取り込み
3. テスト・lint が通ることを確認
4. force-with-lease で push
5. gh pr create --base feature/{機能名} で PR を作成
6. PR レビュー → 承認 → マージ
```

gh コマンドが使えない環境の場合は、ユーザーに PR 作成 URL と推奨内容を提示する。
詳細な手順は `/git-worktree` スキルの「PR 作成」セクションを参照。

### ブランチ戦略 + worktree 構成

```
develop
└── feature/{機能名}                          ← project-orchestrator が管理
    ├── task/{作業名}-be-api                  ← BE orchestrator が管理
    │   → .worktrees/task-{作業名}-be-api/
    ├── task/{作業名}-be-schema               ← BE orchestrator が管理
    │   → .worktrees/task-{作業名}-be-schema/
    ├── task/{作業名}-fe-auth                 ← FE orchestrator が管理
    │   → .worktrees/task-{作業名}-fe-auth/
    └── task/{作業名}-fe-dashboard            ← FE orchestrator が管理
        → .worktrees/task-{作業名}-fe-dashboard/
```

### project-orchestrator 自身の責務

1. **feature ブランチの作成**
   ```bash
   git checkout develop && git pull origin develop
   git checkout -b feature/{機能名}
   git push -u origin feature/{機能名}
   ```

2. **.gitignore への `.worktrees/` 追加**（初回のみ）
   ```bash
   echo ".worktrees/" >> .gitignore
   git add .gitignore && git commit -m "chore: .worktreesをgitignoreに追加"
   mkdir -p .worktrees
   ```

3. **タスクを BE/FE に振り分けて各オーケストレータに委譲**

4. **BE/FE オーケストレータの成果物を横断レビュー**
   - BE/FE の API インターフェース整合性
   - 共有型定義の一致
   - 認証/認可フローの一貫性
   - エラーハンドリング方針の統一

5. **feature → develop のマージ管理**

6. **クリーンアップの案内**

### BE/FE オーケストレータへの委譲フォーマット

```
=== 並列開発: {BE/FE} タスク委譲 ===

feature ブランチ: feature/{機能名}

【タスク一覧】

1. task/{作業名1}
   - 概要: {概要}
   - 使用スキル: /{スキル名}
   - 依存: なし
   - 仕様:
     - {仕様項目}

2. task/{作業名2}
   - 概要: {概要}
   - 使用スキル: /{スキル名}
   - 依存: task/{作業名1} 完了後
   - 仕様:
     - {仕様項目}

【依頼事項】
1. 各タスクの worktree + タスクブランチを作成
2. 各タスクの worker スラッシュコマンドを生成
3. レビュー → rebase → feature ブランチへのマージ
4. 完了後 project-orchestrator に報告
```

### メインリポジトリ編集禁止ルール

- 各エキスパートは**専用 worktree 内でのみ**作業する
- メインリポジトリ（プロジェクトルート）のファイル編集は禁止
- ファイルパスは worktree ルートからの相対パスで指定する
- `pwd` で worktree 内であることを確認してから作業する

### こまめなコミットの徹底

実装エージェント（worker）およびレビュー修正エージェント（fix）は、作業中にこまめにコミットすること。

- 意味のある変更単位ごと（1 ファイル or 1 機能のまとまり）にコミット
- テストが通る状態になったタイミングでコミット
- 長時間の作業では 15〜30 分ごとを目安に中間コミット
- レビュー修正時は修正項目ごとにコミット

理由: 並列開発ではコンフリクトリスクが高く、こまめなコミットにより解消が容易になる。また障害時のロールバック単位が小さくなり、レビュー差分も読みやすくなる。

### 参照リンク

- [全体フロー詳細](references/parallel-dev-workflow.md)
- [スラッシュコマンドテンプレート](references/slash-command-templates.md)
- [Git コマンドリファレンス](references/git-commands.md)
- [レビューフェーズ詳細](references/review-session.md)
- `/git-worktree` スキル - git worktree の技術的な操作・運用ガイド（worktree ライフサイクル、rebase 詳細、コンフリクト予防、トラブルシューティング）

## 技術選定の判断フレームワーク

### FW/言語選定

```
フルスタック TypeScript で統一したい？
├→ Yes → FE: Next.js App Router + BE: Hono
│         モノレポ: pnpm ワークスペース
└→ No  → BE の要件で判断:
          ├→ 高パフォーマンス・並行処理 → Go (Gin)
          ├→ ML/データ処理 → Python (FastAPI)
          └→ FE は要件で判断:
               ├→ SSR + SEO → Next.js App Router
               ├→ SPA（管理画面等）→ Vite + React
               └→ 静的サイト → Next.js (Static Export) or Astro
```

### アーキテクチャ選定

```
API スタイル:
  ├→ CRUD 中心 → REST
  ├→ 複雑なデータ取得 → GraphQL
  └→ マイクロサービス間通信 → gRPC

データストア:
  ├→ リレーショナルデータ → RDBMS
  ├→ ドキュメント指向 → NoSQL
  └→ キャッシュ → Redis 等

デプロイ:
  ├→ エッジ分散 → Cloudflare Workers
  ├→ コンテナ → Docker + Cloud Run / ECS
  └→ サーバーレス → Lambda / Cloud Functions
```

## プロジェクト横断的な品質基準

```
コード品質:
  - 型安全性の確保
  - リンター/フォーマッター設定
  - コードレビュー必須

テスト:
  - ビジネスロジックのユニットテスト必須
  - API エンドポイントの統合テスト必須
  - クリティカルパスの E2E テスト推奨

セキュリティ:
  - 入力バリデーション必須
  - 認証/認可の適切な実装
  - 依存関係の脆弱性チェック

運用:
  - 構造化ログの出力
  - ヘルスチェックエンドポイント
  - 環境変数による設定管理
```

## 開発フェーズと使用スキルの対応

```
1. 要件整理・技術選定    → project-orchestrator (自身)
2. モノレポ構築          → /pnpm-monorepo
3. DB 設計              → /db-design
4. API 設計 (DDD)       → /api-design
5. 認証/認可設計         → /auth-design
6. 環境設定管理          → /env-config
7. BE 実装              → /backend-orchestrator → FW スキル
8. FE 実装              → /frontend-orchestrator → FW スキル
9. テスト設計            → /test-design
10. テスト実装           → /vitest-testing, /pytest-testing, /gotest-testing
11. セキュリティレビュー  → /web-security
12. アクセシビリティ対応  → /accessibility
13. 可観測性設計          → /observability
14. CI/CD 構築          → /cicd-github-actions
```

※ 並列開発時は、ステップ 7〜10 を `/backend-orchestrator` と `/frontend-orchestrator` に委譲し、worktree ベースで並列実行する。横断レビュー（BE/FE 整合性確認）は project-orchestrator 自身が担う。
