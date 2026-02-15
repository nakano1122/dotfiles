---
name: nextjs-app-router
description: Next.js App Router (TypeScript) の包括的な実装ガイド。App Routerの基本構造、Feature-Based Architecture、Server/Client Components使い分け、データフェッチパターン、キャッシュ戦略、状態管理、認証UIパターン、メタデータ/SEO、ミドルウェア、環境設定をカバー。Next.js App Routerでの機能実装、アーキテクチャ設計時に使用。
---

# Next.js App Router 実装ガイド

## App Router 基本構造

```
app/
├── layout.tsx          # ルートレイアウト（必須）
├── page.tsx            # トップページ
├── loading.tsx         # Suspense フォールバック UI
├── error.tsx           # Error Boundary（"use client" 必須）
├── not-found.tsx       # 404 ページ
├── [slug]/             # 動的ルート
│   └── page.tsx
├── (group)/            # Route Group（URLに影響しないグルーピング）
│   └── settings/
│       └── page.tsx
└── api/                # Route Handlers
    └── route.ts
```

- `layout.tsx`: 子ルート間で共有される UI。再レンダリングされない
- `loading.tsx`: 配置するだけで自動的に `Suspense` 境界を作成
- `error.tsx`: 配置するだけで自動的に Error Boundary を作成
- `template.tsx`: layout と似るがナビゲーション毎に再マウントされる

## Feature-Based Architecture

```
src/
├── app/                 # App Router（ルーティングのみ、ロジック最小限）
├── components/          # 共有コンポーネント（ui/, layout/, feedback/）
├── features/            # 機能別モジュール（自己完結）
│   └── [feature]/
│       ├── components/  # Feature 固有コンポーネント
│       ├── hooks/       # カスタムフック（状態管理）
│       ├── services/    # API 呼び出し
│       ├── types/       # フロントエンド独自型
│       └── mappers/     # API型 → フロントエンド型変換
├── lib/                 # 共有ユーティリティ
├── config/              # 設定
└── styles/              # スタイル定義
```

### Feature 間依存ルール

**Feature 間の直接依存は禁止**。

| 状況 | 対処法 |
|------|--------|
| 複数 Feature で使う汎用コンポーネント | `components/` に移動 |
| 複数 Feature で使うユーティリティ | `lib/` に移動 |
| 2つの Feature が密結合 | 1つの Feature に統合 |

### 責務分離

| レイヤー | 責務 | 共有スキーマ使用 |
|---------|------|-----------------|
| Server Component | データフェッチ、Services 呼び出し | ❌ |
| Client Component | JSX レンダリング、ユーザー操作 | ❌ |
| Hooks | 状態管理、イベントハンドラ | ❌ |
| Services | API 呼び出し | ✅ |
| Mappers | API レスポンス → フロントエンド型変換 | ✅ |

詳細: [references/feature-architecture.md](references/feature-architecture.md)

## Server Components vs Client Components

```
判断木:
  イベントハンドラ (onClick等) が必要？ → Yes → Client Component ("use client")
  useState / useEffect が必要？ → Yes → Client Component
  ブラウザ API (localStorage等) が必要？ → Yes → Client Component
  上記すべて No → Server Component（デフォルト）
```

**原則**: Server Component をデフォルトにし、必要な場合のみ `"use client"` を追加。Client Component は可能な限り末端（リーフ）に配置する。

## データフェッチパターン

### 基本: Server Component → Services → Mappers

```typescript
// app/items/page.tsx (Server Component)
import { fetchItems } from "@/features/item/services/itemApi";
import { toItems } from "@/features/item/mappers/itemMapper";
import { ItemList } from "@/features/item/components/ItemList";

export default async function ItemsPage() {
  const response = await fetchItems();
  const items = toItems(response);
  return <ItemList items={items} />;
}
```

### Server Actions（フォーム送信・ミューテーション）

```typescript
// features/item/services/itemActions.ts
"use server";

export async function createItem(formData: FormData) {
  const title = formData.get("title") as string;
  // DB操作やAPI呼び出し
  revalidatePath("/items");
}
```

### 例外: クライアント側取得が必要な場合

- ユーザー操作に紐づく取得（検索、フィルタ、無限スクロール）
- ブラウザ API 依存（localStorage 等）
- WebSocket / SSE 常時接続

→ この場合のみ Hooks から Services を呼び出す

詳細: [references/data-fetching.md](references/data-fetching.md)

## キャッシュ戦略

| レイヤー | 対象 | 説明 |
|---------|------|------|
| Request Memoization | 同一リクエスト内の重複 fetch | 自動。同一引数の fetch を1回に集約 |
| Data Cache | fetch レスポンス | `fetch()` のデフォルト。`revalidate` で制御 |
| Full Route Cache | レンダリング済み HTML/RSC Payload | 静的ルートで自動適用 |
| Router Cache | クライアント側のルート情報 | ナビゲーション高速化 |

```typescript
// キャッシュ制御の例
fetch(url, { next: { revalidate: 3600 } }); // 1時間キャッシュ
fetch(url, { cache: "no-store" });           // キャッシュ無効
```

**再検証**: `revalidatePath()` / `revalidateTag()` で明示的に無効化

## 状態管理

**グローバルステートライブラリは原則不要**

| 用途 | 推奨手法 |
|------|---------|
| サーバーデータ | Server Components + Request Memoization |
| クライアント UI 状態 | useState / 軽量ライブラリ |
| フォーム状態 | useActionState / React Hook Form |

### コンポジションパターン（Props Drilling 回避）

```typescript
// ✅ 各 Server Component が独立してデータ取得
async function Page() {
  return (
    <Layout>
      <UserProfile />  {/* 自分で fetchUser() を呼ぶ */}
      <Content />
    </Layout>
  );
}
```

同一リクエスト内の重複 fetch は Request Memoization で自動排除される。

## 認証 UI パターン

### ミドルウェア認証

```typescript
// middleware.ts
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

export function middleware(request: NextRequest) {
  const token = request.cookies.get("session")?.value;
  if (!token && request.nextUrl.pathname.startsWith("/dashboard")) {
    return NextResponse.redirect(new URL("/login", request.url));
  }
  return NextResponse.next();
}

export const config = { matcher: ["/dashboard/:path*"] };
```

### セッション管理パターン

- Server Component でセッション検証 → ユーザー情報を Props として渡す
- Client Component でのセッション参照は専用 Hook で抽象化
- トークンリフレッシュは Server Action またはミドルウェアで処理

## メタデータ / SEO

```typescript
// 静的メタデータ
export const metadata: Metadata = {
  title: "ページタイトル",
  description: "説明文",
};

// 動的メタデータ
export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const item = await fetchItem(params.id);
  return { title: item.name };
}
```

## 環境設定

### 環境変数

| プレフィックス | アクセス範囲 |
|--------------|-------------|
| `NEXT_PUBLIC_` | クライアント + サーバー |
| なし | サーバーのみ |

```typescript
// next.config.ts
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  images: { remotePatterns: [{ hostname: "example.com" }] },
  experimental: { /* 実験的機能 */ },
};

export default nextConfig;
```

## コーディング規約

- **インポート**: パスエイリアス (`@/`) 必須。相対パス禁止
- **バレルファイル**: `index.ts` 経由のインポート禁止
- **スタイル**: インラインスタイル (`style` 属性) 禁止。Tailwind CSS + `cn()` を使用
- **コンポーネント**: 1ファイル1コンポーネント。`useState`/`useEffect` はカスタムフックに分離

## リファレンス

- [feature-architecture.md](references/feature-architecture.md) - Feature 構造、依存ルール、型管理の詳細
- [data-fetching.md](references/data-fetching.md) - データフェッチ、キャッシュ、ストリーミングの詳細パターン
- [routing-patterns.md](references/routing-patterns.md) - ルーティング、ミドルウェア、認証UIの詳細パターン
