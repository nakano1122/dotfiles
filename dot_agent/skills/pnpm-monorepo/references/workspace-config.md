# pnpm モノレポ ワークスペース設定リファレンス

## 目次

- [pnpm-workspace.yaml の詳細設定](#pnpm-workspaceyaml-の詳細設定)
  - [基本構成](#基本構成)
  - [パターン指定](#パターン指定)
  - [除外パターン](#除外パターン)
  - [カタログ機能 (pnpm v9+)](#カタログ機能-pnpm-v9)
  - [推奨ディレクトリ構成](#推奨ディレクトリ構成)
- [.npmrc の設定オプション詳細](#npmrc-の設定オプション詳細)
  - [推奨設定](#推奨設定)
  - [環境別 .npmrc の使い分け](#環境別-npmrc-の使い分け)
- [ルート package.json 設計](#ルート-packagejson-設計)
  - [基本構成](#基本構成-1)
  - [scripts 設計のポイント](#scripts-設計のポイント)
  - [devDependencies の配置方針](#devdependencies-の配置方針)
- [turbo.json の詳細設定](#turbojson-の詳細設定)
  - [基本構成](#基本構成-2)
  - [tasks 設定の詳細](#tasks-設定の詳細)
  - [Turborepo Remote Cache 設定](#turborepo-remote-cache-設定)
- [.gitignore のモノレポ対応](#gitignore-のモノレポ対応)
  - [ルート .gitignore](#ルート-gitignore)
  - [パッケージ固有の .gitignore](#パッケージ固有の-gitignore)
- [EditorConfig / Prettier の共有設定](#editorconfig-prettier-の共有設定)
  - [.editorconfig (ルート)](#editorconfig-ルート)
  - [Prettier 設定共有パターン](#prettier-設定共有パターン)
  - [.prettierignore (ルート)](#prettierignore-ルート)
- [pnpm のバージョン管理](#pnpm-のバージョン管理)
  - [corepack による管理](#corepack-による管理)
  - [package.json の packageManager フィールド](#packagejson-の-packagemanager-フィールド)
  - [CI 環境での設定例](#ci-環境での設定例)
  - [engines フィールドによる制限](#engines-フィールドによる制限)
- [ワークスペースのトラブルシューティング](#ワークスペースのトラブルシューティング)
  - [Phantom Dependencies (幽霊依存)](#phantom-dependencies-幽霊依存)
  - [Version Conflicts (バージョン衝突)](#version-conflicts-バージョン衝突)
  - [Symlink Issues (シンボリックリンク問題)](#symlink-issues-シンボリックリンク問題)
  - [その他のよくある問題](#その他のよくある問題)

## pnpm-workspace.yaml の詳細設定

### 基本構成

```yaml
packages:
  - "apps/*"
  - "packages/*"
```

### パターン指定

```yaml
packages:
  # 直下のディレクトリのみ
  - "apps/*"
  # ネストされたディレクトリも含む
  - "packages/**"
  # 特定のディレクトリを明示的に指定
  - "tools/cli"
  # 複数階層のグループ化
  - "libs/frontend/*"
  - "libs/backend/*"
```

### 除外パターン

```yaml
packages:
  - "packages/*"
  # テスト用 fixture を除外
  - "!packages/*/test/fixtures"
  # 特定パッケージを除外
  - "!packages/deprecated-*"
  # ビルド出力を除外
  - "!**/dist"
  - "!**/node_modules"
```

### カタログ機能 (pnpm v9+)

ワークスペース全体で依存関係のバージョンを一元管理する。

```yaml
packages:
  - "apps/*"
  - "packages/*"

catalog:
  react: ^19.0.0
  react-dom: ^19.0.0
  typescript: ^5.7.0
  zod: ^3.24.0

catalogs:
  frontend:
    next: ^15.0.0
    tailwindcss: ^4.0.0
  backend:
    hono: ^4.0.0
    drizzle-orm: ^0.38.0
```

各パッケージの package.json でカタログを参照する。

```json
{
  "dependencies": {
    "react": "catalog:",
    "next": "catalog:frontend"
  }
}
```

### 推奨ディレクトリ構成

```
project-root/
├── pnpm-workspace.yaml
├── package.json
├── pnpm-lock.yaml
├── turbo.json
├── .npmrc
├── .gitignore
├── apps/
│   ├── web/           # Next.js フロントエンド
│   ├── api/           # Hono バックエンド
│   └── admin/         # 管理画面
├── packages/
│   ├── ui/            # 共有 UI コンポーネント
│   ├── schemas/       # Zod スキーマ・型定義
│   ├── config/        # 共有設定
│   ├── db/            # DB スキーマ・マイグレーション
│   └── utils/         # 共有ユーティリティ
└── tooling/
    ├── eslint/        # ESLint 設定
    ├── prettier/      # Prettier 設定
    └── typescript/    # TypeScript 設定
```

---

## .npmrc の設定オプション詳細

### 推奨設定

```ini
# ホイスティング制御
# true: すべての依存関係をルートにホイスト (デフォルト)
# false: 各パッケージの node_modules に厳密に配置
hoist=true

# 特定パッケージのホイスティングパターン
# ホイストするパッケージを制限
hoist-pattern[]=*
# 特定パッケージをホイスト対象外にする
# hoist-pattern[]=!@types/react

# ワークスペースパッケージのリンク方式
# true: workspace: プロトコルのパッケージをシンボリックリンク
# false: レジストリから取得
# deep: ワークスペースパッケージが依存する他のワークスペースパッケージもリンク
link-workspace-packages=true

# shamefully-hoist: node_modules のフラット化
# true にすると npm/yarn と同様のフラット構造になる
# 互換性のために必要な場合のみ有効化
shamefully-hoist=false

# strict-peer-dependencies: peer dependency の厳密チェック
# true にすると peer dependency の不一致でインストール失敗
strict-peer-dependencies=false

# auto-install-peers: peer dependency の自動インストール
auto-install-peers=true

# resolve-peers-from-workspace-root: ワークスペースルートから peer を解決
resolve-peers-from-workspace-root=true

# レジストリ設定
registry=https://registry.npmjs.org/

# プライベートレジストリ (スコープ単位)
# @myorg:registry=https://npm.pkg.github.com
# //npm.pkg.github.com/:_authToken=${NODE_AUTH_TOKEN}

# Node.js のバージョン指定 (corepack と併用)
use-node-version=22.12.0

# lockfile の凍結 (CI 環境向け)
# CI=true の場合自動で frozen-lockfile になる
# frozen-lockfile=true
```

### 環境別 .npmrc の使い分け

```ini
# .npmrc (プロジェクトルート - リポジトリにコミット)
link-workspace-packages=true
auto-install-peers=true
resolve-peers-from-workspace-root=true
strict-peer-dependencies=false

# ~/.npmrc (ユーザーグローバル - コミットしない)
# プライベートレジストリのトークン等
# //npm.pkg.github.com/:_authToken=ghp_xxxx
```

---

## ルート package.json 設計

### 基本構成

```json
{
  "name": "@myproject/root",
  "private": true,
  "packageManager": "pnpm@9.15.0",
  "engines": {
    "node": ">=22.0.0",
    "pnpm": ">=9.0.0"
  },
  "scripts": {
    "build": "turbo run build",
    "dev": "turbo run dev",
    "lint": "turbo run lint",
    "lint:fix": "turbo run lint:fix",
    "typecheck": "turbo run typecheck",
    "test": "turbo run test",
    "test:ci": "turbo run test:ci",
    "format": "prettier --write .",
    "format:check": "prettier --check .",
    "clean": "turbo run clean && rm -rf node_modules",
    "db:generate": "pnpm --filter @myproject/db generate",
    "db:migrate": "pnpm --filter @myproject/db migrate",
    "db:seed": "pnpm --filter @myproject/db seed",
    "db:studio": "pnpm --filter @myproject/db studio",
    "preinstall": "npx only-allow pnpm"
  },
  "devDependencies": {
    "@biomejs/biome": "^1.9.0",
    "prettier": "^3.4.0",
    "turbo": "^2.3.0",
    "typescript": "^5.7.0"
  }
}
```

### scripts 設計のポイント

```json
{
  "scripts": {
    // Turborepo 経由のタスク (キャッシュ・並列実行の恩恵)
    "build": "turbo run build",
    "dev": "turbo run dev",
    "lint": "turbo run lint",
    "typecheck": "turbo run typecheck",
    "test": "turbo run test",

    // 特定パッケージのタスク実行
    "dev:web": "turbo run dev --filter=@myproject/web",
    "dev:api": "turbo run dev --filter=@myproject/api",

    // フィルタリング例
    "build:apps": "turbo run build --filter='./apps/*'",
    "build:packages": "turbo run build --filter='./packages/*'",
    "test:changed": "turbo run test --filter='...[HEAD~1]'",

    // pnpm 直接実行 (Turborepo 不要なタスク)
    "format": "prettier --write .",
    "format:check": "prettier --check .",
    "clean": "turbo run clean && rm -rf node_modules .turbo",

    // パッケージマネージャー制限
    "preinstall": "npx only-allow pnpm"
  }
}
```

### devDependencies の配置方針

| 種別 | 配置場所 | 例 |
|---|---|---|
| ビルドツール (全体共通) | ルート | turbo, typescript |
| フォーマッター | ルート | prettier, @biomejs/biome |
| Git フック | ルート | husky, lint-staged |
| テストフレームワーク | 各パッケージ or ルート | vitest |
| 型定義 (共通) | ルート | @types/node |
| Lint 設定 | tooling パッケージ | eslint, @eslint/js |
| フレームワーク固有 | 各パッケージ | next, hono |

---

## turbo.json の詳細設定

### 基本構成

```json
{
  "$schema": "https://turbo.build/schema.json",
  "globalDependencies": [
    "**/.env",
    "**/.env.*",
    ".npmrc",
    "tsconfig.json"
  ],
  "globalEnv": [
    "NODE_ENV",
    "CI"
  ],
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "inputs": [
        "src/**",
        "tsconfig.json",
        "package.json"
      ],
      "outputs": [
        "dist/**",
        ".next/**"
      ]
    },
    "dev": {
      "dependsOn": ["^build"],
      "cache": false,
      "persistent": true
    },
    "lint": {
      "dependsOn": ["^build"],
      "inputs": [
        "src/**",
        "eslint.config.*",
        "biome.json",
        "tsconfig.json"
      ],
      "outputs": []
    },
    "lint:fix": {
      "dependsOn": ["^build"],
      "cache": false
    },
    "typecheck": {
      "dependsOn": ["^build"],
      "inputs": [
        "src/**",
        "tsconfig.json",
        "tsconfig.*.json"
      ],
      "outputs": []
    },
    "test": {
      "dependsOn": ["^build"],
      "inputs": [
        "src/**",
        "tests/**",
        "vitest.config.*"
      ],
      "outputs": []
    },
    "test:ci": {
      "dependsOn": ["^build"],
      "inputs": [
        "src/**",
        "tests/**",
        "vitest.config.*"
      ],
      "outputs": [
        "coverage/**"
      ]
    },
    "clean": {
      "cache": false
    }
  }
}
```

### tasks 設定の詳細

#### dependsOn

```json
{
  "tasks": {
    "build": {
      // ^ は依存パッケージの同名タスクを先に実行する意味
      "dependsOn": ["^build"]
    },
    "deploy": {
      // 同一パッケージ内の build を先に実行
      "dependsOn": ["build"],
    },
    "test:e2e": {
      // 同一パッケージの build + 依存パッケージの build
      "dependsOn": ["build", "^build"]
    }
  }
}
```

#### inputs と outputs

```json
{
  "tasks": {
    "build": {
      // inputs: キャッシュキーに含めるファイル
      // 指定しない場合は .gitignore 以外の全ファイル
      "inputs": [
        "src/**/*.ts",
        "src/**/*.tsx",
        "tsconfig.json",
        "package.json",
        // 環境変数ファイル
        ".env",
        ".env.production"
      ],
      // outputs: キャッシュ対象のビルド出力
      "outputs": [
        "dist/**",
        ".next/**",
        "!.next/cache/**"
      ]
    }
  }
}
```

#### パッケージ単位のタスク上書き

turbo.json でパッケージ固有のタスク設定を上書きできる。

```json
{
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**"]
    },
    // 特定パッケージの build を上書き
    "@myproject/web#build": {
      "dependsOn": ["^build"],
      "outputs": [".next/**", "!.next/cache/**"],
      "env": ["NEXT_PUBLIC_API_URL"]
    },
    // 特定パッケージの dev を上書き
    "@myproject/api#dev": {
      "dependsOn": ["^build"],
      "cache": false,
      "persistent": true,
      "env": ["DATABASE_URL", "JWT_SECRET"]
    }
  }
}
```

#### env (環境変数)

```json
{
  // 全タスク共通の環境変数 (変更時に全キャッシュ無効化)
  "globalEnv": [
    "NODE_ENV",
    "CI",
    "TURBO_TOKEN",
    "TURBO_TEAM"
  ],
  "tasks": {
    "build": {
      // タスク固有の環境変数 (変更時にこのタスクのキャッシュ無効化)
      "env": [
        "API_URL",
        "NEXT_PUBLIC_*"
      ]
    }
  }
}
```

### Turborepo Remote Cache 設定

#### Vercel Remote Cache

```bash
# ログイン
npx turbo login

# リモートキャッシュの有効化
npx turbo link
```

turbo.json への設定追加は不要。環境変数で制御する。

```bash
# CI 環境変数
TURBO_TOKEN=your-turbo-token
TURBO_TEAM=your-team-name

# オプション: API エンドポイント (セルフホスト時)
# TURBO_API=https://your-cache-server.example.com
```

#### セルフホスト Remote Cache

```json
// turbo.json
{
  "remoteCache": {
    "enabled": true,
    "signature": true
  }
}
```

```bash
# 環境変数
TURBO_API=https://your-cache-server.example.com
TURBO_TOKEN=your-token
TURBO_TEAM=your-team
```

#### CI での設定例 (GitHub Actions)

```yaml
- name: Build
  run: pnpm build
  env:
    TURBO_TOKEN: ${{ secrets.TURBO_TOKEN }}
    TURBO_TEAM: ${{ vars.TURBO_TEAM }}
```

---

## .gitignore のモノレポ対応

### ルート .gitignore

```gitignore
# 依存関係
node_modules/

# ビルド出力
dist/
build/
.next/
.nuxt/
out/

# Turborepo
.turbo/

# 環境変数
.env
.env.local
.env.*.local

# エディタ
.vscode/*
!.vscode/settings.json
!.vscode/extensions.json
.idea/

# OS
.DS_Store
Thumbs.db

# テスト
coverage/

# DB
*.sqlite
*.sqlite-journal

# ログ
*.log

# 型生成
*.generated.ts
```

### パッケージ固有の .gitignore

各パッケージの .gitignore はそのパッケージ固有の除外のみ記述する。

```gitignore
# packages/db/.gitignore
# マイグレーション生成物 (Drizzle)
# drizzle/ はコミットするため除外しない
*.sqlite
*.sqlite-journal

# apps/web/.gitignore
.next/
.vercel/
```

---

## EditorConfig / Prettier の共有設定

### .editorconfig (ルート)

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
indent_style = space
indent_size = 2
insert_final_newline = true
trim_trailing_whitespace = true

[*.md]
trim_trailing_whitespace = false

[Makefile]
indent_style = tab
```

### Prettier 設定共有パターン

#### 方法 1: ルートに直接配置

```json
// .prettierrc (ルート)
{
  "semi": true,
  "singleQuote": false,
  "tabWidth": 2,
  "trailingComma": "all",
  "printWidth": 100,
  "plugins": ["prettier-plugin-tailwindcss"],
  "overrides": [
    {
      "files": "*.json",
      "options": {
        "tabWidth": 2
      }
    }
  ]
}
```

#### 方法 2: 共有設定パッケージ

```json
// tooling/prettier/package.json
{
  "name": "@myproject/prettier-config",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "exports": {
    ".": "./index.mjs"
  }
}
```

```js
// tooling/prettier/index.mjs
/** @type {import("prettier").Config} */
const config = {
  semi: true,
  singleQuote: false,
  tabWidth: 2,
  trailingComma: "all",
  printWidth: 100,
  plugins: ["prettier-plugin-tailwindcss"],
};

export default config;
```

```json
// apps/web/package.json
{
  "prettier": "@myproject/prettier-config"
}
```

### .prettierignore (ルート)

```
node_modules/
dist/
build/
.next/
.turbo/
coverage/
pnpm-lock.yaml
```

---

## pnpm のバージョン管理

### corepack による管理

```bash
# corepack の有効化
corepack enable

# pnpm バージョンの固定
corepack use pnpm@9.15.0
```

### package.json の packageManager フィールド

```json
{
  "packageManager": "pnpm@9.15.0"
}
```

このフィールドにより以下が保証される。

- corepack が自動的に指定バージョンの pnpm を使用する
- 異なるバージョンの pnpm を使おうとした場合に警告が出る
- CI 環境で正確なバージョンが再現される

### CI 環境での設定例

```yaml
# GitHub Actions
- name: Enable Corepack
  run: corepack enable

- name: Install dependencies
  run: pnpm install --frozen-lockfile
```

### engines フィールドによる制限

```json
{
  "engines": {
    "node": ">=22.0.0",
    "pnpm": ">=9.0.0"
  }
}
```

.npmrc で engines の厳密チェックを有効化する。

```ini
engine-strict=true
```

---

## ワークスペースのトラブルシューティング

### Phantom Dependencies (幽霊依存)

#### 問題

ホイスティングにより、package.json に明示的に記載していないパッケージが `import` できてしまう。本番環境やクリーンインストール時に壊れる原因になる。

#### 対策

```ini
# .npmrc
# ホイスティングを無効化 (厳密モード)
hoist=false

# または shamefully-hoist を無効に保つ (デフォルト)
shamefully-hoist=false

# 特定パッケージのみホイスト
hoist-pattern[]=eslint-*
hoist-pattern[]=prettier
```

pnpm のデフォルトの strict な node_modules 構造が最良の防御策となる。

#### 検出

```bash
# 未宣言の依存関係を検出
pnpm ls --depth 0  # 各パッケージの直接依存のみ表示
```

### Version Conflicts (バージョン衝突)

#### 問題

同じパッケージの異なるバージョンがワークスペース内で使われ、型の不一致やランタイムエラーが発生する。

#### 対策

```json
// ルート package.json の pnpm.overrides で統一
{
  "pnpm": {
    "overrides": {
      "react": "^19.0.0",
      "react-dom": "^19.0.0",
      "@types/react": "^19.0.0"
    }
  }
}
```

```yaml
# pnpm-workspace.yaml の catalog で統一 (推奨)
catalog:
  react: ^19.0.0
  react-dom: ^19.0.0
```

#### 検出

```bash
# 重複パッケージの確認
pnpm ls react --depth 0 --recursive

# なぜそのバージョンがインストールされたか確認
pnpm why react
pnpm why react --recursive
```

### Symlink Issues (シンボリックリンク問題)

#### 問題

ワークスペースパッケージ間のシンボリックリンクが正しく機能しない。ファイル監視が動かない。Docker コンテキストでリンクが壊れる。

#### 対策: リンクの確認

```bash
# ワークスペースのリンク状態を確認
pnpm ls --recursive --depth 0

# 特定パッケージのリンク確認
ls -la node_modules/@myproject/
```

#### 対策: Docker でのモノレポ

```dockerfile
# マルチステージビルドで必要なパッケージのみコピー
FROM node:22-alpine AS base
RUN corepack enable

FROM base AS deps
WORKDIR /app
COPY pnpm-lock.yaml pnpm-workspace.yaml package.json .npmrc ./
COPY apps/api/package.json ./apps/api/
COPY packages/schemas/package.json ./packages/schemas/
COPY packages/db/package.json ./packages/db/
RUN pnpm install --frozen-lockfile

FROM base AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN pnpm --filter @myproject/api build

FROM base AS runner
WORKDIR /app
COPY --from=build /app/apps/api/dist ./dist
COPY --from=build /app/node_modules ./node_modules
CMD ["node", "dist/index.js"]
```

#### 対策: deploy 用の inject

`pnpm deploy` コマンドで依存関係を解決済みの状態で出力できる。

```bash
# 特定パッケージとその依存をフラットに出力
pnpm --filter @myproject/api deploy ./deploy/api
```

### その他のよくある問題

#### `pnpm install` が遅い

```bash
# store の場所を確認
pnpm store path

# store をクリーンアップ
pnpm store prune

# 並列インストール数を増やす
# .npmrc
# network-concurrency=16
```

#### lockfile の競合

```bash
# lockfile を再生成
rm pnpm-lock.yaml
pnpm install

# 特定パッケージの lockfile エントリを更新
pnpm update react --recursive
```

#### TypeScript がワークスペースパッケージの型を解決できない

```json
// tsconfig.json (ルート)
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@myproject/*": ["packages/*/src"]
    }
  }
}
```

または各パッケージの package.json で exports を正しく設定する。

```json
{
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "import": "./dist/index.js"
    }
  }
}
```

開発時にビルドなしで型解決する場合は `publishConfig` を活用する。

```json
{
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "exports": {
    ".": {
      "types": "./src/index.ts",
      "default": "./src/index.ts"
    }
  },
  "publishConfig": {
    "main": "./dist/index.js",
    "types": "./dist/index.d.ts",
    "exports": {
      ".": {
        "types": "./dist/index.d.ts",
        "import": "./dist/index.js"
      }
    }
  }
}
```
