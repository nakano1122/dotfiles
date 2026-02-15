---
name: cicd-github-actions
description: GitHub Actions ベースの CI/CD 設計・実装ガイド。ワークフロー設計原則、GitHub Actions 構文、CI パイプライン（lint/test/type-check/build）、CD パイプライン（ステージング/本番/ロールバック）、キャッシュ戦略、シークレット管理、再利用可能ワークフロー、セキュリティ設定をカバー。CI/CD パイプライン構築、GitHub Actions ワークフロー設計、自動化設定時に使用。
---

# CI/CD GitHub Actions ガイド

GitHub Actions ベースの CI/CD パイプライン設計・実装ガイド。

## ワークフロー設計の原則

```
1. 高速フィードバック: lint → type-check → test → build の順で実行
2. 失敗を早期検出: 軽い検査を先に実行（fast-fail）
3. 並列化: 独立したジョブは並列実行
4. キャッシュ活用: 依存関係とビルド成果物をキャッシュ
5. 最小権限: 必要最小限の permissions を設定
```

## GitHub Actions 基本構文

### ワークフロー構造

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  job-name:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Step name
        run: command
```

### トリガー

| トリガー | 用途 |
|---------|------|
| push | ブランチへのプッシュ時 |
| pull_request | PR の作成・更新時 |
| workflow_dispatch | 手動実行 |
| schedule | 定期実行（cron） |
| release | リリース作成時 |

### ジョブ間の依存

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    # ...
  test:
    needs: lint  # lint 完了後に実行
    runs-on: ubuntu-latest
    # ...
  deploy:
    needs: [lint, test]  # 両方完了後に実行
    if: github.ref == 'refs/heads/main'
```

## CI パイプライン

### 推奨ジョブ構成

```
PR / push 時:
  ├→ lint        (並列) コードスタイル検査
  ├→ type-check  (並列) 型検査
  ├→ test        (並列) テスト実行
  └→ build       (lint + type-check + test 完了後) ビルド検証
```

### マトリックス戦略

```yaml
strategy:
  matrix:
    node-version: [18, 20]
    os: [ubuntu-latest]
  fail-fast: true  # 1つ失敗したら全停止
```

### テスト結果の活用

```
- テストカバレッジをコメントで PR に表示
- テスト結果をアーティファクトとして保存
- 失敗時のログを分かりやすく表示
```

## CD パイプライン

### デプロイ戦略

```
ブランチ戦略:
  main → 本番環境
  develop → ステージング環境
  feature/* → プレビュー環境（必要に応じて）

デプロイフロー:
  1. CI パイプライン通過
  2. ステージングにデプロイ
  3. 動作確認（自動 or 手動）
  4. 本番にデプロイ
  5. ヘルスチェック
```

### 環境保護ルール

```yaml
jobs:
  deploy-production:
    environment:
      name: production
      url: https://example.com
    # GitHub の Environment protection rules で:
    # - Required reviewers（承認者の設定）
    # - Wait timer（待機時間）
    # - Deployment branches（デプロイ可能ブランチ）
```

### ロールバック

```
戦略:
  1. 前バージョンの成果物を再デプロイ
  2. Git revert → CI/CD で自動デプロイ
  3. Feature Flag で機能を無効化

準備:
  - デプロイ成果物を保存しておく
  - ロールバック手順を文書化
  - ロールバック用の手動ワークフロー
```

## キャッシュ戦略

### 依存関係のキャッシュ

```yaml
- uses: actions/setup-node@v4
  with:
    node-version: 20
    cache: 'pnpm'  # 自動でキャッシュ

# または手動設定
- uses: actions/cache@v4
  with:
    path: ~/.pnpm-store
    key: pnpm-${{ hashFiles('**/pnpm-lock.yaml') }}
    restore-keys: pnpm-
```

### ビルドキャッシュ

```
キャッシュ対象:
  - パッケージマネージャーのキャッシュ（pnpm, pip, go mod）
  - ビルド成果物（.next, dist）
  - Docker レイヤー

キャッシュキー設計:
  - ロックファイルのハッシュをキーに含める
  - OS とランタイムバージョンをキーに含める
  - restore-keys でフォールバック
```

## シークレットと環境変数

```
管理方法:
  - GitHub Secrets: リポジトリ or Organization レベル
  - GitHub Environments: 環境ごとのシークレット
  - OIDC: クラウドプロバイダーとの連携（長期キー不要）

原則:
  - シークレットをログに出力しない（自動マスクされる）
  - PR からのワークフローではシークレットアクセスを制限
  - 定期的なシークレットローテーション
  - 必要最小限のシークレットのみ設定
```

## 再利用可能ワークフロー

### Composite Actions

```yaml
# .github/actions/setup/action.yml
name: Setup
description: プロジェクトのセットアップ
runs:
  using: composite
  steps:
    - uses: actions/setup-node@v4
      with:
        node-version: 20
        cache: 'pnpm'
    - run: pnpm install --frozen-lockfile
      shell: bash
```

### Reusable Workflows

```yaml
# .github/workflows/reusable-test.yml
on:
  workflow_call:
    inputs:
      node-version:
        type: string
        default: '20'

# 呼び出し側
jobs:
  test:
    uses: ./.github/workflows/reusable-test.yml
    with:
      node-version: '20'
```

### 使い分け

```
Composite Actions: 複数ステップの共通処理
  → セットアップ、ビルド、通知など

Reusable Workflows: ジョブ全体の共通化
  → テスト実行、デプロイフローなど
```

## セキュリティ

### permissions の設定

```yaml
# ワークフローレベルで最小権限を設定
permissions:
  contents: read
  pull-requests: write  # PR コメント用

# ジョブレベルで上書き可能
jobs:
  deploy:
    permissions:
      contents: read
      id-token: write  # OIDC 用
```

### セキュリティのベストプラクティス

```
1. アクションのバージョン固定（SHA ピン留め推奨）
   ✅ uses: actions/checkout@v4  (最低限タグ固定)
   ✅ uses: actions/checkout@<sha>  (SHA固定が最も安全)

2. GITHUB_TOKEN の権限を最小化
3. サードパーティアクションの監査
4. fork からの PR でのシークレットアクセス制限
5. OpenSSF Scorecard での定期チェック
```

### supply chain セキュリティ

```
- 依存関係のロックファイルを使用
- Dependabot / Renovate で自動更新
- npm audit / pip audit を CI に組み込み
- SBOM（Software Bill of Materials）の生成
```

## レビューチェックリスト

- [ ] permissions が最小権限に設定されている
- [ ] アクションのバージョンが固定されている
- [ ] シークレットがログに露出しない
- [ ] キャッシュが適切に設定されている
- [ ] テスト失敗時にワークフローが失敗する
- [ ] 本番デプロイに承認フローがある
- [ ] ロールバック手順が用意されている

## リファレンス

- [references/workflow-examples.md](references/workflow-examples.md) - ワークフロー設定例
- [references/advanced-patterns.md](references/advanced-patterns.md) - 高度なパターン
