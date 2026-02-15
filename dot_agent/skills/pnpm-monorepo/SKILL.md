---
name: pnpm-monorepo
description: pnpm ワークスペースによるモノレポ管理ガイド。ワークスペース設定、パッケージ構成パターン（apps/packages/shared）、パッケージ間依存管理（workspace:*）、共有パッケージ設計、TypeScript設定（tsconfig継承/パスエイリアス）、開発コマンド（turbo/pnpm run --filter）、ビルドとバージョン管理をカバー。モノレポのワークスペース設定、パッケージ追加、共有パッケージ設計時に使用。
---

# pnpm モノレポガイド

pnpm ワークスペースによるモノレポの構成・管理ガイド。

## ワークスペース設定

### pnpm-workspace.yaml

```yaml
packages:
  - 'apps/*'
  - 'packages/*'
```

### .npmrc

```ini
# ファントム依存の防止（推奨）
shamefully-hoist=false
strict-peer-dependencies=true

# モノレポ用設定
link-workspace-packages=true
prefer-workspace-packages=true
```

### ルート package.json

```json
{
  "private": true,
  "scripts": {
    "dev": "turbo dev",
    "build": "turbo build",
    "test": "turbo test",
    "lint": "turbo lint",
    "type-check": "turbo type-check"
  },
  "devDependencies": {
    "turbo": "latest"
  }
}
```

## パッケージ構成パターン

### 基本構造

```
project-root/
├── apps/                 # アプリケーション
│   ├── web/              # フロントエンドアプリ
│   ├── api/              # バックエンド API
│   └── admin/            # 管理画面
├── packages/             # 共有パッケージ
│   ├── ui/               # 共有 UI コンポーネント
│   ├── config/           # 共有設定（ESLint, TypeScript等）
│   ├── schemas/          # 共有 Zod スキーマ
│   └── utils/            # 共有ユーティリティ
├── pnpm-workspace.yaml
├── turbo.json
└── package.json
```

### apps と packages の責務

```
apps/:
  - 独立してデプロイ可能なアプリケーション
  - エントリーポイント（サーバー起動、ルーティング）
  - apps 同士は直接依存しない

packages/:
  - 再利用可能な共有コード
  - 明確なインターフェース（exports）
  - packages 間の依存は許可（循環依存は禁止）
```

## パッケージ間の依存管理

### workspace:* プロトコル

```json
{
  "name": "@myapp/web",
  "dependencies": {
    "@myapp/ui": "workspace:*",
    "@myapp/schemas": "workspace:*"
  }
}
```

### 依存の方向

```
apps → packages: OK（アプリが共有パッケージを使用）
packages → packages: OK（ただし循環禁止）
apps → apps: NG（アプリ間の直接依存は禁止）
packages → apps: NG（共有パッケージがアプリに依存しない）
```

### 依存の追加

```bash
# 特定パッケージに依存追加
pnpm add zod --filter @myapp/schemas

# ワークスペース内パッケージを依存追加
pnpm add @myapp/schemas --filter @myapp/web --workspace

# ルートに devDependency 追加
pnpm add -D turbo -w
```

## 共有パッケージ設計

### パッケージの package.json

```json
{
  "name": "@myapp/schemas",
  "version": "0.0.0",
  "private": true,
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "exports": {
    ".": "./src/index.ts",
    "./user": "./src/user.ts"
  }
}
```

### 設計原則

```
1. 明確な公開インターフェース（exports で定義）
2. 内部実装の隠蔽（公開しないモジュールは exports に含めない）
3. 最小限の依存（不要な依存を持ち込まない）
4. 型定義の同梱（types フィールド設定）
5. 循環依存の禁止
```

### よくある共有パッケージ

| パッケージ | 内容 |
|-----------|------|
| @myapp/schemas | Zod スキーマ、型定義 |
| @myapp/ui | 共有 UI コンポーネント |
| @myapp/config | ESLint, TypeScript, Prettier 設定 |
| @myapp/utils | 汎用ユーティリティ関数 |
| @myapp/db | DB スキーマ、マイグレーション |

詳細: [references/shared-packages.md](references/shared-packages.md)

## TypeScript 設定

### tsconfig の継承

```
packages/config/
  └── tsconfig/
      ├── base.json        # 共通設定
      ├── nextjs.json      # Next.js 用
      ├── node.json        # Node.js / Workers 用
      └── react.json       # React ライブラリ用
```

```json
// packages/config/tsconfig/base.json
{
  "compilerOptions": {
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "declaration": true,
    "declarationMap": true
  }
}

// apps/web/tsconfig.json
{
  "extends": "@myapp/config/tsconfig/nextjs.json",
  "include": ["src"],
  "exclude": ["node_modules"]
}
```

### パスエイリアス

```json
{
  "compilerOptions": {
    "paths": {
      "@/*": ["./src/*"]
    }
  }
}
```

## 開発コマンド

### Turborepo 設定

```json
// turbo.json
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**", ".next/**"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "test": {
      "dependsOn": ["^build"]
    },
    "lint": {},
    "type-check": {
      "dependsOn": ["^build"]
    }
  }
}
```

### よく使うコマンド

```bash
# 全パッケージで実行
pnpm turbo build
pnpm turbo test

# 特定パッケージのみ
pnpm turbo build --filter=@myapp/web
pnpm turbo dev --filter=@myapp/web

# 変更のあるパッケージのみ
pnpm turbo build --filter=...[HEAD~1]

# pnpm で直接
pnpm --filter @myapp/web dev
pnpm --filter @myapp/api add zod
```

## CI/CD でのモノレポ対応

```
原則:
  1. 変更のあるパッケージのみビルド・テスト
  2. キャッシュを最大限活用
  3. 依存関係の順序を考慮

Turborepo の Remote Cache:
  - CI で Turborepo のキャッシュを共有
  - ビルド時間の大幅な短縮

変更検出:
  - turbo --filter=...[base-branch] で affected のみ実行
  - GitHub Actions の paths フィルタと組み合わせ
```

## レビューチェックリスト

- [ ] pnpm-workspace.yaml に新しいパッケージが登録されている
- [ ] パッケージ間の依存方向が正しい（循環なし）
- [ ] 共有パッケージの exports が適切に設定されている
- [ ] workspace:* で内部パッケージを参照している
- [ ] tsconfig が共通設定を継承している
- [ ] turbo.json の依存関係が正しい
- [ ] パッケージの責務が明確

## リファレンス

- [references/workspace-config.md](references/workspace-config.md) - ワークスペース設定詳細
- [references/shared-packages.md](references/shared-packages.md) - 共有パッケージ設計パターン
