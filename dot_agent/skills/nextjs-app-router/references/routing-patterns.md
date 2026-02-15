# ルーティング・ミドルウェア・認証 UI 詳細パターン

## 目次

1. [ルーティングパターン](#ルーティングパターン)
2. [ミドルウェア](#ミドルウェア)
3. [認証 UI パターン](#認証-ui-パターン)
4. [画像最適化](#画像最適化)
5. [メタデータ / SEO 詳細](#メタデータ--seo-詳細)

---

## ルーティングパターン

### 動的ルート

```
app/items/[id]/page.tsx         # /items/123
app/blog/[...slug]/page.tsx     # /blog/2024/01/title (Catch-all)
app/shop/[[...slug]]/page.tsx   # /shop または /shop/any/path (Optional catch-all)
```

```typescript
// app/items/[id]/page.tsx
type Props = { params: Promise<{ id: string }> };

export default async function ItemPage({ params }: Props) {
  const { id } = await params;
  const item = await fetchItem(id);
  return <ItemDetail item={toItem(item)} />;
}
```

### Route Groups

URL パスに影響を与えずにルートをグルーピング。

```
app/
├── (marketing)/         # マーケティング用レイアウト
│   ├── layout.tsx
│   ├── about/page.tsx   # /about
│   └── blog/page.tsx    # /blog
├── (app)/               # アプリ用レイアウト
│   ├── layout.tsx
│   ├── dashboard/page.tsx  # /dashboard
│   └── settings/page.tsx   # /settings
└── layout.tsx           # ルートレイアウト
```

### Parallel Routes

```
app/dashboard/
├── layout.tsx
├── page.tsx
├── @analytics/
│   ├── page.tsx
│   └── loading.tsx
└── @notifications/
    ├── page.tsx
    └── loading.tsx
```

```typescript
// app/dashboard/layout.tsx
export default function Layout({
  children,
  analytics,
  notifications,
}: {
  children: React.ReactNode;
  analytics: React.ReactNode;
  notifications: React.ReactNode;
}) {
  return (
    <div>
      {children}
      <aside>{analytics}</aside>
      <aside>{notifications}</aside>
    </div>
  );
}
```

### Intercepting Routes

モーダル表示などで、URLは変えつつ現在のレイアウト内にコンテンツを表示。

```
app/
├── items/
│   ├── page.tsx           # /items (一覧)
│   └── [id]/
│       └── page.tsx       # /items/123 (詳細 - 直接アクセス時)
├── @modal/
│   └── (.)items/[id]/
│       └── page.tsx       # /items/123 (一覧からの遷移時 - モーダル表示)
└── layout.tsx
```

## ミドルウェア

### 基本構造

```typescript
// middleware.ts (プロジェクトルートに配置)
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

export function middleware(request: NextRequest) {
  // リクエスト処理
  const response = NextResponse.next();

  // レスポンスヘッダー追加
  response.headers.set("x-custom-header", "value");

  return response;
}

// matcher でミドルウェア適用パスを制限
export const config = {
  matcher: [
    // 静的ファイルと _next を除外
    "/((?!_next/static|_next/image|favicon.ico).*)",
  ],
};
```

### 典型的なミドルウェア用途

```typescript
export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // 1. 認証チェック
  const token = request.cookies.get("session")?.value;
  if (!token && pathname.startsWith("/dashboard")) {
    return NextResponse.redirect(new URL("/login", request.url));
  }

  // 2. リダイレクト
  if (pathname === "/old-path") {
    return NextResponse.redirect(new URL("/new-path", request.url));
  }

  // 3. リライト (URL は変えずに別ルートを表示)
  if (pathname.startsWith("/api/v1")) {
    return NextResponse.rewrite(new URL(`/api/v2${pathname.slice(7)}`, request.url));
  }

  // 4. ヘッダー操作
  const response = NextResponse.next();
  response.headers.set("x-request-id", crypto.randomUUID());
  return response;
}
```

### ミドルウェアの制約

- Edge Runtime で動作（Node.js API の一部は使用不可）
- 直接 DB アクセスは不可（API 経由で行う）
- レスポンスボディの直接返却は不可（redirect/rewrite/next のみ）

## 認証 UI パターン

### ログインページ

```typescript
// app/login/page.tsx (Server Component)
import { redirect } from "next/navigation";
import { getSession } from "@/lib/auth";
import { LoginForm } from "@/features/auth/components/LoginForm";

export default async function LoginPage() {
  const session = await getSession();
  if (session) redirect("/dashboard");
  return <LoginForm />;
}
```

```typescript
// features/auth/components/LoginForm.tsx
"use client";

import { useActionState } from "react";
import { login } from "@/features/auth/services/authActions";

export function LoginForm() {
  const [state, action, isPending] = useActionState(login, null);

  return (
    <form action={action}>
      <input name="email" type="email" required />
      <input name="password" type="password" required />
      {state?.error && <p className="text-red-500">{state.error}</p>}
      <button type="submit" disabled={isPending}>
        {isPending ? "ログイン中..." : "ログイン"}
      </button>
    </form>
  );
}
```

### Server Action による認証

```typescript
// features/auth/services/authActions.ts
"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";

export async function login(prevState: unknown, formData: FormData) {
  const email = formData.get("email") as string;
  const password = formData.get("password") as string;

  const res = await fetch(`${process.env.API_BASE_URL}/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });

  if (!res.ok) {
    return { error: "メールアドレスまたはパスワードが正しくありません" };
  }

  const { token } = await res.json();
  const cookieStore = await cookies();
  cookieStore.set("session", token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
  });

  redirect("/dashboard");
}

export async function logout() {
  const cookieStore = await cookies();
  cookieStore.delete("session");
  redirect("/login");
}
```

### 認証済みレイアウト

```typescript
// app/(authenticated)/layout.tsx
import { redirect } from "next/navigation";
import { getSession } from "@/lib/auth";

export default async function AuthenticatedLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const session = await getSession();
  if (!session) redirect("/login");

  return (
    <div>
      <Header user={session.user} />
      <main>{children}</main>
    </div>
  );
}
```

## 画像最適化

### next/image

```typescript
import Image from "next/image";

// ローカル画像（自動サイズ検出）
import heroImage from "@/assets/hero.jpg";
<Image src={heroImage} alt="Hero" placeholder="blur" />

// リモート画像（サイズ指定必須）
<Image
  src="https://example.com/image.jpg"
  alt="Example"
  width={800}
  height={600}
  priority  // LCP 画像には priority を付与
/>

// レスポンシブ
<Image
  src="/image.jpg"
  alt="Responsive"
  fill
  sizes="(max-width: 768px) 100vw, 50vw"
  className="object-cover"
/>
```

### next.config での設定

```typescript
const nextConfig: NextConfig = {
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "example.com" },
      { protocol: "https", hostname: "**.amazonaws.com" },
    ],
    formats: ["image/avif", "image/webp"],
  },
};
```

## メタデータ / SEO 詳細

### 静的メタデータ

```typescript
// app/layout.tsx
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: {
    template: "%s | サイト名",
    default: "サイト名",
  },
  description: "サイトの説明",
  openGraph: {
    type: "website",
    locale: "ja_JP",
    siteName: "サイト名",
  },
};
```

### 動的メタデータ

```typescript
// app/items/[id]/page.tsx
import type { Metadata } from "next";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>;
}): Promise<Metadata> {
  const { id } = await params;
  const item = await fetchItem(id);

  return {
    title: item.title,
    description: item.description,
    openGraph: {
      title: item.title,
      description: item.description,
      images: [item.imageUrl],
    },
  };
}
```

### generateStaticParams（SSG）

```typescript
// app/items/[id]/page.tsx
export async function generateStaticParams() {
  const items = await fetchAllItems();
  return items.map((item) => ({ id: item.id }));
}
```

### sitemap.xml / robots.txt

```typescript
// app/sitemap.ts
import type { MetadataRoute } from "next";

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    { url: "https://example.com", lastModified: new Date() },
    { url: "https://example.com/items", lastModified: new Date() },
  ];
}

// app/robots.ts
import type { MetadataRoute } from "next";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: { userAgent: "*", allow: "/", disallow: "/private/" },
    sitemap: "https://example.com/sitemap.xml",
  };
}
```
