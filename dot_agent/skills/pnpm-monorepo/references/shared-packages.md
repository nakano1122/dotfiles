# pnpm モノレポ 共有パッケージ設計リファレンス

## 目次

- [schemas パッケージ (Zod スキーマ共有)](#schemas-パッケージ-zod-スキーマ共有)
  - [目的](#目的)
  - [パッケージ構成](#パッケージ構成)
  - [package.json](#packagejson)
  - [スキーマ定義例](#スキーマ定義例)
  - [フロントエンドでの利用](#フロントエンドでの利用)
  - [バックエンドでの利用](#バックエンドでの利用)
- [config パッケージ (共有設定)](#config-パッケージ-共有設定)
  - [目的](#目的-1)
  - [ディレクトリ構成](#ディレクトリ構成)
  - [TypeScript 設定共有](#typescript-設定共有)
  - [ESLint 設定共有 (Flat Config)](#eslint-設定共有-flat-config)
- [ui パッケージ (共有コンポーネントライブラリ)](#ui-パッケージ-共有コンポーネントライブラリ)
  - [目的](#目的-2)
  - [パッケージ構成](#パッケージ構成-1)
  - [package.json](#packagejson-1)
  - [Tailwind CSS 設定共有 (v4)](#tailwind-css-設定共有-v4)
  - [コンポーネント例](#コンポーネント例)
  - [アプリケーションからの利用](#アプリケーションからの利用)
- [utils パッケージ (共有ユーティリティ)](#utils-パッケージ-共有ユーティリティ)
  - [目的](#目的-3)
  - [パッケージ構成](#パッケージ構成-2)
  - [package.json](#packagejson-2)
  - [ユーティリティ例](#ユーティリティ例)
- [db パッケージ (DB スキーマ、マイグレーション、シード)](#db-パッケージ-db-スキーママイグレーションシード)
  - [目的](#目的-4)
  - [パッケージ構成](#パッケージ構成-3)
  - [package.json](#packagejson-3)
  - [スキーマ定義例](#スキーマ定義例-1)
  - [アプリケーションからの利用](#アプリケーションからの利用-1)
- [パッケージの exports 設計パターン](#パッケージの-exports-設計パターン)
  - [Conditional Exports](#conditional-exports)
  - [開発時 (ソースコード直接参照)](#開発時-ソースコード直接参照)
  - [Subpath Exports](#subpath-exports)
  - [exports と typesVersions の併用](#exports-と-typesversions-の併用)
- [パッケージの依存関係管理](#パッケージの依存関係管理)
  - [依存関係の種別と配置](#依存関係の種別と配置)
  - [peerDependencies の使い方](#peerdependencies-の使い方)
  - [内部パッケージの依存関係](#内部パッケージの依存関係)
  - [依存関係の循環回避](#依存関係の循環回避)
- [内部パッケージ vs 公開パッケージの設計差異](#内部パッケージ-vs-公開パッケージの設計差異)
  - [内部パッケージ (private: true)](#内部パッケージ-private-true)
  - [公開パッケージ (npm 公開)](#公開パッケージ-npm-公開)
  - [比較表](#比較表)
- [パッケージ追加手順](#パッケージ追加手順)
  - [新しい共有パッケージの作成ステップ](#新しい共有パッケージの作成ステップ)
  - [チェックリスト](#チェックリスト)

## schemas パッケージ (Zod スキーマ共有)

### 目的

フロントエンドとバックエンド間で型安全なデータ検証スキーマを共有する。API リクエスト/レスポンスの型を単一ソースから生成し、型の不一致を防ぐ。

### パッケージ構成

```
packages/schemas/
├── package.json
├── tsconfig.json
├── src/
│   ├── index.ts           # 公開エントリポイント
│   ├── user.ts            # ユーザー関連スキーマ
│   ├── auth.ts            # 認証関連スキーマ
│   ├── common.ts          # 共通スキーマ (ページネーション等)
│   └── api/
│       ├── index.ts
│       ├── request.ts     # API リクエスト型
│       └── response.ts    # API レスポンス型
```

### package.json

```json
{
  "name": "@myproject/schemas",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "exports": {
    ".": {
      "types": "./src/index.ts",
      "default": "./src/index.ts"
    },
    "./user": {
      "types": "./src/user.ts",
      "default": "./src/user.ts"
    },
    "./auth": {
      "types": "./src/auth.ts",
      "default": "./src/auth.ts"
    },
    "./api": {
      "types": "./src/api/index.ts",
      "default": "./src/api/index.ts"
    }
  },
  "dependencies": {
    "zod": "catalog:"
  },
  "devDependencies": {
    "typescript": "catalog:"
  }
}
```

### スキーマ定義例

```typescript
// src/user.ts
import { z } from "zod";

// 基本スキーマ
export const userSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  name: z.string().min(1).max(100),
  role: z.enum(["admin", "user", "viewer"]),
  createdAt: z.coerce.date(),
  updatedAt: z.coerce.date(),
});

// 型の導出
export type User = z.infer<typeof userSchema>;

// 作成用スキーマ (id, timestamps を除外)
export const createUserSchema = userSchema.omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});
export type CreateUser = z.infer<typeof createUserSchema>;

// 更新用スキーマ (全フィールドをオプショナルに)
export const updateUserSchema = createUserSchema.partial();
export type UpdateUser = z.infer<typeof updateUserSchema>;

// リスト取得パラメータ
export const listUsersParamsSchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(20),
  role: z.enum(["admin", "user", "viewer"]).optional(),
  search: z.string().optional(),
});
export type ListUsersParams = z.infer<typeof listUsersParamsSchema>;
```

```typescript
// src/common.ts
import { z } from "zod";

export const paginatedResponseSchema = <T extends z.ZodTypeAny>(itemSchema: T) =>
  z.object({
    items: z.array(itemSchema),
    total: z.number().int().nonnegative(),
    page: z.number().int().positive(),
    limit: z.number().int().positive(),
    hasNext: z.boolean(),
  });

export type PaginatedResponse<T> = {
  items: T[];
  total: number;
  page: number;
  limit: number;
  hasNext: boolean;
};

export const idParamSchema = z.object({
  id: z.string().uuid(),
});
export type IdParam = z.infer<typeof idParamSchema>;

export const apiErrorSchema = z.object({
  code: z.string(),
  message: z.string(),
  details: z.record(z.unknown()).optional(),
});
export type ApiError = z.infer<typeof apiErrorSchema>;
```

### フロントエンドでの利用

```typescript
// apps/web/src/lib/api.ts
import { createUserSchema, type User, type CreateUser } from "@myproject/schemas/user";

export async function createUser(data: CreateUser): Promise<User> {
  // フォーム送信前にクライアント側でバリデーション
  const validated = createUserSchema.parse(data);
  const response = await fetch("/api/users", {
    method: "POST",
    body: JSON.stringify(validated),
  });
  return response.json();
}
```

### バックエンドでの利用

```typescript
// apps/api/src/routes/users.ts
import { Hono } from "hono";
import { zValidator } from "@hono/zod-validator";
import { createUserSchema, listUsersParamsSchema } from "@myproject/schemas/user";

const app = new Hono()
  .post("/users", zValidator("json", createUserSchema), async (c) => {
    const data = c.req.valid("json"); // 型安全
    // ...
  })
  .get("/users", zValidator("query", listUsersParamsSchema), async (c) => {
    const params = c.req.valid("query"); // 型安全
    // ...
  });
```

---

## config パッケージ (共有設定)

### 目的

TypeScript、ESLint、Prettier などのツール設定をワークスペース全体で統一する。設定の重複を排除し、一箇所の変更を全パッケージに反映させる。

### ディレクトリ構成

```
tooling/
├── typescript/
│   ├── package.json
│   ├── base.json
│   ├── nextjs.json
│   ├── library.json
│   └── node.json
├── eslint/
│   ├── package.json
│   ├── base.js
│   ├── nextjs.js
│   └── node.js
└── prettier/
    ├── package.json
    └── index.mjs
```

### TypeScript 設定共有

```json
// tooling/typescript/package.json
{
  "name": "@myproject/tsconfig",
  "version": "0.1.0",
  "private": true
}
```

```json
// tooling/typescript/base.json
{
  "$schema": "https://json.schemastore.org/tsconfig",
  "compilerOptions": {
    "strict": true,
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "noUncheckedIndexedAccess": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "exactOptionalPropertyTypes": false
  },
  "exclude": ["node_modules", "dist"]
}
```

```json
// tooling/typescript/library.json
{
  "$schema": "https://json.schemastore.org/tsconfig",
  "extends": "./base.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src",
    "declaration": true,
    "declarationMap": true
  }
}
```

```json
// tooling/typescript/nextjs.json
{
  "$schema": "https://json.schemastore.org/tsconfig",
  "extends": "./base.json",
  "compilerOptions": {
    "lib": ["dom", "dom.iterable", "ES2022"],
    "jsx": "preserve",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "noEmit": true,
    "plugins": [{ "name": "next" }]
  }
}
```

```json
// tooling/typescript/node.json
{
  "$schema": "https://json.schemastore.org/tsconfig",
  "extends": "./base.json",
  "compilerOptions": {
    "lib": ["ES2022"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "outDir": "./dist",
    "rootDir": "./src"
  }
}
```

各パッケージからの利用。

```json
// apps/web/tsconfig.json
{
  "extends": "@myproject/tsconfig/nextjs.json",
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src", "next-env.d.ts", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

```json
// packages/schemas/tsconfig.json
{
  "extends": "@myproject/tsconfig/library.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src"]
}
```

### ESLint 設定共有 (Flat Config)

```json
// tooling/eslint/package.json
{
  "name": "@myproject/eslint-config",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "exports": {
    "./base": "./base.js",
    "./nextjs": "./nextjs.js",
    "./node": "./node.js"
  },
  "dependencies": {
    "@eslint/js": "^9.0.0",
    "eslint-config-prettier": "^10.0.0",
    "typescript-eslint": "^8.0.0"
  },
  "peerDependencies": {
    "eslint": "^9.0.0"
  }
}
```

```javascript
// tooling/eslint/base.js
import js from "@eslint/js";
import tseslint from "typescript-eslint";
import prettierConfig from "eslint-config-prettier";

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.recommended,
  prettierConfig,
  {
    rules: {
      "@typescript-eslint/no-unused-vars": [
        "error",
        { argsIgnorePattern: "^_", varsIgnorePattern: "^_" },
      ],
      "@typescript-eslint/consistent-type-imports": [
        "error",
        { prefer: "type-imports" },
      ],
    },
  },
  {
    ignores: ["dist/", "node_modules/", ".turbo/", "coverage/"],
  },
);
```

```javascript
// apps/web/eslint.config.js
import baseConfig from "@myproject/eslint-config/base";
import nextConfig from "@myproject/eslint-config/nextjs";

export default [...baseConfig, ...nextConfig];
```

---

## ui パッケージ (共有コンポーネントライブラリ)

### 目的

複数のフロントエンドアプリケーションで共有する UI コンポーネントを提供する。shadcn/ui ベースのコンポーネントや独自コンポーネントを管理する。

### パッケージ構成

```
packages/ui/
├── package.json
├── tsconfig.json
├── src/
│   ├── index.ts              # 全コンポーネントの re-export
│   ├── components/
│   │   ├── button.tsx
│   │   ├── input.tsx
│   │   ├── dialog.tsx
│   │   ├── card.tsx
│   │   └── data-table.tsx
│   ├── hooks/
│   │   ├── index.ts
│   │   └── use-media-query.ts
│   └── lib/
│       ├── utils.ts          # cn() 等のユーティリティ
│       └── types.ts
```

### package.json

```json
{
  "name": "@myproject/ui",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "exports": {
    ".": {
      "types": "./src/index.ts",
      "default": "./src/index.ts"
    },
    "./button": {
      "types": "./src/components/button.tsx",
      "default": "./src/components/button.tsx"
    },
    "./dialog": {
      "types": "./src/components/dialog.tsx",
      "default": "./src/components/dialog.tsx"
    },
    "./hooks": {
      "types": "./src/hooks/index.ts",
      "default": "./src/hooks/index.ts"
    },
    "./lib/utils": {
      "types": "./src/lib/utils.ts",
      "default": "./src/lib/utils.ts"
    }
  },
  "dependencies": {
    "@radix-ui/react-dialog": "^1.1.0",
    "@radix-ui/react-slot": "^1.1.0",
    "class-variance-authority": "^0.7.0",
    "clsx": "^2.1.0",
    "tailwind-merge": "^2.6.0"
  },
  "peerDependencies": {
    "react": "^19.0.0",
    "react-dom": "^19.0.0"
  },
  "devDependencies": {
    "@types/react": "catalog:",
    "@types/react-dom": "catalog:",
    "react": "catalog:",
    "react-dom": "catalog:",
    "typescript": "catalog:"
  }
}
```

### Tailwind CSS 設定共有 (v4)

Tailwind CSS v4 では CSS ファイルベースの設定になり、共有方法が変わる。

```css
/* packages/ui/src/styles/theme.css */
@theme {
  /* カラーパレット */
  --color-primary: oklch(0.55 0.2 250);
  --color-primary-foreground: oklch(0.98 0 0);
  --color-secondary: oklch(0.75 0.1 200);
  --color-secondary-foreground: oklch(0.2 0 0);
  --color-destructive: oklch(0.55 0.2 25);
  --color-destructive-foreground: oklch(0.98 0 0);
  --color-background: oklch(0.99 0 0);
  --color-foreground: oklch(0.15 0 0);
  --color-muted: oklch(0.95 0.01 250);
  --color-muted-foreground: oklch(0.5 0.01 250);
  --color-border: oklch(0.9 0.01 250);

  /* スペーシング */
  --spacing-xs: 0.25rem;
  --spacing-sm: 0.5rem;
  --spacing-md: 1rem;
  --spacing-lg: 1.5rem;
  --spacing-xl: 2rem;

  /* Border Radius */
  --radius-sm: 0.25rem;
  --radius-md: 0.5rem;
  --radius-lg: 0.75rem;
  --radius-full: 9999px;

  /* フォントファミリー */
  --font-sans: "Inter Variable", ui-sans-serif, system-ui, sans-serif;
  --font-mono: "JetBrains Mono Variable", ui-monospace, monospace;
}
```

アプリケーション側でインポートする。

```css
/* apps/web/src/app/globals.css */
@import "tailwindcss";
@import "@myproject/ui/src/styles/theme.css";
```

Tailwind CSS v4 でパッケージのコンテンツをスキャンする。

```css
/* apps/web/src/app/globals.css */
@import "tailwindcss";
@import "@myproject/ui/src/styles/theme.css";

/* ui パッケージのソースもスキャン対象に追加 */
@source "../../../../packages/ui/src/**/*.{ts,tsx}";
```

### コンポーネント例

```typescript
// packages/ui/src/lib/utils.ts
import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

```tsx
// packages/ui/src/components/button.tsx
import { Slot } from "@radix-ui/react-slot";
import { cva, type VariantProps } from "class-variance-authority";
import { forwardRef, type ButtonHTMLAttributes } from "react";
import { cn } from "../lib/utils";

const buttonVariants = cva(
  "inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 disabled:pointer-events-none disabled:opacity-50",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground hover:bg-primary/90",
        destructive: "bg-destructive text-destructive-foreground hover:bg-destructive/90",
        outline: "border border-border bg-background hover:bg-muted",
        secondary: "bg-secondary text-secondary-foreground hover:bg-secondary/80",
        ghost: "hover:bg-muted hover:text-foreground",
        link: "text-primary underline-offset-4 hover:underline",
      },
      size: {
        default: "h-10 px-4 py-2",
        sm: "h-9 rounded-md px-3",
        lg: "h-11 rounded-md px-8",
        icon: "h-10 w-10",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  },
);

export interface ButtonProps
  extends ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : "button";
    return (
      <Comp
        className={cn(buttonVariants({ variant, size, className }))}
        ref={ref}
        {...props}
      />
    );
  },
);
Button.displayName = "Button";

export { Button, buttonVariants };
```

### アプリケーションからの利用

```tsx
// apps/web/src/app/page.tsx
import { Button } from "@myproject/ui/button";

export default function Page() {
  return (
    <div>
      <Button variant="default">クリック</Button>
      <Button variant="destructive" size="sm">削除</Button>
    </div>
  );
}
```

---

## utils パッケージ (共有ユーティリティ)

### 目的

日付操作、文字列処理、バリデーションなど、フロントエンドとバックエンドの両方で使える純粋なユーティリティ関数を提供する。

### パッケージ構成

```
packages/utils/
├── package.json
├── tsconfig.json
├── vitest.config.ts
├── src/
│   ├── index.ts
│   ├── date.ts         # 日付ユーティリティ
│   ├── string.ts       # 文字列ユーティリティ
│   ├── number.ts       # 数値ユーティリティ
│   ├── array.ts        # 配列ユーティリティ
│   ├── result.ts       # Result 型
│   └── assertion.ts    # 型ガード・アサーション
└── tests/
    ├── date.test.ts
    ├── string.test.ts
    └── result.test.ts
```

### package.json

```json
{
  "name": "@myproject/utils",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "exports": {
    ".": {
      "types": "./src/index.ts",
      "default": "./src/index.ts"
    },
    "./date": {
      "types": "./src/date.ts",
      "default": "./src/date.ts"
    },
    "./string": {
      "types": "./src/string.ts",
      "default": "./src/string.ts"
    },
    "./result": {
      "types": "./src/result.ts",
      "default": "./src/result.ts"
    }
  },
  "devDependencies": {
    "typescript": "catalog:",
    "vitest": "catalog:"
  }
}
```

### ユーティリティ例

```typescript
// src/result.ts

/** 成功を表す型 */
export type Ok<T> = { ok: true; value: T };

/** 失敗を表す型 */
export type Err<E> = { ok: false; error: E };

/** Result 型 */
export type Result<T, E = Error> = Ok<T> | Err<E>;

export function ok<T>(value: T): Ok<T> {
  return { ok: true, value };
}

export function err<E>(error: E): Err<E> {
  return { ok: false, error };
}

/** 非同期関数をラップして Result を返す */
export async function tryCatch<T>(
  fn: () => Promise<T>,
): Promise<Result<T, Error>> {
  try {
    const value = await fn();
    return ok(value);
  } catch (e) {
    return err(e instanceof Error ? e : new Error(String(e)));
  }
}
```

```typescript
// src/date.ts

/** 日付を YYYY-MM-DD 形式にフォーマットする */
export function formatDate(date: Date): string {
  return date.toISOString().split("T")[0]!;
}

/** 日付を YYYY-MM-DD HH:mm 形式にフォーマットする */
export function formatDateTime(date: Date): string {
  return date.toISOString().replace("T", " ").slice(0, 16);
}

/** 相対時間を返す (e.g. "3分前", "2日前") */
export function timeAgo(date: Date, now = new Date()): string {
  const seconds = Math.floor((now.getTime() - date.getTime()) / 1000);
  if (seconds < 60) return `${seconds}秒前`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}分前`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}時間前`;
  const days = Math.floor(hours / 24);
  if (days < 30) return `${days}日前`;
  const months = Math.floor(days / 30);
  if (months < 12) return `${months}ヶ月前`;
  const years = Math.floor(months / 12);
  return `${years}年前`;
}
```

```typescript
// src/string.ts

/** 文字列を指定長で切り詰め、省略記号を付加する */
export function truncate(str: string, maxLength: number, suffix = "..."): string {
  if (str.length <= maxLength) return str;
  return str.slice(0, maxLength - suffix.length) + suffix;
}

/** 文字列をスラッグ化する */
export function slugify(str: string): string {
  return str
    .toLowerCase()
    .trim()
    .replace(/[^\w\s-]/g, "")
    .replace(/[\s_]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

/** 文字列をキャメルケースに変換する */
export function camelCase(str: string): string {
  return str
    .replace(/[-_\s]+(.)?/g, (_, c: string | undefined) =>
      c ? c.toUpperCase() : "",
    )
    .replace(/^[A-Z]/, (c) => c.toLowerCase());
}
```

```typescript
// src/assertion.ts

/** 値が null/undefined でないことを保証する */
export function assertDefined<T>(
  value: T | null | undefined,
  message = "Expected value to be defined",
): asserts value is T {
  if (value === null || value === undefined) {
    throw new Error(message);
  }
}

/** 条件が truthy であることを保証する */
export function assertNever(value: never): never {
  throw new Error(`Unexpected value: ${JSON.stringify(value)}`);
}

/** 値が null/undefined でなければその値を、そうでなければエラーを投げる */
export function unwrap<T>(value: T | null | undefined, message?: string): T {
  assertDefined(value, message);
  return value;
}
```

---

## db パッケージ (DB スキーマ、マイグレーション、シード)

### 目的

データベーススキーマ定義、マイグレーション、シードデータを一箇所で管理する。Drizzle ORM を使用し、型安全なデータアクセスを提供する。

### パッケージ構成

```
packages/db/
├── package.json
├── tsconfig.json
├── drizzle.config.ts
├── src/
│   ├── index.ts           # クライアント & スキーマのエクスポート
│   ├── client.ts          # DB クライアント生成
│   ├── schema/
│   │   ├── index.ts       # 全スキーマの re-export
│   │   ├── users.ts
│   │   ├── posts.ts
│   │   └── relations.ts   # リレーション定義
│   └── seed.ts            # シードスクリプト
├── drizzle/               # マイグレーションファイル (自動生成)
│   ├── 0000_initial.sql
│   ├── 0001_add_posts.sql
│   └── meta/
└── .env                   # DB 接続情報 (.gitignore 対象)
```

### package.json

```json
{
  "name": "@myproject/db",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "exports": {
    ".": {
      "types": "./src/index.ts",
      "default": "./src/index.ts"
    },
    "./client": {
      "types": "./src/client.ts",
      "default": "./src/client.ts"
    },
    "./schema": {
      "types": "./src/schema/index.ts",
      "default": "./src/schema/index.ts"
    }
  },
  "scripts": {
    "generate": "drizzle-kit generate",
    "migrate": "drizzle-kit migrate",
    "push": "drizzle-kit push",
    "studio": "drizzle-kit studio",
    "seed": "tsx src/seed.ts"
  },
  "dependencies": {
    "drizzle-orm": "catalog:",
    "postgres": "catalog:"
  },
  "devDependencies": {
    "drizzle-kit": "catalog:",
    "tsx": "catalog:",
    "typescript": "catalog:"
  }
}
```

### スキーマ定義例

```typescript
// src/schema/users.ts
import { pgTable, text, timestamp, uuid, varchar } from "drizzle-orm/pg-core";

export const users = pgTable("users", {
  id: uuid("id").primaryKey().defaultRandom(),
  email: varchar("email", { length: 255 }).notNull().unique(),
  name: varchar("name", { length: 100 }).notNull(),
  role: text("role", { enum: ["admin", "user", "viewer"] })
    .notNull()
    .default("user"),
  hashedPassword: text("hashed_password").notNull(),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true })
    .notNull()
    .defaultNow()
    .$onUpdate(() => new Date()),
});
```

```typescript
// src/schema/relations.ts
import { relations } from "drizzle-orm";
import { users } from "./users";
import { posts } from "./posts";

export const usersRelations = relations(users, ({ many }) => ({
  posts: many(posts),
}));

export const postsRelations = relations(posts, ({ one }) => ({
  author: one(users, {
    fields: [posts.authorId],
    references: [users.id],
  }),
}));
```

```typescript
// src/client.ts
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import * as schema from "./schema";

export function createDb(connectionString: string) {
  const client = postgres(connectionString);
  return drizzle(client, { schema });
}

export type Database = ReturnType<typeof createDb>;
```

```typescript
// src/index.ts
export { createDb, type Database } from "./client";
export * from "./schema";
```

### アプリケーションからの利用

```typescript
// apps/api/src/db.ts
import { createDb } from "@myproject/db/client";

export const db = createDb(process.env.DATABASE_URL!);
```

```typescript
// apps/api/src/routes/users.ts
import { db } from "../db";
import { users } from "@myproject/db/schema";
import { eq } from "drizzle-orm";

const allUsers = await db.query.users.findMany({
  with: { posts: true },
});

const user = await db.query.users.findFirst({
  where: eq(users.id, userId),
});
```

---

## パッケージの exports 設計パターン

### Conditional Exports

Node.js の条件付きエクスポートを使い、環境やバンドラーに応じたエントリポイントを提供する。

```json
{
  "exports": {
    ".": {
      // TypeScript の型解決 (最優先に配置)
      "types": "./dist/index.d.ts",
      // ESM
      "import": "./dist/index.js",
      // CommonJS (必要な場合のみ)
      "require": "./dist/index.cjs",
      // フォールバック
      "default": "./dist/index.js"
    }
  }
}
```

### 開発時 (ソースコード直接参照)

内部パッケージではビルドせずにソースを直接参照するパターンが効率的。

```json
{
  "exports": {
    ".": {
      "types": "./src/index.ts",
      "default": "./src/index.ts"
    }
  }
}
```

このパターンでは消費側のバンドラー (Next.js, Vite 等) がトランスパイルを担当する。Next.js の場合は `next.config.ts` で `transpilePackages` を設定する。

```typescript
// apps/web/next.config.ts
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  transpilePackages: ["@myproject/ui", "@myproject/schemas", "@myproject/utils"],
};

export default nextConfig;
```

### Subpath Exports

パッケージの一部だけをインポート可能にする。

```json
{
  "name": "@myproject/ui",
  "exports": {
    // メインエントリポイント
    ".": {
      "types": "./src/index.ts",
      "default": "./src/index.ts"
    },
    // 個別コンポーネント
    "./button": {
      "types": "./src/components/button.tsx",
      "default": "./src/components/button.tsx"
    },
    "./dialog": {
      "types": "./src/components/dialog.tsx",
      "default": "./src/components/dialog.tsx"
    },
    // ワイルドカード (v16.17.0+)
    "./components/*": {
      "types": "./src/components/*.tsx",
      "default": "./src/components/*.tsx"
    },
    // ユーティリティ
    "./lib/utils": {
      "types": "./src/lib/utils.ts",
      "default": "./src/lib/utils.ts"
    }
  }
}
```

### exports と typesVersions の併用

古い TypeScript バージョンとの互換性が必要な場合。

```json
{
  "exports": {
    ".": {
      "types": "./src/index.ts",
      "default": "./src/index.ts"
    },
    "./button": {
      "types": "./src/components/button.tsx",
      "default": "./src/components/button.tsx"
    }
  },
  "typesVersions": {
    "*": {
      "button": ["./src/components/button.tsx"]
    }
  }
}
```

---

## パッケージの依存関係管理

### 依存関係の種別と配置

| 種別 | 用途 | package.json フィールド |
|---|---|---|
| dependencies | ランタイムに必要 | `dependencies` |
| devDependencies | 開発・ビルドのみ | `devDependencies` |
| peerDependencies | 消費側が提供すべき | `peerDependencies` |

### peerDependencies の使い方

UI パッケージなど、フレームワーク依存のパッケージで使用する。

```json
{
  "name": "@myproject/ui",
  "peerDependencies": {
    "react": "^19.0.0",
    "react-dom": "^19.0.0"
  },
  "devDependencies": {
    "react": "catalog:",
    "react-dom": "catalog:"
  }
}
```

ポイントは以下の通り。

- `peerDependencies` に宣言すると消費側のバージョンを使う
- 開発時に必要なので `devDependencies` にも記載する
- `.npmrc` の `auto-install-peers=true` で自動インストールされる

### 内部パッケージの依存関係

ワークスペース内パッケージへの依存は `workspace:` プロトコルを使う。

```json
{
  "name": "@myproject/web",
  "dependencies": {
    "@myproject/schemas": "workspace:*",
    "@myproject/ui": "workspace:*",
    "@myproject/utils": "workspace:*"
  }
}
```

`workspace:*` はワークスペース内の最新バージョンにリンクする。`workspace:^` や `workspace:~` も使用可能。公開時には実際のバージョンに置換される。

### 依存関係の循環回避

パッケージ間の依存に循環が発生しないよう設計する。

```
推奨: 一方向の依存
schemas → (依存なし)
utils   → (依存なし)
db      → schemas
ui      → schemas, utils
api     → schemas, db, utils
web     → schemas, ui, utils

禁止: 循環依存
schemas → utils → schemas  (循環)
```

循環が発生しそうな場合は共通部分を別パッケージに切り出す。

---

## 内部パッケージ vs 公開パッケージの設計差異

### 内部パッケージ (private: true)

モノレポ内でのみ使用するパッケージ。

```json
{
  "name": "@myproject/schemas",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "exports": {
    ".": {
      "types": "./src/index.ts",
      "default": "./src/index.ts"
    }
  }
}
```

特徴は以下の通り。

- `"private": true` で npm への誤公開を防止する
- ソースコードを直接 exports できる (ビルド不要)
- 消費側のバンドラーがトランスパイルする
- バージョン管理は緩くてよい

### 公開パッケージ (npm 公開)

外部に公開するパッケージ。

```json
{
  "name": "@myorg/design-system",
  "version": "1.2.0",
  "type": "module",
  "license": "MIT",
  "main": "./dist/index.cjs",
  "module": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "import": "./dist/index.js",
      "require": "./dist/index.cjs"
    }
  },
  "files": [
    "dist",
    "README.md",
    "LICENSE"
  ],
  "scripts": {
    "build": "tsup src/index.ts --format cjs,esm --dts",
    "prepublishOnly": "pnpm build"
  },
  "publishConfig": {
    "access": "public"
  },
  "peerDependencies": {
    "react": "^18.0.0 || ^19.0.0"
  }
}
```

特徴は以下の通り。

- ビルド済みファイルを配布する (dist)
- CJS/ESM 両対応が望ましい
- `files` フィールドでパッケージに含めるファイルを明示する
- `peerDependencies` のバージョン範囲を広く取る
- セマンティックバージョニングを厳密に遵守する
- `README.md`, `LICENSE`, `CHANGELOG.md` を含める

### 比較表

| 項目 | 内部パッケージ | 公開パッケージ |
|---|---|---|
| private | `true` | `false` or 未指定 |
| exports | ソース直接 | ビルド済み |
| ビルド | 不要 (消費側) | 必須 |
| files | 不要 | 必須 |
| バージョン管理 | 緩い | セマンティック |
| CJS 対応 | 不要 | 推奨 |
| ドキュメント | 不要 | 必須 |
| テスト | 推奨 | 必須 |

---

## パッケージ追加手順

### 新しい共有パッケージの作成ステップ

以下は `packages/logger` という新しいパッケージを作成する例。

#### 1. ディレクトリとファイルの作成

```bash
mkdir -p packages/logger/src
```

#### 2. package.json の作成

```bash
cat > packages/logger/package.json << 'EOF'
{
  "name": "@myproject/logger",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "exports": {
    ".": {
      "types": "./src/index.ts",
      "default": "./src/index.ts"
    }
  },
  "scripts": {
    "typecheck": "tsc --noEmit",
    "lint": "eslint .",
    "test": "vitest run"
  },
  "devDependencies": {
    "typescript": "catalog:"
  }
}
EOF
```

#### 3. tsconfig.json の作成

```bash
cat > packages/logger/tsconfig.json << 'EOF'
{
  "extends": "@myproject/tsconfig/library.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src"]
}
EOF
```

#### 4. ソースコードの作成

```bash
cat > packages/logger/src/index.ts << 'EOF'
export function createLogger(prefix: string) {
  return {
    info: (message: string, ...args: unknown[]) =>
      console.log(`[${prefix}] INFO:`, message, ...args),
    warn: (message: string, ...args: unknown[]) =>
      console.warn(`[${prefix}] WARN:`, message, ...args),
    error: (message: string, ...args: unknown[]) =>
      console.error(`[${prefix}] ERROR:`, message, ...args),
  };
}

export type Logger = ReturnType<typeof createLogger>;
EOF
```

#### 5. 依存関係のインストール

```bash
# ルートから
pnpm install
```

#### 6. 消費側パッケージへの依存追加

```bash
# 特定のアプリから依存を追加
pnpm --filter @myproject/api add @myproject/logger@workspace:*
```

#### 7. pnpm-workspace.yaml の確認

`packages/*` のようなグロブパターンが既にあれば追加設定は不要。明示的に指定している場合は追加する。

```yaml
packages:
  - "apps/*"
  - "packages/*"    # この設定があれば packages/logger は自動認識
```

#### 8. turbo.json の確認

パッケージ固有のタスク設定が必要であれば追加する。通常、デフォルトのタスク定義で十分。

#### 9. 利用確認

```typescript
// apps/api/src/index.ts
import { createLogger } from "@myproject/logger";

const logger = createLogger("api");
logger.info("Server started");
```

### チェックリスト

新しいパッケージを作成したら以下を確認する。

- [ ] package.json の `name` がワークスペースの命名規則に従っている
- [ ] `private: true` が設定されている (内部パッケージの場合)
- [ ] `type: "module"` が設定されている
- [ ] `exports` フィールドが正しく設定されている
- [ ] tsconfig.json が共有設定を `extends` している
- [ ] `pnpm install` でエラーなくインストールできる
- [ ] 消費側から `import` して型が解決される
- [ ] `pnpm build` (Turborepo) が正しく動作する
- [ ] `pnpm typecheck` でエラーがない
- [ ] 循環依存が発生していない
