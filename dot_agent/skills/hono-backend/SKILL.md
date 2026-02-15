---
name: hono-backend
description: "Hono (TypeScript) バックエンドAPIの包括的な実装ガイド。ルート定義、ミドルウェア、Zodバリデーション、DIコンテナ、エラーハンドリング、認証/認可ミドルウェア、構造化ログ、RPCクライアント型生成、ランタイム別注意点をカバー。HonoでのAPI実装、ミドルウェア設計、バリデーション実装時に使用。"
---

# Hono Backend

Hono (TypeScript) バックエンドAPIの実装ガイド。ルート定義からミドルウェア、DI、認証、ロギング、ランタイム対応までをカバーする。

## ワークフロー

### 新規API追加

1. **ルート定義**: `new Hono<AppEnv>()` でルート作成、`zValidator` でバリデーション設定
2. **ミドルウェア設定**: 認証・CORS・コンテナ注入等の必要なミドルウェアを適用
3. **ビジネスロジック接続**: UseCase をインスタンス化し、DIコンテナから Repository を注入
4. **エラーハンドリング**: `onError` でドメインエラー・HTTPエラーをマッピング
5. **ルートマウント**: 親ルーターに `.route("/path", newRoute)` で結合
6. **RPC型エクスポート**: `export type AppType = typeof app` でクライアントに公開

### レビュー時

末尾のレビューチェックリストを参照。

## ルート定義とContext

```typescript
type AppEnv = { Bindings: Bindings; Variables: Variables };

const app = new Hono<AppEnv>()
  .get("/items", zValidator("query", ListQuerySchema), async (c) => {
    const { limit, offset } = c.req.valid("query"); // 型安全
    const repo = c.var.repositories.itemRepository;
    return c.json(await new ListItemsUsecase(repo).execute({ limit, offset }));
  })
  .post("/items", zValidator("json", CreateItemSchema), async (c) => {
    const body = c.req.valid("json");
    return c.json(created, 201);
  })
  .get("/:id", async (c) => {
    const id = c.req.param("id"); // パスパラメータ
  });

// ルート集約
const root = new Hono<AppEnv>()
  .onError(errorHandler)
  .use("*", corsMiddleware)
  .use("*", containerMiddleware)
  .route("/users", usersRoute)
  .route("/items", itemsRoute);
```

## ミドルウェア

### ビルトイン

```typescript
import { cors } from "hono/cors";
import { logger } from "hono/logger";
import { secureHeaders } from "hono/secure-headers";
import { timing } from "hono/timing";

app.use("*", cors({ origin: "https://example.com", credentials: true }));
app.use("*", logger());
app.use("*", secureHeaders());
app.use("*", timing());
```

### カスタムミドルウェア

```typescript
import { createMiddleware } from "hono/factory";

export const authMiddleware = createMiddleware<AppEnv>(async (c, next) => {
  const token = c.req.header("Authorization")?.replace("Bearer ", "");
  if (!token) throw new HTTPException(401, { message: "Unauthorized" });
  c.set("user", await verifyToken(token));
  await next();
});
```

詳細は [references/middleware-patterns.md](references/middleware-patterns.md) を参照。

## バリデーション (zValidator + Zod)

```typescript
import { zValidator } from "@hono/zod-validator";
import { z } from "zod";

const Schema = z.object({ nickname: z.string().min(1).max(50), email: z.string().email() });

// ターゲット: "json" | "query" | "param" | "header" | "cookie" | "form"
app.post("/users", zValidator("json", Schema), async (c) => {
  const { nickname, email } = c.req.valid("json"); // 型安全
});

// カスタムエラーレスポンス
app.post("/users", zValidator("json", Schema, (result, c) => {
  if (!result.success) return c.json({ error: result.error.flatten() }, 400);
}), handler);
```

## DIコンテナパターン

```typescript
// コンテナ生成
export type Repositories = { itemRepository: ItemRepository; userRepository: UserRepository | null };

export const createRepositories = (db: D1Database | undefined): Repositories => {
  if (db) return { itemRepository: new D1ItemRepository(db), userRepository: new D1UserRepository(db) };
  return { itemRepository: new InMemoryItemRepository(), userRepository: null };
};

// ミドルウェアで注入
export const containerMiddleware: MiddlewareHandler<AppEnv> = async (c, next) => {
  c.set("repositories", createRepositories(c.env?.DB));
  await next();
};

// ルートで使用
const { userRepository } = c.var.repositories;
if (!userRepository) throw new DatabaseNotConfiguredError();
const usecase = new CreateUserUsecase(userRepository);
```

詳細は [references/di-container.md](references/di-container.md) を参照。

## エラーハンドリング

```typescript
import { HTTPException } from "hono/http-exception";

app.onError((err, c) => {
  if (err instanceof HTTPException)
    return c.json({ error: { code: "HTTP_ERROR", message: err.message } }, err.status);
  if (err instanceof DomainError)
    return c.json({ error: { code: err.code, message: err.message } }, err.statusCode);
  console.error("Unexpected:", err);
  return c.json({ error: { code: "INTERNAL_ERROR", message: "Internal Server Error" } }, 500);
});

// ルート内で明示的にスロー
throw new HTTPException(404, { message: "Not found" });
```

## 認証/認可ミドルウェア

### JWT検証

```typescript
import { jwt } from "hono/jwt";
app.use("/api/*", jwt({ secret: "your-secret" }));
// c.get("jwtPayload") で payload にアクセス
```

### セッションベース認証

```typescript
export const sessionAuth = createMiddleware<AppEnv>(async (c, next) => {
  const sessionId = c.req.header("X-Session-ID");
  if (!sessionId) throw new HTTPException(401, { message: "No session" });
  const session = await c.var.repositories.sessionRepository.findById(sessionId);
  if (!session || session.isExpired()) throw new HTTPException(401, { message: "Invalid session" });
  c.set("currentUser", session.user);
  await next();
});
```

### RBAC

```typescript
export const requireRole = (...roles: string[]) =>
  createMiddleware<AppEnv>(async (c, next) => {
    const user = c.get("currentUser");
    if (!user || !roles.includes(user.role)) throw new HTTPException(403, { message: "Forbidden" });
    await next();
  });

app.delete("/users/:id", sessionAuth, requireRole("admin"), handler);
```

## ロギング実装

### 構造化ログ

```typescript
export const structuredLogger = createMiddleware<AppEnv>(async (c, next) => {
  const start = Date.now();
  await next();
  console.log(JSON.stringify({
    method: c.req.method, path: c.req.path, status: c.res.status,
    duration: Date.now() - start, timestamp: new Date().toISOString(),
    requestId: c.req.header("X-Request-ID") ?? crypto.randomUUID(),
  }));
});
```

### Cloudflare Workers (Analytics Engine)

```typescript
export const analyticsLogger = createMiddleware<AppEnv>(async (c, next) => {
  const start = Date.now();
  await next();
  c.env.ACCESS_LOGS?.writeDataPoint({
    blobs: [c.req.method, c.req.path, String(c.res.status)],
    doubles: [Date.now() - start],
  });
});
```

## ランタイム別注意点

### Cloudflare Workers

- `env` は `c.env` 経由 (`process.env` 不可)
- D1/KV/R2 は `wrangler.toml` で binding 設定
- `node:` prefix でNode.js互換API限定利用可

### Node.js / Bun

```typescript
// Node.js
import { serve } from "@hono/node-server";
serve({ fetch: app.fetch, port: 3000 });

// Bun
export default { fetch: app.fetch, port: 3000 };
```

## RPCクライアント型生成

```typescript
// サーバー側
const app = new Hono().get("/users", handler).post("/users", handler);
export type AppType = typeof app;

// クライアント側
import { hc } from "hono/client";
import type { AppType } from "../server";
const client = hc<AppType>("http://localhost:3000");
const res = await client.users.$get({ query: { limit: "10" } });
const data = await res.json(); // 型安全
```

**注意**: チェーンが途切れると型推論が失敗する。`.route()` 結合時も各サブルートで型を保持すること。

## 環境設定

### AppEnv 型定義

```typescript
type Bindings = { DB: D1Database; KV: KVNamespace; CORS_ORIGIN?: string; API_KEY?: string };
type Variables = { repositories: Repositories; currentUser?: User };
type AppEnv = { Bindings: Bindings; Variables: Variables };
```

### wrangler.toml

```toml
name = "my-api"
main = "src/index.ts"
compatibility_date = "2024-01-01"

[[d1_databases]]
binding = "DB"
database_name = "my-db"
database_id = "xxx"

[vars]
CORS_ORIGIN = "https://example.com"
```

## レビューチェックリスト

- [ ] ルートに `zValidator` でバリデーション設定済み
- [ ] `AppEnv` 型が Bindings/Variables を正しく定義
- [ ] `onError` でドメインエラー・HTTPException を適切にハンドリング
- [ ] DIコンテナから Repository を取得し、null チェック実施
- [ ] 認証が必要なルートにミドルウェア適用済み
- [ ] 構造化ログがリクエスト/レスポンスを記録
- [ ] RPC型エクスポートのチェーン維持
- [ ] Cloudflare Workers の場合 `c.env` 経由で環境変数アクセス
- [ ] エラーレスポンスが統一フォーマット (`{ error: { code, message } }`)

## リファレンス

- [references/middleware-patterns.md](references/middleware-patterns.md) - ミドルウェアパターン詳細
- [references/di-container.md](references/di-container.md) - DIコンテナ実装パターン
- [Hono 公式ドキュメント](https://hono.dev/)
- [Hono RPC](https://hono.dev/docs/guides/rpc)
- [@hono/zod-validator](https://github.com/honojs/middleware/tree/main/packages/zod-validator)
