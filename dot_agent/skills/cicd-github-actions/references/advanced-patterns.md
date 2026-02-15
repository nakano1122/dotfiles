# GitHub Actions 高度なパターン集

実践で頻出する高度なパターンのリファレンス。
各パターンにはユースケース、コード例、注意点を記載する。

---

## 目次

- [1. パス/変更ベースのフィルタリング](#1-パス変更ベースのフィルタリング)
  - [組み込みの paths フィルタ](#組み込みの-paths-フィルタ)
  - [dorny/paths-filter による高度なフィルタリング](#dornypaths-filter-による高度なフィルタリング)
  - [paths-filter の変更タイプフィルタ](#paths-filter-の変更タイプフィルタ)
  - [設計ポイント](#設計ポイント)
- [2. 条件分岐パターン](#2-条件分岐パターン)
  - [if 式の基本](#if-式の基本)
  - [ジョブの outputs を使った条件分岐](#ジョブの-outputs-を使った条件分岐)
  - [環境変数を使った分岐](#環境変数を使った分岐)
  - [失敗時・常時実行](#失敗時常時実行)
  - [設計ポイント](#設計ポイント-1)
- [3. アーティファクト共有](#3-アーティファクト共有)
  - [ジョブ間でのアーティファクト受け渡し](#ジョブ間でのアーティファクト受け渡し)
  - [複数アーティファクトのマージダウンロード](#複数アーティファクトのマージダウンロード)
  - [設計ポイント](#設計ポイント-2)
- [4. Concurrency 制御](#4-concurrency-制御)
  - [基本的な Concurrency 設定](#基本的な-concurrency-設定)
  - [PR ごとの Concurrency](#pr-ごとの-concurrency)
  - [Environment ごとの排他制御](#environment-ごとの排他制御)
  - [設計ポイント](#設計ポイント-3)
- [5. 自動リリース](#5-自動リリース)
  - [semantic-release を使ったリリース](#semantic-release-を使ったリリース)
  - [Changesets を使ったリリース](#changesets-を使ったリリース)
  - [タグベースのリリース](#タグベースのリリース)
  - [設計ポイント](#設計ポイント-4)
- [6. Docker ビルドとレジストリプッシュ](#6-docker-ビルドとレジストリプッシュ)
  - [GitHub Container Registry (ghcr.io) へのプッシュ](#github-container-registry-ghcrio-へのプッシュ)
  - [Amazon ECR へのプッシュ](#amazon-ecr-へのプッシュ)
  - [設計ポイント](#設計ポイント-5)
- [7. OIDC によるクラウド認証](#7-oidc-によるクラウド認証)
  - [AWS](#aws)
  - [GCP](#gcp)
  - [設計ポイント](#設計ポイント-6)
- [8. Composite Action の設計パターン](#8-composite-action-の設計パターン)
  - [基本構造](#基本構造)
  - [Composite Action の利用](#composite-action-の利用)
  - [テスト実行 + レポートの汎用 Composite Action](#テスト実行-レポートの汎用-composite-action)
  - [設計ポイント](#設計ポイント-7)
- [9. ワークフローのデバッグ方法](#9-ワークフローのデバッグ方法)
  - [ACTIONS_RUNNER_DEBUG の有効化](#actions_runner_debug-の有効化)
  - [ステップ内でのデバッグ出力](#ステップ内でのデバッグ出力)
  - [act によるローカル実行](#act-によるローカル実行)
  - [設計ポイント](#設計ポイント-8)
- [10. コスト最適化](#10-コスト最適化)
  - [ランナー選択](#ランナー選択)
  - [キャッシュの最適化](#キャッシュの最適化)
  - [ジョブの統合による最適化](#ジョブの統合による最適化)
  - [タイムアウトの設定](#タイムアウトの設定)
  - [不要な実行のスキップ](#不要な実行のスキップ)
  - [コスト見積もりの目安](#コスト見積もりの目安)
  - [設計ポイント](#設計ポイント-9)

## 1. パス/変更ベースのフィルタリング

### 組み込みの paths フィルタ

```yaml
on:
  push:
    branches: [main]
    paths:
      - "src/**"
      - "package.json"
      - "pnpm-lock.yaml"
    paths-ignore:
      - "docs/**"
      - "**.md"
      - ".github/**"
```

**制約**: `paths` と `paths-ignore` は同じイベントに併用できない。どちらか一方のみ指定する。

### dorny/paths-filter による高度なフィルタリング

```yaml
jobs:
  detect:
    runs-on: ubuntu-latest
    outputs:
      backend: ${{ steps.filter.outputs.backend }}
      frontend: ${{ steps.filter.outputs.frontend }}
      backend_files: ${{ steps.filter.outputs.backend_files }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          # 変更されたファイルの一覧も取得可能
          list-files: json
          filters: |
            backend:
              - 'src/api/**'
              - 'src/models/**'
            frontend:
              - 'src/web/**'
              - 'src/components/**'
            config:
              - added|modified: '*.config.*'

  backend-ci:
    needs: detect
    if: needs.detect.outputs.backend == 'true'
    runs-on: ubuntu-latest
    steps:
      - run: echo "バックエンドの変更を検出"
```

### paths-filter の変更タイプフィルタ

```yaml
filters: |
  src:
    - added|modified: 'src/**'       # 追加・変更のみ (削除は無視)
  deleted:
    - deleted: 'src/**'              # 削除のみ
  any:
    - 'src/**'                       # すべての変更タイプ
```

### 設計ポイント

- 組み込みの `paths` はワークフロー自体の実行をスキップする（ジョブが0件になる）
- `dorny/paths-filter` はジョブレベルでの制御が可能でより柔軟
- モノレポでは `dorny/paths-filter` を推奨
- `paths-ignore` でドキュメントやメタファイルの変更を除外するのが一般的

---

## 2. 条件分岐パターン

### if 式の基本

```yaml
jobs:
  deploy:
    # main ブランチへの push のみ
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
    steps:
      - name: PR からのみ実行
        if: github.event_name == 'pull_request'
        run: echo "PR トリガー"

      - name: 特定のラベルがある場合
        if: contains(github.event.pull_request.labels.*.name, 'deploy')
        run: echo "deploy ラベル付き"

      - name: 特定のユーザーの場合
        if: github.actor == 'dependabot[bot]'
        run: echo "Dependabot による変更"
```

### ジョブの outputs を使った条件分岐

```yaml
jobs:
  check:
    runs-on: ubuntu-latest
    outputs:
      should-deploy: ${{ steps.check.outputs.deploy }}
      version: ${{ steps.version.outputs.value }}
    steps:
      - id: check
        run: |
          if [[ "${{ github.event.head_commit.message }}" == *"[deploy]"* ]]; then
            echo "deploy=true" >> "$GITHUB_OUTPUT"
          else
            echo "deploy=false" >> "$GITHUB_OUTPUT"
          fi
      - id: version
        run: echo "value=$(jq -r .version package.json)" >> "$GITHUB_OUTPUT"

  deploy:
    needs: check
    if: needs.check.outputs.should-deploy == 'true'
    runs-on: ubuntu-latest
    steps:
      - run: echo "デプロイ: v${{ needs.check.outputs.version }}"
```

### 環境変数を使った分岐

```yaml
env:
  IS_MAIN: ${{ github.ref == 'refs/heads/main' }}

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: 本番ビルド
        if: env.IS_MAIN == 'true'
        run: npm run build:prod
      - name: 開発ビルド
        if: env.IS_MAIN != 'true'
        run: npm run build:dev
```

### 失敗時・常時実行

```yaml
steps:
  - name: テスト
    id: test
    run: npm test
    continue-on-error: true

  - name: テスト結果に関わらず常に実行
    if: always()
    run: echo "クリーンアップ"

  - name: テスト失敗時のみ実行
    if: failure()
    run: echo "テストが失敗しました"

  - name: 前のステップが失敗した場合
    if: steps.test.outcome == 'failure'
    run: echo "テストステップが失敗"

  - name: キャンセル時のみ実行
    if: cancelled()
    run: echo "ワークフローがキャンセルされました"
```

### 設計ポイント

- `if` 式では `${{ }}` を省略可能（ジョブレベルの `if` では自動的に式として評価される）
- `always()`, `failure()`, `cancelled()` は他の条件と `&&` で組み合わせ可能
- `continue-on-error: true` と `steps.<id>.outcome` で柔軟なエラーハンドリングが可能
- outputs は文字列型のみ。真偽値は `'true'` / `'false'` の文字列比較になる

---

## 3. アーティファクト共有

### ジョブ間でのアーティファクト受け渡し

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm run build
      - uses: actions/upload-artifact@v4
        with:
          name: build-output
          path: |
            dist/
            !dist/**/*.map
          retention-days: 1
          compression-level: 6

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: build-output
          path: dist/
      - run: ls -la dist/

  test-report:
    runs-on: ubuntu-latest
    steps:
      - run: npm test -- --reporter=junit --output-file=report.xml
      - uses: actions/upload-artifact@v4
        if: always()  # テスト失敗時もレポートをアップロード
        with:
          name: test-report
          path: report.xml
          retention-days: 30
```

### 複数アーティファクトのマージダウンロード

```yaml
jobs:
  test:
    strategy:
      matrix:
        shard: [1, 2, 3, 4]
    runs-on: ubuntu-latest
    steps:
      - run: npm test -- --shard=${{ matrix.shard }}/4
      - uses: actions/upload-artifact@v4
        with:
          name: coverage-${{ matrix.shard }}
          path: coverage/

  merge-coverage:
    needs: test
    runs-on: ubuntu-latest
    steps:
      # すべてのシャードのカバレッジを一括ダウンロード
      - uses: actions/download-artifact@v4
        with:
          pattern: coverage-*
          merge-multiple: true
          path: coverage/
      - run: npx nyc merge coverage/ merged-coverage.json
```

### 設計ポイント

- `retention-days` でアーティファクトの保持期間を制御（デフォルト 90 日、最小 1 日）
- `compression-level` で圧縮レベルを指定（0: 無圧縮、6: デフォルト、9: 最大圧縮）
- `if: always()` でテスト失敗時もレポートをアップロード
- `merge-multiple: true` でパターンマッチした複数アーティファクトを1つのディレクトリにマージ
- アーティファクトはワークフロー実行間では共有できない（同一ワークフロー内のジョブ間のみ）

---

## 4. Concurrency 制御

### 基本的な Concurrency 設定

```yaml
# ワークフローレベル
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

# ジョブレベル（デプロイの場合）
jobs:
  deploy:
    concurrency:
      group: deploy-${{ inputs.environment }}
      cancel-in-progress: false  # デプロイは途中キャンセルしない
```

### PR ごとの Concurrency

```yaml
concurrency:
  # PR の場合は PR 番号、push の場合はブランチ名でグループ化
  group: ci-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true
```

### Environment ごとの排他制御

```yaml
jobs:
  deploy-staging:
    environment: staging
    concurrency:
      group: deploy-staging
      cancel-in-progress: false

  deploy-production:
    environment: production
    concurrency:
      group: deploy-production
      cancel-in-progress: false
```

### 設計ポイント

- `cancel-in-progress: true` は CI に適している（最新のコミットの結果だけが重要）
- `cancel-in-progress: false` はデプロイに適している（途中で中断すると不整合が生じる）
- concurrency group はリポジトリ全体でグローバルに一意である必要がある
- Environment の concurrency とワークフローの concurrency は独立して動作する

---

## 5. 自動リリース

### semantic-release を使ったリリース

```yaml
name: Release

on:
  push:
    branches: [main]

permissions:
  contents: write
  issues: write
  pull-requests: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          # semantic-release がタグ・コミットを push するために PAT が必要
          token: ${{ secrets.RELEASE_TOKEN }}
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci
      - run: npx semantic-release
        env:
          GITHUB_TOKEN: ${{ secrets.RELEASE_TOKEN }}
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
```

### Changesets を使ったリリース

```yaml
name: Release

on:
  push:
    branches: [main]

permissions:
  contents: write
  pull-requests: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: pnpm
      - run: pnpm install --frozen-lockfile
      - name: バージョン PR の作成またはパッケージの公開
        uses: changesets/action@v1
        with:
          version: pnpm changeset version
          publish: pnpm changeset publish
          title: "chore(release): バージョン更新"
          commit: "chore(release): version packages"
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
```

### タグベースのリリース

```yaml
name: Release

on:
  push:
    tags:
      - "v*"

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci
      - run: npm run build
      - name: GitHub Release 作成
        uses: softprops/action-gh-release@v2
        with:
          generate_release_notes: true
          files: |
            dist/*.tar.gz
            dist/*.zip
```

### 設計ポイント

- semantic-release: コミットメッセージ規約（Conventional Commits）からバージョンを自動決定
- Changesets: 開発者が明示的に変更内容を記述し、PR でバージョンを管理
- タグベース: 手動でタグを打ってリリースをトリガー
- `GITHUB_TOKEN` ではなく PAT を使う必要がある場合がある（semantic-release のタグ push 等）
- `fetch-depth: 0` でコミット履歴全体を取得（バージョン決定に必要）

---

## 6. Docker ビルドとレジストリプッシュ

### GitHub Container Registry (ghcr.io) へのプッシュ

```yaml
name: Docker Build

on:
  push:
    branches: [main]
    tags: ["v*"]
  pull_request:
    branches: [main]

permissions:
  contents: read
  packages: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Docker メタデータ
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            # ブランチ名
            type=ref,event=branch
            # PR 番号
            type=ref,event=pr
            # セマンティックバージョン
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=semver,pattern={{major}}
            # コミット SHA (短縮)
            type=sha,prefix=

      - uses: docker/setup-buildx-action@v3

      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: docker/build-push-action@v6
        with:
          context: .
          # PR の場合はプッシュしない
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          # マルチプラットフォーム
          platforms: linux/amd64,linux/arm64
```

### Amazon ECR へのプッシュ

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/ecr-push
          aws-region: ap-northeast-1
      - uses: aws-actions/amazon-ecr-login@v2
        id: ecr
      - uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ steps.ecr.outputs.registry }}/my-app:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

### 設計ポイント

- `docker/metadata-action` でタグ・ラベルを自動生成（ブランチ、PR、セマンティックバージョン等）
- `cache-from: type=gha` / `cache-to: type=gha,mode=max` で GitHub Actions Cache をビルドキャッシュに利用
- `mode=max` はすべてのレイヤーをキャッシュ（ビルド時間短縮に効果的）
- PR ではビルドのみ実行し、プッシュしない（`push: ${{ github.event_name != 'pull_request' }}`）
- マルチプラットフォームビルドは `platforms` で指定

---

## 7. OIDC によるクラウド認証

### AWS

```yaml
permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-actions
          aws-region: ap-northeast-1
          # オプション: セッション名をカスタマイズ
          role-session-name: github-actions-${{ github.run_id }}
      - run: aws sts get-caller-identity
```

**AWS 側の設定 (Terraform 例)**:

```hcl
# OIDC プロバイダー
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["ffffffffffffffffffffffffffffffffffffffff"]
}

# IAM ロール
resource "aws_iam_role" "github_actions" {
  name = "github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # リポジトリとブランチを制限
          "token.actions.githubusercontent.com:sub" = "repo:owner/repo:ref:refs/heads/main"
        }
      }
    }]
  })
}
```

### GCP

```yaml
permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: projects/123456789/locations/global/workloadIdentityPools/github/providers/github
          service_account: github-actions@project-id.iam.gserviceaccount.com
      - uses: google-github-actions/setup-gcloud@v2
      - run: gcloud info
```

**GCP 側の設定 (gcloud 例)**:

```bash
# Workload Identity Pool の作成
gcloud iam workload-identity-pools create github \
  --location="global" \
  --display-name="GitHub Actions"

# Provider の作成
gcloud iam workload-identity-pools providers create-oidc github \
  --location="global" \
  --workload-identity-pool="github" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --attribute-condition="assertion.repository=='owner/repo'"

# サービスアカウントへのバインド
gcloud iam service-accounts add-iam-policy-binding \
  github-actions@project-id.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/123456789/locations/global/workloadIdentityPools/github/attribute.repository/owner/repo"
```

### 設計ポイント

- OIDC を使えば長期間有効なアクセスキーやシークレットが不要になる
- `id-token: write` 権限が必須
- クラウド側でリポジトリ・ブランチ単位のアクセス制御が可能
- 本番環境へのアクセスは `refs/heads/main` のみに制限するのが推奨
- OIDC トークンの有効期間は短い（デフォルト数分）ため、セキュリティリスクが低い

---

## 8. Composite Action の設計パターン

### 基本構造

```yaml
# .github/actions/setup-project/action.yml
name: プロジェクトセットアップ
description: Node.js プロジェクトの共通セットアップ

inputs:
  node-version:
    description: Node.js バージョン
    required: false
    default: "20"
  install-command:
    description: インストールコマンド
    required: false
    default: "pnpm install --frozen-lockfile"

outputs:
  cache-hit:
    description: キャッシュがヒットしたかどうか
    value: ${{ steps.cache.outputs.cache-hit }}

runs:
  using: composite
  steps:
    - uses: pnpm/action-setup@v4
      shell: bash

    - uses: actions/setup-node@v4
      with:
        node-version: ${{ inputs.node-version }}
        cache: pnpm

    - id: cache
      uses: actions/cache@v4
      with:
        path: node_modules
        key: node-modules-${{ hashFiles('pnpm-lock.yaml') }}

    - if: steps.cache.outputs.cache-hit != 'true'
      run: ${{ inputs.install-command }}
      shell: bash
```

### Composite Action の利用

```yaml
# .github/workflows/ci.yml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-project
        with:
          node-version: "20"
      - run: pnpm lint

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-project
      - run: pnpm test
```

### テスト実行 + レポートの汎用 Composite Action

```yaml
# .github/actions/run-tests/action.yml
name: テスト実行
description: テストを実行してレポートをアップロード

inputs:
  test-command:
    description: テスト実行コマンド
    required: true
  report-name:
    description: レポートのアーティファクト名
    required: false
    default: test-report

runs:
  using: composite
  steps:
    - name: テスト実行
      id: test
      run: ${{ inputs.test-command }}
      shell: bash
      continue-on-error: true

    - name: テストレポートのアップロード
      if: always()
      uses: actions/upload-artifact@v4
      with:
        name: ${{ inputs.report-name }}
        path: |
          **/junit-report.xml
          **/coverage/
        retention-days: 7

    - name: テスト失敗時にエラーを返す
      if: steps.test.outcome == 'failure'
      run: exit 1
      shell: bash
```

### 設計ポイント

- Composite Action はリポジトリ内で再利用可能な処理をまとめるのに最適
- `shell: bash` はすべての `run` ステップで必須（Composite Action では自動推論されない）
- 入力にデフォルト値を設定して使いやすくする
- `continue-on-error` + 後続ステップで柔軟なエラーハンドリングが可能
- 別リポジトリの Composite Action も `uses: owner/repo/.github/actions/name@v1` で参照可能

---

## 9. ワークフローのデバッグ方法

### ACTIONS_RUNNER_DEBUG の有効化

```yaml
# リポジトリの Settings > Secrets and variables > Actions で設定
# Variables に以下を追加:
#   ACTIONS_RUNNER_DEBUG = true
#   ACTIONS_STEP_DEBUG = true

# または workflow_dispatch で動的に有効化
on:
  workflow_dispatch:
    inputs:
      debug:
        description: デバッグモードを有効にする
        type: boolean
        default: false

env:
  ACTIONS_RUNNER_DEBUG: ${{ inputs.debug }}
  ACTIONS_STEP_DEBUG: ${{ inputs.debug }}
```

### ステップ内でのデバッグ出力

```yaml
steps:
  - name: コンテキスト情報を出力
    run: |
      echo "--- github context ---"
      echo '${{ toJSON(github) }}'
      echo "--- env context ---"
      echo '${{ toJSON(env) }}'
      echo "--- runner context ---"
      echo '${{ toJSON(runner) }}'

  - name: グループ化されたログ出力
    run: |
      echo "::group::詳細なデバッグ情報"
      echo "変数1: $VAR1"
      echo "変数2: $VAR2"
      ls -la
      echo "::endgroup::"

  - name: 警告・エラーのアノテーション
    run: |
      echo "::warning file=app.js,line=1::非推奨の関数が使われています"
      echo "::error file=app.js,line=10::必須フィールドが未定義です"
      echo "::notice::ビルドが完了しました"
```

### act によるローカル実行

```bash
# インストール
brew install act

# ワークフローをローカルで実行
act push

# 特定のジョブだけ実行
act -j build

# シークレットを指定して実行
act push --secret-file .secrets

# 特定のイベントペイロードで実行
act pull_request --eventpath event.json

# Ubuntu ランナーイメージの指定
act push -P ubuntu-latest=catthehacker/ubuntu:act-latest

# ドライラン (実行せずジョブグラフを確認)
act push --list

# 環境変数を渡す
act push --env MY_VAR=value
```

**.secrets ファイルの例**:

```
GITHUB_TOKEN=ghp_xxxxxxxxxxxx
NPM_TOKEN=npm_xxxxxxxxxxxx
```

**.actrc ファイルの例**:

```
-P ubuntu-latest=catthehacker/ubuntu:act-latest
--container-architecture linux/amd64
```

### 設計ポイント

- `ACTIONS_RUNNER_DEBUG` は runner レベル、`ACTIONS_STEP_DEBUG` はステップレベルの詳細ログ
- `toJSON()` でコンテキストオブジェクト全体をダンプして確認
- `::group::` / `::endgroup::` でログを折りたたみ可能
- `act` はローカルで素早くテストするのに便利だが、すべての機能を再現できるわけではない
- `act` では `GITHUB_TOKEN` や OIDC 等の GitHub 固有機能は使えない

---

## 10. コスト最適化

### ランナー選択

```yaml
jobs:
  # 軽量な処理は ubuntu-latest (2 core, 7GB RAM)
  lint:
    runs-on: ubuntu-latest
    steps:
      - run: npm run lint

  # 重い処理には Larger Runner (要 GitHub Team/Enterprise)
  build:
    runs-on: ubuntu-latest-4-cores  # 4 core, 16GB RAM
    steps:
      - run: npm run build

  # ARM ランナー (料金が安い、GitHub Team/Enterprise)
  test:
    runs-on: ubuntu-latest-arm64
    steps:
      - run: npm test
```

### キャッシュの最適化

```yaml
steps:
  # pnpm: setup-node の cache 機能を使う (最も簡単)
  - uses: actions/setup-node@v4
    with:
      node-version: 20
      cache: pnpm

  # より細かいキャッシュ制御が必要な場合
  - uses: actions/cache@v4
    id: cache
    with:
      path: |
        node_modules
        ~/.cache/Cypress
      key: deps-${{ runner.os }}-${{ hashFiles('pnpm-lock.yaml') }}
      restore-keys: |
        deps-${{ runner.os }}-

  # キャッシュミス時のみインストール
  - if: steps.cache.outputs.cache-hit != 'true'
    run: pnpm install --frozen-lockfile
```

### ジョブの統合による最適化

```yaml
# 非推奨: ジョブを分割しすぎ (各ジョブでランナー起動 + checkout のオーバーヘッド)
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run lint

  format:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run format:check

# 推奨: 軽量なチェックは1つのジョブにまとめる
jobs:
  checks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run lint
      - run: npm run format:check
      - run: npm run type-check
```

### タイムアウトの設定

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 15  # デフォルト 360 分 (6 時間) は長すぎる
    steps:
      - name: 個別ステップのタイムアウト
        timeout-minutes: 5
        run: npm test
```

### 不要な実行のスキップ

```yaml
on:
  push:
    branches: [main]
    # ドキュメントの変更では CI を実行しない
    paths-ignore:
      - "docs/**"
      - "**.md"
      - ".gitignore"
      - "LICENSE"

jobs:
  ci:
    # Dependabot の PR は別ワークフローで処理
    if: github.actor != 'dependabot[bot]'
    runs-on: ubuntu-latest
    steps:
      - run: echo "CI"
```

### コスト見積もりの目安

| ランナー | 料金 (分あたり) | 備考 |
|---------|---------------|------|
| ubuntu-latest (2 core) | $0.008 | パブリックリポジトリは無料 |
| ubuntu-latest-4-cores | $0.016 | GitHub Team/Enterprise |
| ubuntu-latest-arm64 | $0.005 | GitHub Team/Enterprise |
| macos-latest | $0.08 | ubuntu の 10 倍 |
| windows-latest | $0.016 | ubuntu の 2 倍 |

### 設計ポイント

- パブリックリポジトリは Linux/macOS/Windows すべて無料
- プライベートリポジトリは月の無料枠を超えると課金される（Free: 2,000分/月、Pro: 3,000分/月）
- macOS ランナーは高額なので、macOS 固有のテスト以外では使わない
- `timeout-minutes` は必ず設定する（無限ループや応答のないプロセスによる無駄な課金を防ぐ）
- 軽量なチェック（lint, format, type-check）は1つのジョブにまとめてオーバーヘッドを削減
- キャッシュを活用して `npm ci` / `pnpm install` の時間を短縮
- `paths-ignore` で不要なワークフロー実行を回避
