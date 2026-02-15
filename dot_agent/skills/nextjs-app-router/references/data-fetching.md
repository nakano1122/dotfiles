# データフェッチ詳細パターン

## 目次

1. [Server Component でのデータフェッチ](#server-component-でのデータフェッチ)
2. [Server Actions](#server-actions)
3. [Route Handlers](#route-handlers)
4. [クライアント側データフェッチ（例外パターン）](#クライアント側データフェッチ例外パターン)
5. [ストリーミングと Suspense](#ストリーミングと-suspense)
6. [キャッシュ戦略の詳細](#キャッシュ戦略の詳細)
7. [エラーハンドリング](#エラーハンドリング)

---

## Server Component でのデータフェッチ

### 基本パターン: Services → Mappers → Component

```typescript
// features/item/services/itemApi.ts
import type { GetItemsResponse } from "@project/schemas";

export async function fetchItems(): Promise<GetItemsResponse> {
  const res = await fetch(`${process.env.API_BASE_URL}/items`, {
    next: { tags: ["items"] },
  });
  if (!res.ok) throw new Error("Failed to fetch items");
  return res.json();
}

// features/item/mappers/itemMapper.ts
import type { GetItemsResponse } from "@project/schemas";
import type { Item } from "@/features/item/types";

export function toItems(response: GetItemsResponse): Item[] {
  return response.items.map((item) => ({
    id: item.id,
    title: item.title,
    createdAt: new Date(item.created_at),
  }));
}

// app/items/page.tsx
import { fetchItems } from "@/features/item/services/itemApi";
import { toItems } from "@/features/item/mappers/itemMapper";
import { ItemList } from "@/features/item/components/ItemList";

export default async function ItemsPage() {
  const response = await fetchItems();
  const items = toItems(response);
  return <ItemList items={items} />;
}
```

### 並列データフェッチ

```typescript
export default async function DashboardPage() {
  const [items, user] = await Promise.all([
    fetchItems(),
    fetchUser(),
  ]);
  return (
    <Dashboard
      items={toItems(items)}
      user={toUser(user)}
    />
  );
}
```

## Server Actions

フォーム送信やデータ変更に使用。`"use server"` ディレクティブを付与。

```typescript
// features/item/services/itemActions.ts
"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

export async function createItem(formData: FormData) {
  const title = formData.get("title") as string;

  const res = await fetch(`${process.env.API_BASE_URL}/items`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ title }),
  });

  if (!res.ok) {
    return { error: "作成に失敗しました" };
  }

  revalidatePath("/items");
  redirect("/items");
}
```

### フォームでの使用

```typescript
// features/item/components/CreateItemForm.tsx
"use client";

import { useActionState } from "react";
import { createItem } from "@/features/item/services/itemActions";

export function CreateItemForm() {
  const [state, action, isPending] = useActionState(createItem, null);

  return (
    <form action={action}>
      <input name="title" required />
      {state?.error && <p>{state.error}</p>}
      <button type="submit" disabled={isPending}>
        {isPending ? "作成中..." : "作成"}
      </button>
    </form>
  );
}
```

### 楽観的更新

```typescript
"use client";

import { useOptimistic } from "react";

export function ItemList({ items }: { items: Item[] }) {
  const [optimisticItems, addOptimistic] = useOptimistic(
    items,
    (state, newItem: Item) => [...state, newItem]
  );

  async function handleCreate(formData: FormData) {
    const title = formData.get("title") as string;
    addOptimistic({ id: "temp", title, createdAt: new Date() });
    await createItem(formData);
  }

  return (/* ... */);
}
```

## Route Handlers

外部 API からのコールバックや Webhook 受信に使用。

```typescript
// app/api/items/route.ts
import { NextRequest, NextResponse } from "next/server";

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams;
  const query = searchParams.get("q");
  // ...
  return NextResponse.json({ items });
}

export async function POST(request: NextRequest) {
  const body = await request.json();
  // ...
  return NextResponse.json({ item }, { status: 201 });
}
```

**原則**: データフェッチは Server Component で、ミューテーションは Server Actions で行う。Route Handlers は外部連携やストリーミングレスポンスに限定。

## クライアント側データフェッチ（例外パターン）

以下の場合のみ、Hooks から Services を呼び出す:

```typescript
// features/search/hooks/useSearch.ts
"use client";

import { useState, useTransition } from "react";
import { searchItems } from "@/features/search/services/searchApi";
import { toSearchResults } from "@/features/search/mappers/searchMapper";
import type { SearchResult } from "@/features/search/types";

export function useSearch() {
  const [results, setResults] = useState<SearchResult[]>([]);
  const [isPending, startTransition] = useTransition();

  const search = (query: string) => {
    startTransition(async () => {
      const response = await searchItems(query);
      setResults(toSearchResults(response));
    });
  };

  return { results, search, isPending };
}
```

### クライアント側取得が正当な場面

- **ユーザー操作連動**: 検索、フィルタ、無限スクロール、ソート
- **ブラウザ API 依存**: localStorage、geolocation
- **リアルタイム通信**: WebSocket、SSE
- **ポーリング**: 一定間隔でのデータ更新

## ストリーミングと Suspense

### loading.tsx によるページレベルの Suspense

```typescript
// app/items/loading.tsx
export default function Loading() {
  return <ItemListSkeleton />;
}
```

### コンポーネントレベルの Suspense

```typescript
// app/dashboard/page.tsx
import { Suspense } from "react";

export default function DashboardPage() {
  return (
    <div>
      <h1>ダッシュボード</h1>
      <Suspense fallback={<StatsSkeleton />}>
        <Stats />  {/* 重いデータを非同期取得 */}
      </Suspense>
      <Suspense fallback={<RecentItemsSkeleton />}>
        <RecentItems />
      </Suspense>
    </div>
  );
}
```

### Parallel Routes によるストリーミング

```
app/dashboard/
├── layout.tsx
├── page.tsx
├── @stats/
│   ├── page.tsx
│   └── loading.tsx
└── @activity/
    ├── page.tsx
    └── loading.tsx
```

```typescript
// app/dashboard/layout.tsx
export default function Layout({
  children,
  stats,
  activity,
}: {
  children: React.ReactNode;
  stats: React.ReactNode;
  activity: React.ReactNode;
}) {
  return (
    <div>
      {children}
      <div className="grid grid-cols-2 gap-4">
        {stats}
        {activity}
      </div>
    </div>
  );
}
```

## キャッシュ戦略の詳細

### Request Memoization

同一レンダリングパス内で同じ引数の fetch を自動的に1回に集約。

```typescript
// コンポーネント A と B が同じ fetch を呼んでも、実際の通信は1回
async function ComponentA() {
  const user = await fetchUser(); // ← 実際の fetch
  return <div>{user.name}</div>;
}

async function ComponentB() {
  const user = await fetchUser(); // ← メモ化された結果を使用
  return <div>{user.email}</div>;
}
```

### Data Cache

```typescript
// デフォルト: キャッシュされる
fetch(url);

// 時間ベースの再検証
fetch(url, { next: { revalidate: 3600 } });

// キャッシュしない
fetch(url, { cache: "no-store" });

// タグベースの再検証
fetch(url, { next: { tags: ["items"] } });
// → revalidateTag("items") で無効化
```

### オンデマンド再検証

```typescript
"use server";

import { revalidatePath, revalidateTag } from "next/cache";

// パスベース: 特定ページのキャッシュを無効化
revalidatePath("/items");

// タグベース: 特定タグのキャッシュを無効化
revalidateTag("items");
```

## エラーハンドリング

### error.tsx による Error Boundary

```typescript
// app/items/error.tsx
"use client";

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <div>
      <h2>エラーが発生しました</h2>
      <p>{error.message}</p>
      <button onClick={reset}>再試行</button>
    </div>
  );
}
```

### not-found.tsx による 404

```typescript
// app/items/[id]/page.tsx
import { notFound } from "next/navigation";

export default async function ItemPage({ params }: { params: { id: string } }) {
  const item = await fetchItem(params.id);
  if (!item) notFound();
  return <ItemDetail item={toItem(item)} />;
}

// app/items/[id]/not-found.tsx
export default function NotFound() {
  return <div>アイテムが見つかりません</div>;
}
```
