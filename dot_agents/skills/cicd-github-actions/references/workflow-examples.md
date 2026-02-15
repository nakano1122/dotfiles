# GitHub Actions ワークフロー例集

実践的なワークフロー YAML の完全な例を集めたリファレンス。
コピー＆ペーストで使える形式にしてある。

---

## 目次

- [1. TypeScript (pnpm) プロジェクトの CI](#1-typescript-pnpm-プロジェクトの-ci)
  - [ジョブ依存関係の図](#ジョブ依存関係の図)
  - [設計ポイント](#設計ポイント)
- [2. Python (uv) プロジェクトの CI](#2-python-uv-プロジェクトの-ci)
  - [pip を使う場合の代替](#pip-を使う場合の代替)
  - [設計ポイント](#設計ポイント-1)
- [3. Go プロジェクトの CI](#3-go-プロジェクトの-ci)
  - [設計ポイント](#設計ポイント-2)
- [4. モノレポの CI (変更検出 + affected パッケージのみ実行)](#4-モノレポの-ci-変更検出-affected-パッケージのみ実行)
  - [Turborepo を使う場合の代替](#turborepo-を使う場合の代替)
  - [設計ポイント](#設計ポイント-3)
- [5. CD ワークフロー (ステージング → 本番、承認付き)](#5-cd-ワークフロー-ステージング-本番承認付き)
  - [デプロイフロー](#デプロイフロー)
  - [設計ポイント](#設計ポイント-4)
- [6. 定期実行ワークフロー](#6-定期実行ワークフロー)
  - [依存関係チェック](#依存関係チェック)
  - [ヘルスチェック](#ヘルスチェック)
  - [設計ポイント](#設計ポイント-5)
- [7. 手動実行ワークフロー (ロールバック用)](#7-手動実行ワークフロー-ロールバック用)
  - [設計ポイント](#設計ポイント-6)

## 1. TypeScript (pnpm) プロジェクトの CI

lint, type-check, test, build を並列＋依存関係で構成する例。

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  install:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: pnpm
      - run: pnpm install --frozen-lockfile
      # node_modules をキャッシュして後続ジョブで再利用
      - uses: actions/cache/save@v4
        with:
          path: node_modules
          key: node-modules-${{ hashFiles('pnpm-lock.yaml') }}

  lint:
    needs: install
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - uses: actions/cache/restore@v4
        with:
          path: node_modules
          key: node-modules-${{ hashFiles('pnpm-lock.yaml') }}
      - run: pnpm lint

  type-check:
    needs: install
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - uses: actions/cache/restore@v4
        with:
          path: node_modules
          key: node-modules-${{ hashFiles('pnpm-lock.yaml') }}
      - run: pnpm tsc --noEmit

  test:
    needs: install
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - uses: actions/cache/restore@v4
        with:
          path: node_modules
          key: node-modules-${{ hashFiles('pnpm-lock.yaml') }}
      - run: pnpm test -- --coverage
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: coverage-report
          path: coverage/

  build:
    needs: [lint, type-check, test]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - uses: actions/cache/restore@v4
        with:
          path: node_modules
          key: node-modules-${{ hashFiles('pnpm-lock.yaml') }}
      - run: pnpm build
      - uses: actions/upload-artifact@v4
        with:
          name: build-output
          path: dist/
```

### ジョブ依存関係の図

```
install
  ├── lint ──────────┐
  ├── type-check ────┼── build
  └── test ──────────┘
```

### 設計ポイント

- `install` ジョブで `node_modules` をキャッシュし、後続ジョブで復元する
- lint / type-check / test は互いに独立なので並列実行
- build はすべてのチェックが通った後にだけ実行
- `concurrency` でブランチ単位の重複実行を防止

---

## 2. Python (uv) プロジェクトの CI

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
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v4
        with:
          enable-cache: true
      - run: uv sync --frozen
      - run: uv run ruff check .
      - run: uv run ruff format --check .

  type-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v4
        with:
          enable-cache: true
      - run: uv sync --frozen
      - run: uv run mypy src/

  test:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        python-version: ["3.11", "3.12", "3.13"]
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v4
        with:
          enable-cache: true
      - run: uv python install ${{ matrix.python-version }}
      - run: uv sync --frozen
      - run: uv run pytest --cov=src --cov-report=xml
      - uses: actions/upload-artifact@v4
        if: matrix.python-version == '3.12'
        with:
          name: coverage-report
          path: coverage.xml
```

### pip を使う場合の代替

```yaml
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: ["3.11", "3.12", "3.13"]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
          cache: pip
      - run: pip install -e ".[dev]"
      - run: pytest --cov=src --cov-report=xml
```

### 設計ポイント

- `uv` は `astral-sh/setup-uv` で導入し、`enable-cache: true` で自動キャッシュ
- `--frozen` で lockfile との整合性を保証
- マトリクスで複数 Python バージョンを並列テスト
- `fail-fast: false` で1つ失敗しても他バージョンの結果を確認可能

---

## 3. Go プロジェクトの CI

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
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - uses: golangci/golangci-lint-action@v6
        with:
          version: latest

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - run: go test -race -coverprofile=coverage.out ./...
      - run: go tool cover -func=coverage.out

  build:
    needs: [lint, test]
    runs-on: ubuntu-latest
    strategy:
      matrix:
        goos: [linux, darwin, windows]
        goarch: [amd64, arm64]
        exclude:
          - goos: windows
            goarch: arm64
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - run: |
          GOOS=${{ matrix.goos }} GOARCH=${{ matrix.goarch }} \
            go build -ldflags="-s -w" -o bin/app-${{ matrix.goos }}-${{ matrix.goarch }} ./cmd/app
      - uses: actions/upload-artifact@v4
        with:
          name: binary-${{ matrix.goos }}-${{ matrix.goarch }}
          path: bin/

  vulnerability-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - run: go install golang.org/x/vuln/cmd/govulncheck@latest
      - run: govulncheck ./...
```

### 設計ポイント

- `go-version-file: go.mod` で go.mod に記載されたバージョンを自動使用
- `actions/setup-go` はモジュールキャッシュを自動管理
- `-race` フラグでデータ競合を検出
- クロスコンパイルでマルチプラットフォームバイナリを生成
- `govulncheck` で既知の脆弱性をチェック

---

## 4. モノレポの CI (変更検出 + affected パッケージのみ実行)

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
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      api: ${{ steps.filter.outputs.api }}
      web: ${{ steps.filter.outputs.web }}
      shared: ${{ steps.filter.outputs.shared }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            api:
              - 'packages/api/**'
              - 'packages/shared/**'
            web:
              - 'packages/web/**'
              - 'packages/shared/**'
            shared:
              - 'packages/shared/**'

  ci-api:
    needs: detect-changes
    if: needs.detect-changes.outputs.api == 'true'
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: packages/api
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: pnpm
      - run: pnpm install --frozen-lockfile
        working-directory: .
      - run: pnpm lint
      - run: pnpm test
      - run: pnpm build

  ci-web:
    needs: detect-changes
    if: needs.detect-changes.outputs.web == 'true'
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: packages/web
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: pnpm
      - run: pnpm install --frozen-lockfile
        working-directory: .
      - run: pnpm lint
      - run: pnpm test
      - run: pnpm build

  ci-shared:
    needs: detect-changes
    if: needs.detect-changes.outputs.shared == 'true'
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: packages/shared
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: pnpm
      - run: pnpm install --frozen-lockfile
        working-directory: .
      - run: pnpm lint
      - run: pnpm test
      - run: pnpm build

  # すべての CI ジョブの結果を集約するゲートジョブ
  # ブランチ保護ルールではこのジョブだけを必須にする
  ci-gate:
    if: always()
    needs: [ci-api, ci-web, ci-shared]
    runs-on: ubuntu-latest
    steps:
      - name: すべてのジョブが成功したか確認
        run: |
          results=("${{ needs.ci-api.result }}" "${{ needs.ci-web.result }}" "${{ needs.ci-shared.result }}")
          for result in "${results[@]}"; do
            if [[ "$result" == "failure" || "$result" == "cancelled" ]]; then
              echo "ジョブが失敗またはキャンセルされました: $result"
              exit 1
            fi
          done
          echo "すべてのジョブが成功またはスキップされました"
```

### Turborepo を使う場合の代替

```yaml
name: CI (Turborepo)

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: pnpm
      - run: pnpm install --frozen-lockfile
      # main ブランチとの差分から affected パッケージを自動検出
      - run: pnpm turbo run lint test build --filter="...[origin/main...HEAD]"
```

### 設計ポイント

- `dorny/paths-filter` でパッケージごとの変更を検出
- shared ライブラリの変更時は依存パッケージも CI を実行
- `ci-gate` ジョブでブランチ保護を一元管理（スキップされたジョブも成功扱い）
- Turborepo を使う場合は `--filter` で affected パッケージだけ実行可能

---

## 5. CD ワークフロー (ステージング → 本番、承認付き)

```yaml
name: CD

on:
  push:
    branches: [main]

permissions:
  contents: read
  id-token: write  # OIDC 認証用

# 同時に1つのデプロイだけ実行
concurrency:
  group: deploy
  cancel-in-progress: false  # デプロイは途中キャンセルしない

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
    steps:
      - uses: actions/checkout@v4
      - name: Docker メタデータ生成
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
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
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  deploy-staging:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: staging
      url: https://staging.example.com
    steps:
      - uses: actions/checkout@v4
      - name: AWS 認証 (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/deploy-staging
          aws-region: ap-northeast-1
      - name: ステージングにデプロイ
        run: |
          aws ecs update-service \
            --cluster staging \
            --service app \
            --force-new-deployment

  integration-test:
    needs: deploy-staging
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: ステージング環境のヘルスチェック
        run: |
          for i in $(seq 1 30); do
            status=$(curl -s -o /dev/null -w "%{http_code}" https://staging.example.com/health)
            if [ "$status" = "200" ]; then
              echo "ヘルスチェック成功"
              exit 0
            fi
            echo "待機中... ($i/30)"
            sleep 10
          done
          echo "ヘルスチェック失敗"
          exit 1
      - name: E2E テスト実行
        run: |
          npx playwright test --config=e2e/playwright.config.ts
        env:
          BASE_URL: https://staging.example.com

  deploy-production:
    needs: integration-test
    runs-on: ubuntu-latest
    # GitHub の Environment 設定で承認者を指定
    environment:
      name: production
      url: https://example.com
    steps:
      - uses: actions/checkout@v4
      - name: AWS 認証 (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/deploy-production
          aws-region: ap-northeast-1
      - name: 本番にデプロイ
        run: |
          aws ecs update-service \
            --cluster production \
            --service app \
            --force-new-deployment
      - name: 本番ヘルスチェック
        run: |
          for i in $(seq 1 30); do
            status=$(curl -s -o /dev/null -w "%{http_code}" https://example.com/health)
            if [ "$status" = "200" ]; then
              echo "本番ヘルスチェック成功"
              exit 0
            fi
            echo "待機中... ($i/30)"
            sleep 10
          done
          echo "本番ヘルスチェック失敗"
          exit 1
```

### デプロイフロー

```
build → deploy-staging → integration-test → [承認] → deploy-production
```

### 設計ポイント

- `environment` で GitHub の Environment protection rules を利用
- production 環境には承認者（reviewers）を設定し、手動承認を必須にする
- `concurrency` でデプロイの同時実行を防止（`cancel-in-progress: false` で途中キャンセルしない）
- OIDC でクラウド認証（長期間有効なシークレットを使わない）
- ステージングで E2E テストを実行してから本番にデプロイ

---

## 6. 定期実行ワークフロー

### 依存関係チェック

```yaml
name: 依存関係チェック

on:
  schedule:
    # 毎週月曜 9:00 JST (日曜 24:00 UTC)
    - cron: "0 0 * * 1"
  workflow_dispatch: {}

permissions:
  contents: write
  pull-requests: write

jobs:
  dependency-update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: pnpm
      - run: pnpm install --frozen-lockfile
      - name: 脆弱性チェック
        run: pnpm audit --audit-level=high
        continue-on-error: true
      - name: 古い依存関係の確認
        run: pnpm outdated || true
      - name: 依存関係の更新
        run: |
          pnpm update --latest
          if git diff --quiet pnpm-lock.yaml; then
            echo "更新なし"
            exit 0
          fi
      - name: PR を作成
        if: success()
        uses: peter-evans/create-pull-request@v7
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          branch: chore/dependency-update
          title: "chore(deps): 依存関係の更新"
          body: |
            自動生成された依存関係の更新 PR です。
            変更内容を確認し、CI が通ることを確認してからマージしてください。
          commit-message: "chore(deps): update dependencies"
```

### ヘルスチェック

```yaml
name: ヘルスチェック

on:
  schedule:
    # 5分ごと
    - cron: "*/5 * * * *"
  workflow_dispatch: {}

jobs:
  health-check:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        target:
          - name: Production
            url: https://example.com/health
          - name: Staging
            url: https://staging.example.com/health
    steps:
      - name: "${{ matrix.target.name }} ヘルスチェック"
        run: |
          status=$(curl -s -o /dev/null -w "%{http_code}" \
            --max-time 10 "${{ matrix.target.url }}")
          if [ "$status" != "200" ]; then
            echo "::error::${{ matrix.target.name }} が応答しません (HTTP $status)"
            exit 1
          fi
          echo "${{ matrix.target.name }}: 正常 (HTTP $status)"

  notify-on-failure:
    needs: health-check
    if: failure()
    runs-on: ubuntu-latest
    steps:
      - name: Slack 通知
        uses: slackapi/slack-github-action@v2
        with:
          webhook: ${{ secrets.SLACK_WEBHOOK_URL }}
          webhook-type: incoming-webhook
          payload: |
            {
              "text": ":rotating_light: ヘルスチェック失敗\n環境: ${{ github.workflow }}\n詳細: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
            }
```

### 設計ポイント

- `schedule` の cron は UTC で指定する（JST = UTC + 9）
- `workflow_dispatch` を併用して手動実行も可能にする
- 依存関係更新は PR を自動作成し、人間がレビュー・マージする運用が安全
- ヘルスチェックの失敗時は Slack 等に通知を飛ばす
- GitHub Actions の schedule は正確な時刻を保証しない（数分の遅延がありうる）

---

## 7. 手動実行ワークフロー (ロールバック用)

```yaml
name: ロールバック

on:
  workflow_dispatch:
    inputs:
      environment:
        description: "デプロイ先環境"
        required: true
        type: choice
        options:
          - staging
          - production
      image-tag:
        description: "ロールバック先のイメージタグ (例: abc1234)"
        required: true
        type: string
      reason:
        description: "ロールバックの理由"
        required: true
        type: string

permissions:
  contents: read
  id-token: write

concurrency:
  group: deploy-${{ inputs.environment }}
  cancel-in-progress: false

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: 入力値の検証
        run: |
          echo "環境: ${{ inputs.environment }}"
          echo "イメージタグ: ${{ inputs.image-tag }}"
          echo "理由: ${{ inputs.reason }}"

          # イメージタグの形式チェック (短い SHA)
          if [[ ! "${{ inputs.image-tag }}" =~ ^[a-f0-9]{7,40}$ ]]; then
            echo "::error::イメージタグの形式が不正です"
            exit 1
          fi

  confirm-production:
    needs: validate
    if: inputs.environment == 'production'
    runs-on: ubuntu-latest
    environment:
      name: production-rollback
    steps:
      - name: 本番ロールバックの承認待ち
        run: echo "本番ロールバックが承認されました"

  rollback:
    needs: [validate, confirm-production]
    # production の場合は承認後、staging の場合はバリデーション後に実行
    if: |
      always() &&
      needs.validate.result == 'success' &&
      (needs.confirm-production.result == 'success' || needs.confirm-production.result == 'skipped')
    runs-on: ubuntu-latest
    environment:
      name: ${{ inputs.environment }}
    steps:
      - uses: actions/checkout@v4

      - name: AWS 認証 (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/deploy-${{ inputs.environment }}
          aws-region: ap-northeast-1

      - name: ロールバック実行
        run: |
          echo "ロールバック開始: ${{ inputs.environment }} → ${{ inputs.image-tag }}"

          # ECS タスク定義を更新
          TASK_DEF=$(aws ecs describe-task-definition \
            --task-definition app-${{ inputs.environment }} \
            --query 'taskDefinition' --output json)

          NEW_TASK_DEF=$(echo "$TASK_DEF" | jq \
            --arg IMAGE "ghcr.io/${{ github.repository }}:${{ inputs.image-tag }}" \
            '.containerDefinitions[0].image = $IMAGE |
             del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)')

          aws ecs register-task-definition --cli-input-json "$NEW_TASK_DEF"

          aws ecs update-service \
            --cluster ${{ inputs.environment }} \
            --service app \
            --force-new-deployment

      - name: ヘルスチェック
        run: |
          if [ "${{ inputs.environment }}" = "production" ]; then
            URL="https://example.com/health"
          else
            URL="https://staging.example.com/health"
          fi

          for i in $(seq 1 30); do
            status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$URL")
            if [ "$status" = "200" ]; then
              echo "ロールバック完了: ヘルスチェック成功"
              exit 0
            fi
            echo "待機中... ($i/30)"
            sleep 10
          done
          echo "::error::ロールバック後のヘルスチェックに失敗しました"
          exit 1

  notify:
    needs: rollback
    if: always()
    runs-on: ubuntu-latest
    steps:
      - name: Slack 通知
        uses: slackapi/slack-github-action@v2
        with:
          webhook: ${{ secrets.SLACK_WEBHOOK_URL }}
          webhook-type: incoming-webhook
          payload: |
            {
              "text": "${{ needs.rollback.result == 'success' && ':white_check_mark: ロールバック成功' || ':x: ロールバック失敗' }}\n環境: ${{ inputs.environment }}\nイメージ: ${{ inputs.image-tag }}\n理由: ${{ inputs.reason }}\n実行者: ${{ github.actor }}\n詳細: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
            }
```

### 設計ポイント

- `workflow_dispatch` の `inputs` で環境、イメージタグ、理由を指定
- `type: choice` でドロップダウン選択、`type: string` で自由入力
- 本番ロールバック時は Environment protection rules で承認を必須にする
- ロールバック後にヘルスチェックを実行して正常性を確認
- 結果を Slack に通知（成功・失敗の両方）
- `concurrency` で同じ環境への同時デプロイを防止
