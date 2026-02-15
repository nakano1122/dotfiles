# AI コーディングエージェント共通スキル & 設定

[chezmoi](https://www.chezmoi.io/) を使って AI コーディングエージェント向けの共通スキルと設定を管理するリポジトリ。

スキルはエージェント非依存のナレッジベース（Markdown）として設計されており、Claude Code・OpenAI Codex CLI など、スキルファイルを読み込めるエージェントであれば利用可能。


## ディレクトリ構成

```
chezmoi ソース                デプロイ先
─────────────────────────    ──────────────────
dot_agents/                → ~/.agents/
├── AGENTS.md                 ├── AGENTS.md          # エージェント共通ルール
├── CLAUDE.md                 ├── CLAUDE.md          # Claude Code 固有設定
└── skills/                   └── skills/            # 共通スキル群
    ├── accessibility/            ├── accessibility/
    ├── api-design/               ├── api-design/
    ├── ...                       ├── ...
    └── web-security/             └── web-security/
```

### エージェントごとの連携方法

各エージェントが `~/.agents/` 配下のスキルを認識できるよう、シンボリックリンクで連携する。

```
Claude Code:  ~/.claude/CLAUDE.md  → ~/.agents/CLAUDE.md
              ~/.claude/skills     → ~/.agents/skills
Codex CLI:    ~/.codex/AGENTS.md   → ~/.agents/AGENTS.md
              ~/.codex/skills      → ~/.agents/skills
```

セットアップスクリプトで一括作成できる：

```bash
./setup.sh
```


## 設定ファイル

| ファイル | 役割 |
|---------|------|
| `AGENTS.md` | エージェント共通ルール（言語設定、Skill ルーティング、作業フロー、進捗報告） |
| `CLAUDE.md` | Claude Code 固有設定（基本方針、コミュニケーション、Skill 利用ルール、並列開発ルール） |


## スキル一覧

### オーケストレーション（3）

| スキル名 | 概要 |
|---------|------|
| project-orchestrator | プロジェクト全体の統括。要件整理・技術選定・タスク分解・委譲 |
| frontend-orchestrator | フロントエンド開発の統括。FW選択・委譲・コードレビュー |
| backend-orchestrator | バックエンド開発の統括。FW/言語選択・委譲・コードレビュー |

### バックエンド実装（4）

| スキル名 | 概要 |
|---------|------|
| hono-backend | Hono (TypeScript) バックエンド API 実装 |
| fastapi-backend | FastAPI (Python) バックエンド API 実装 |
| gin-backend | Gin (Go) バックエンド API 実装 |
| nextjs-app-router | Next.js App Router (TypeScript) 実装 |

### 設計・アーキテクチャ（4）

| スキル名 | 概要 |
|---------|------|
| api-design | DDD + Clean Architecture ベースの API 設計 |
| db-design | RDBMS + ORM 前提のデータベース・スキーマ設計 |
| auth-design | 認証/認可の設計パターン（RBAC/ABAC、OAuth/OIDC） |
| env-config | 環境設定管理の設計（環境変数、シークレット分離） |

### テスト（4）

| スキル名 | 概要 |
|---------|------|
| test-design | テスト設計・戦略の汎用ガイド（ツール非依存） |
| vitest-testing | Vitest (TypeScript) テスト実装 |
| pytest-testing | pytest (Python) テスト実装 |
| gotest-testing | go test (Go) テスト実装 |

### セキュリティ・品質（3）

| スキル名 | 概要 |
|---------|------|
| web-security | Web アプリケーションのセキュリティ設計・実装 |
| accessibility | Web アクセシビリティ（WCAG 2.1 準拠） |
| observability | 可観測性設計（ログ・メトリクス・トレース） |

### 開発ツール・運用（5）

| スキル名 | 概要 |
|---------|------|
| git-worktree | git worktree を活用した並列開発 |
| pnpm-monorepo | pnpm ワークスペースによるモノレポ管理 |
| cicd-github-actions | GitHub Actions ベースの CI/CD 設計・実装 |
| debugging | フロントエンド・バックエンド両対応のデバッグ |
| codex-cli | OpenAI Codex CLI をセカンドオピニオンとして活用 |

### ML・データサイエンス（1）

| スキル名 | 概要 |
|---------|------|
| search-model-builder | HuggingFace/sentence-transformers ベースの検索モデル構築 |

### スキル管理（1）

| スキル名 | 概要 |
|---------|------|
| skill-reviewer | スキルのベストプラクティス適合レビュー |


## セットアップ

```bash
# 1. chezmoi で ~/.agents/ にデプロイ
chezmoi apply

# 2. 各エージェントへのシンボリックリンクを作成
./setup.sh
```

## 日常の使い方

```bash
# 差分確認
chezmoi diff

# デプロイ
chezmoi apply

# chezmoi ソースの編集
chezmoi edit ~/.agents/AGENTS.md
```
