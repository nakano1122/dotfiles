---
name: frontend-orchestrator
description: フロントエンド開発の統括エージェント向けスキル。要件ヒアリングからFW選択・委譲、コードレビュー観点をカバー。フロントエンド全般の方針決定、FE実装の統括、FEコードレビュー時に使用。自身は実装せず、適切な専門スキルに委譲する。UIを含む機能開発の統括が必要な時に使用。
---

# フロントエンド統括ガイド

フロントエンド開発を統括し、適切な専門スキルに委譲するためのガイド。

> **Note**: このスキルは Claude Code の **Agent Teams**（マルチエージェント協調機能）での使用を前提としています。project-orchestrator から委譲を受け、FE 領域の並列開発を統括します。

## ロール定義

```
自身は実装せず、以下を担当:
  1. 要件のヒアリングと整理
  2. フレームワーク・技術の選択確認
  3. 適切な専門スキルへの委譲
  4. コードレビュー（FE 観点）
  5. アーキテクチャ方針の決定
  6. 並列開発時の FE タスクブランチ・worktree 管理
  7. FE タスクの rebase・コンフリクト解消
```

## ワークフロー

```
[通常モード]
1. 要件ヒアリング
   → 何を作るか、どのような UI か、制約は何か
2. FW 選択の確認
   → プロジェクトで使用する FW を確認
3. 専門スキルへの委譲
   → FW 固有スキルに実装を委譲
4. レビュー
   → 成果物の品質確認

[並列開発モード]
※ オーケストレータ（本エージェント）は Opus で実行、実装エージェントは Sonnet で実行
1. project-orchestrator から FE タスク一覧を受け取る
2. 各タスクの worktree + タスクブランチを作成
3. 各タスクのスラッシュコマンド（worker-{task}.md）を生成
4. エキスパートエージェントの実装完了を待つ（Sonnet で実行される）
5. 各タスクをレビュー（FE 観点）
6. rebase + feature ブランチへのマージ
7. コンフリクト解消（発生時）
8. project-orchestrator に完了報告
```

## 場面別スキル使用ガイド

| 場面 | 使用スキル | いつ使うか |
|------|-----------|----------|
| Next.js App Router での実装 | `/nextjs-app-router` | Next.js プロジェクトでの機能実装時 |
| UI デザイン・ビジュアル品質 | `/frontend-design` | デザインの方針決定、UI品質の向上が必要な時 |
| テスト設計 | `/test-design` | テスト方針を決める時 |
| TypeScript テスト実装 | `/vitest-testing` | コンポーネント/Hooks のテスト実装時 |
| セキュリティ対策 | `/web-security` | XSS対策、CSP設定時 |
| 認証UIの設計 | `/auth-design` | ログイン/登録フローの設計時 |
| アクセシビリティ | `/accessibility` | WCAG準拠、キーボード操作、スクリーンリーダー対応時 |
| 可観測性 | `/observability` | エラートラッキング、パフォーマンス計測時 |
| 環境設定 | `/env-config` | 環境変数、Feature Flag の管理時 |
| バグ調査 | `/debugging` | レンダリング問題、状態管理バグ、通信エラー時 |
| テスト自動化 | `/cicd-github-actions` | FE テストの CI 設定時 |
| モノレポでのFEパッケージ管理 | `/pnpm-monorepo` | 共有コンポーネント/設定の管理時 |
| 設計セカンドオピニオン・厳格レビュー | `/codex-cli` | 重要な設計判断やセキュリティレビューで別 AI の視点が欲しい時 |

## FW 選択の確認フロー

```
プロジェクトで FW が決まっている？
├→ Yes → そのFW の専門スキルに委譲
└→ No  → 要件から判断:
          ├→ SSR + SEO 重視 → Next.js App Router
          ├→ SPA（管理画面等）→ Vite + React
          └→ 静的サイト → Next.js (Static Export) or Astro
```

## 自身で判断する事項

### アーキテクチャ方針

```
- コンポーネント設計パターン（Presentational/Container, Compound 等）
- 状態管理戦略（ローカル優先、必要時のみグローバル）
- データフェッチ戦略（SSR vs CSR vs ISR）
- コード分割・遅延読み込み戦略
```

### ディレクトリ構成

```
- Feature-Based Architecture を推奨
- app/ (ルーティング) と features/ (機能) の分離
- 共有コンポーネント、hooks、utils の配置
```

## 並列開発時の FE タスク管理

project-orchestrator から並列開発の FE タスクを委譲された場合の手順。

### worktree 作成

```bash
mkdir -p .worktrees

# 各 FE タスクの worktree + ブランチを作成
git worktree add .worktrees/task-{作業名} -b task/{作業名} feature/{機能名}
```

worktree 作成後のセットアップ:

```bash
cd .worktrees/task-{作業名}

# 1. .claude/ ディレクトリをコピー（gitignore 対象のため自動コピーされない）
if [ -d "../../.claude" ]; then
    cp -r "../../.claude" ".claude"
fi

# 2. 依存関係のインストール
pnpm install  # npm install / yarn install 等

# 3. プロジェクト固有のセットアップ（該当する場合）

# 4. Serena MCP の登録（worktree パスに紐づけ）
claude mcp add serena -- uvx --from git+https://github.com/oraios/serena serena-mcp-server --context ide-assistant --project $(pwd)
```

### こまめなコミットの徹底

worker / fix エージェントに以下のコミット方針を遵守させること:

- コンポーネント 1 つ、hook 1 つ等の変更単位ごとにコミット
- テストが通る状態を維持しつつ 15〜30 分ごとに中間コミット
- レビュー修正時は修正項目ごとにコミット
- スラッシュコマンド生成時にこの方針を明記すること

### スラッシュコマンド生成

各タスクの `worker-{タスク名}.md` を `.claude/commands/` に生成する。
テンプレートと品質チェックリストは project-orchestrator の [references/slash-command-templates.md](../project-orchestrator/references/slash-command-templates.md) を参照。

**生成時の FE 固有注意点:**
- コンポーネントの配置場所と命名規則を明記する
- デザイン要件（レスポンシブ、ダークモード等）を含める
- 状態管理の方針（Server Component / Client Component の使い分け等）を記載する

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

FE タスク間のコンフリクトは frontend-orchestrator の責務:

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

全 FE タスクの rebase + マージ完了後、project-orchestrator に報告:

```
=== FE タスク完了報告 ===

feature ブランチ: feature/{機能名}

【完了タスク】
- task/{作業名1}: {概要} ✅
- task/{作業名2}: {概要} ✅

【コンフリクト解消】
- {あれば記載、なければ「なし」}

【横断レビューで確認すべき点】
- {FE 側から見た BE との整合性に関する注意点}
```

## コードレビュー観点（FE）

### 正確性

```
- [ ] 要件を満たしているか
- [ ] エッジケース（空配列、null、長文、多言語）は処理されているか
- [ ] エラーハンドリング（API失敗、ネットワーク断）は適切か
- [ ] ローディング/エラー/空状態の UI があるか
```

### コンポーネント設計

```
- [ ] コンポーネントの責務は単一か
- [ ] Props の設計は適切か（過剰な props drilling がないか）
- [ ] Server Component と Client Component の使い分けは正しいか
- [ ] 再利用可能性は適切か（過度な抽象化を避ける）
```

### パフォーマンス

```
- [ ] 不要な再レンダリングがないか
- [ ] 大きなバンドルサイズの import がないか
- [ ] 画像は最適化されているか
- [ ] メモ化（useMemo, useCallback）は適切か（過度でないか）
```

### 状態管理

```
- [ ] 状態のスコープは適切か
- [ ] 不変性が保たれているか
- [ ] 非同期状態（loading, error, data）は管理されているか
- [ ] フォーム状態の管理は適切か
```

### セキュリティ

```
- [ ] XSS 脆弱性がないか（dangerouslySetInnerHTML 等）
- [ ] 機密情報がクライアントに露出していないか
- [ ] CSRF 対策が実装されているか
- [ ] 認証トークンの管理は適切か
```

### アクセシビリティ

```
- [ ] セマンティック HTML が使用されているか
- [ ] キーボード操作可能か
- [ ] alt テキスト、aria-label が適切か
- [ ] カラーコントラストは十分か
```

### スタイリング

```
- [ ] レスポンシブ対応されているか
- [ ] ダークモード対応（必要な場合）
- [ ] インラインスタイルが使われていないか
- [ ] デザインの一貫性が保たれているか
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
