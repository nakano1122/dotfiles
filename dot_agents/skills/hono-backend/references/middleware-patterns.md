# ミドルウェアパターン詳細

## 目次

- [概要](#概要)
- [ミドルウェア実行順序](#ミドルウェア実行順序)
- [CORS ミドルウェア](#cors-ミドルウェア)
  - [ビルトイン cors](#ビルトイン-cors)
- [認証ミドルウェア](#認証ミドルウェア)
  - [JWT 認証 (ビルトイン)](#jwt-認証-ビルトイン)
  - [JWT 認証 (カスタム / 外部IdP 対応)](#jwt-認証-カスタム-外部idp-対応)
  - [Bearer Token / API Key 認証](#bearer-token-api-key-認証)
  - [ユーザー識別ミドルウェア (オプショナル認証)](#ユーザー識別ミドルウェア-オプショナル認証)
- [RBAC (ロールベースアクセス制御)](#rbac-ロールベースアクセス制御)
- [ロギングミドルウェア](#ロギングミドルウェア)
  - [ビルトイン logger](#ビルトイン-logger)
  - [構造化ログミドルウェア](#構造化ログミドルウェア)
  - [Cloudflare Workers Analytics Engine](#cloudflare-workers-analytics-engine)
- [エラーハンドリングミドルウェア](#エラーハンドリングミドルウェア)
  - [グローバル onError](#グローバル-onerror)
  - [notFound ハンドラ](#notfound-ハンドラ)
- [セキュリティミドルウェア](#セキュリティミドルウェア)
  - [Secure Headers](#secure-headers)
  - [レートリミット (カスタム)](#レートリミット-カスタム)
- [タイミングミドルウェア](#タイミングミドルウェア)
- [ミドルウェア適用パターン](#ミドルウェア適用パターン)
  - [グローバル適用](#グローバル適用)
  - [パスベース適用](#パスベース適用)
  - [ルート単位適用](#ルート単位適用)
  - [ミドルウェア合成](#ミドルウェア合成)

## 概要

Hono のミドルウェアは `(c, next) => Promise<void | Response>` の形式で、`createMiddleware` を使うと型安全に記述できる。`await next()` の前後でリクエスト/レスポンスの処理を挟む。

## ミドルウェア実行順序

```typescript
app.use("*", middlewareA);  // 1番目に実行
app.use("*", middlewareB);  // 2番目に実行
app.get("/path", handler);  // ハンドラ

// 実行順: A(前) → B(前) → handler → B(後) → A(後)
```

## CORS ミドルウェア

### ビルトイン cors

```typescript
import { cors } from "hono/cors";

// 固定オリジン
app.use("*", cors({ origin: "https://example.com", credentials: true }));

// 複数オリジン
app.use("*", cors({ origin: ["https://app.example.com", "https://admin.example.com"] }));

// 動的オリジン (env から取得)
export const corsMiddleware: MiddlewareHandler<AppEnv> = cors({
  origin: (origin, c) => {
    const allowed = c.env?.CORS_ORIGIN;
    if (!allowed) return origin; // 未設定なら全許可
    return allowed;
  },
  credentials: true,
  allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
  allowHeaders: ["Content-Type", "Authorization", "X-User-ID"],
  maxAge: 86400,
});
```

## 認証ミドルウェア

### JWT 認証 (ビルトイン)

```typescript
import { jwt } from "hono/jwt";

// 基本的な JWT 検証
app.use("/api/*", jwt({ secret: "your-secret" }));

// ハンドラ内で payload 取得
app.get("/api/me", (c) => {
  const payload = c.get("jwtPayload");
  return c.json({ userId: payload.sub });
});
```

### JWT 認証 (カスタム / 外部IdP 対応)

```typescript
import { createMiddleware } from "hono/factory";
import { HTTPException } from "hono/http-exception";

export const jwtAuth = createMiddleware<AppEnv>(async (c, next) => {
  const authHeader = c.req.header("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    throw new HTTPException(401, { message: "Missing or invalid Authorization header" });
  }

  const token = authHeader.slice(7);
  try {
    const payload = await verifyJwtToken(token, c.env.JWT_PUBLIC_KEY);
    c.set("currentUser", { id: payload.sub, role: payload.role });
  } catch {
    throw new HTTPException(401, { message: "Invalid or expired token" });
  }

  await next();
});
```

### Bearer Token / API Key 認証

```typescript
import { bearerAuth } from "hono/bearer-auth";

// 固定トークン
app.use("/internal/*", bearerAuth({ token: "static-api-key" }));

// 動的検証
app.use("/internal/*", bearerAuth({
  verifyToken: async (token, c) => {
    return token === c.env.INTERNAL_API_KEY;
  },
}));
```

### ユーザー識別ミドルウェア (オプショナル認証)

```typescript
export const userIdentification = createMiddleware<AppEnv>(async (c, next) => {
  const userId = c.req.header("X-User-ID");
  if (userId) {
    const user = await c.var.repositories.userRepository?.findById(userId);
    c.set("user", user ?? null);
  } else {
    c.set("user", null);
  }
  await next();
});
```

## RBAC (ロールベースアクセス制御)

```typescript
export const requireRole = (...roles: string[]) =>
  createMiddleware<AppEnv>(async (c, next) => {
    const user = c.get("currentUser");
    if (!user) {
      throw new HTTPException(401, { message: "Authentication required" });
    }
    if (!roles.includes(user.role)) {
      throw new HTTPException(403, { message: `Required role: ${roles.join(" or ")}` });
    }
    await next();
  });

// 適用
app.get("/admin/users", jwtAuth, requireRole("admin"), adminHandler);
app.put("/items/:id", jwtAuth, requireRole("admin", "editor"), editHandler);
```

## ロギングミドルウェア

### ビルトイン logger

```typescript
import { logger } from "hono/logger";
app.use("*", logger()); // --> GET /users 200 12ms
```

### 構造化ログミドルウェア

```typescript
export const structuredLogger = createMiddleware<AppEnv>(async (c, next) => {
  const requestId = c.req.header("X-Request-ID") ?? crypto.randomUUID();
  c.header("X-Request-ID", requestId);

  const start = Date.now();
  await next();
  const duration = Date.now() - start;

  const logEntry = {
    timestamp: new Date().toISOString(),
    requestId,
    method: c.req.method,
    path: c.req.path,
    status: c.res.status,
    duration,
    userAgent: c.req.header("User-Agent"),
    ip: c.req.header("CF-Connecting-IP") ?? c.req.header("X-Forwarded-For"),
  };

  // ステータスコードに応じてログレベルを変更
  if (c.res.status >= 500) {
    console.error(JSON.stringify(logEntry));
  } else if (c.res.status >= 400) {
    console.warn(JSON.stringify(logEntry));
  } else {
    console.log(JSON.stringify(logEntry));
  }
});
```

### Cloudflare Workers Analytics Engine

```typescript
export const analyticsLogger = createMiddleware<AppEnv>(async (c, next) => {
  const start = Date.now();
  await next();

  c.env.ACCESS_LOGS?.writeDataPoint({
    blobs: [c.req.method, c.req.path, String(c.res.status), c.req.header("User-Agent") ?? ""],
    doubles: [Date.now() - start],
    indexes: [c.req.path],
  });
});
```

## エラーハンドリングミドルウェア

### グローバル onError

```typescript
import { HTTPException } from "hono/http-exception";

type ErrorResponse = { error: { code: string; message: string } };

app.onError((err, c) => {
  // Hono HTTPException
  if (err instanceof HTTPException) {
    const res: ErrorResponse = {
      error: { code: `HTTP_${err.status}`, message: err.message },
    };
    return c.json(res, err.status);
  }

  // ドメインエラー (statusCode を持つカスタムエラー)
  if (err instanceof DomainError) {
    const res: ErrorResponse = {
      error: { code: err.code, message: err.message },
    };
    return c.json(res, err.statusCode as ContentfulStatusCode);
  }

  // Zod バリデーションエラー (zValidator 外で発生した場合)
  if (err.name === "ZodError") {
    const res: ErrorResponse = {
      error: { code: "VALIDATION_ERROR", message: "Invalid request" },
    };
    return c.json(res, 400);
  }

  // 予期しないエラー
  console.error("[ErrorHandler] Unexpected error:", err);
  const res: ErrorResponse = {
    error: { code: "INTERNAL_SERVER_ERROR", message: "An unexpected error occurred" },
  };
  return c.json(res, 500);
});
```

### notFound ハンドラ

```typescript
app.notFound((c) => {
  return c.json({ error: { code: "NOT_FOUND", message: `Route not found: ${c.req.path}` } }, 404);
});
```

## セキュリティミドルウェア

### Secure Headers

```typescript
import { secureHeaders } from "hono/secure-headers";
app.use("*", secureHeaders());
```

### レートリミット (カスタム)

```typescript
export const rateLimit = (maxRequests: number, windowMs: number) =>
  createMiddleware<AppEnv>(async (c, next) => {
    const key = c.req.header("CF-Connecting-IP") ?? "unknown";
    const current = await c.env.KV.get(`rate:${key}`);
    const count = current ? parseInt(current, 10) : 0;

    if (count >= maxRequests) {
      throw new HTTPException(429, { message: "Too many requests" });
    }

    await c.env.KV.put(`rate:${key}`, String(count + 1), { expirationTtl: Math.ceil(windowMs / 1000) });
    await next();
  });

app.use("/api/*", rateLimit(100, 60_000)); // 100 req/min
```

## タイミングミドルウェア

```typescript
import { timing, startTime, endTime } from "hono/timing";

app.use("*", timing());

app.get("/items", async (c) => {
  startTime(c, "db");
  const items = await fetchFromDB();
  endTime(c, "db");
  return c.json(items);
});
// Server-Timing ヘッダーが自動的に付与される
```

## ミドルウェア適用パターン

### グローバル適用

```typescript
app.use("*", corsMiddleware);
app.use("*", structuredLogger);
```

### パスベース適用

```typescript
app.use("/api/*", jwtAuth);
app.use("/admin/*", jwtAuth, requireRole("admin"));
```

### ルート単位適用

```typescript
app.get("/public", publicHandler);
app.get("/private", jwtAuth, privateHandler);
app.delete("/admin/users/:id", jwtAuth, requireRole("admin"), deleteUserHandler);
```

### ミドルウェア合成

```typescript
// 複数ミドルウェアを1つにまとめる
const adminGuard = [jwtAuth, requireRole("admin")] as const;

// ルートグループに適用
const adminApp = new Hono<AppEnv>();
adminApp.use("*", ...adminGuard);
adminApp.get("/users", listUsersHandler);
adminApp.delete("/users/:id", deleteUserHandler);

app.route("/admin", adminApp);
```
