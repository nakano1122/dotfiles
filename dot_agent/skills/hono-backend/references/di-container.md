# DIコンテナ実装パターン

## 目次

- [概要](#概要)
- [アーキテクチャ](#アーキテクチャ)
- [型定義](#型定義)
  - [Repositories 型](#repositories-型)
  - [AppEnv 型](#appenv-型)
- [コンテナ生成関数](#コンテナ生成関数)
  - [基本パターン](#基本パターン)
  - [シングルトン対応](#シングルトン対応)
- [コンテナミドルウェア](#コンテナミドルウェア)
- [ルートでの使用](#ルートでの使用)
  - [基本パターン](#基本パターン)
  - [ヘルパー関数で null チェックを共通化](#ヘルパー関数で-null-チェックを共通化)
- [Repository 実装](#repository-実装)
  - [Repository Interface (Domain層)](#repository-interface-domain層)
  - [D1 Repository (Infrastructure層)](#d1-repository-infrastructure層)
  - [InMemory Repository (テスト用)](#inmemory-repository-テスト用)
- [テストでの活用](#テストでの活用)
  - [InMemory Repository を使った統合テスト](#inmemory-repository-を使った統合テスト)
- [複数データソース対応](#複数データソース対応)
  - [複数 DB / 外部API の組み合わせ](#複数-db-外部api-の組み合わせ)
- [設計原則](#設計原則)

## 概要

Hono アプリケーションにおける依存性注入 (DI) パターン。Hono の Context Variables を活用し、ミドルウェアで Repository をリクエストスコープに注入する。外部DIライブラリを使わない軽量な実装。

## アーキテクチャ

```
リクエスト
  → containerMiddleware (Repository 生成・注入)
    → ルートハンドラ (c.var.repositories から取得)
      → UseCase (Repository をコンストラクタ注入)
        → Repository 実装 (D1 / InMemory)
```

## 型定義

### Repositories 型

```typescript
// infrastructure/container.ts
import type { ItemRepository } from "@/domain/repositories/ItemRepository";
import type { UserRepository } from "@/domain/repositories/UserRepository";
import type { FavoriteRepository } from "@/domain/repositories/FavoriteRepository";

export type Repositories = {
  itemRepository: ItemRepository;
  userRepository: UserRepository | null;
  favoriteRepository: FavoriteRepository | null;
};
```

### AppEnv 型

```typescript
// presentation/types/env.ts
import type { Repositories } from "@/infrastructure/container";

type Bindings = {
  DB?: D1Database;
  KV?: KVNamespace;
  CORS_ORIGIN?: string;
};

type Variables = {
  repositories: Repositories;
  currentUser?: User | null;
};

export type AppEnv = {
  Bindings: Bindings;
  Variables: Variables;
};
```

## コンテナ生成関数

### 基本パターン

```typescript
// infrastructure/container.ts
import { D1ItemRepository } from "./repositories/d1/D1ItemRepository";
import { D1UserRepository } from "./repositories/d1/D1UserRepository";
import { D1FavoriteRepository } from "./repositories/d1/D1FavoriteRepository";
import { InMemoryItemRepository } from "./repositories/in-memory/InMemoryItemRepository";

export const createRepositories = (db: D1Database | undefined): Repositories => {
  // DB が利用可能な場合: D1 Repository を返す
  if (db) {
    return {
      itemRepository: new D1ItemRepository(db),
      userRepository: new D1UserRepository(db),
      favoriteRepository: new D1FavoriteRepository(db),
    };
  }

  // DB 未設定の場合: InMemory Repository (一部 null)
  return {
    itemRepository: new InMemoryItemRepository(),
    userRepository: null,
    favoriteRepository: null,
  };
};
```

### シングルトン対応

InMemory Repository をリクエスト間で共有する場合:

```typescript
let cachedInMemoryRepo: InMemoryItemRepository | null = null;

export const createRepositories = (db: D1Database | undefined): Repositories => {
  if (db) {
    return {
      itemRepository: new D1ItemRepository(db),
      userRepository: new D1UserRepository(db),
      favoriteRepository: new D1FavoriteRepository(db),
    };
  }

  if (!cachedInMemoryRepo) {
    cachedInMemoryRepo = new InMemoryItemRepository();
  }

  return {
    itemRepository: cachedInMemoryRepo,
    userRepository: null,
    favoriteRepository: null,
  };
};
```

## コンテナミドルウェア

```typescript
// presentation/http/middlewares/container.ts
import type { MiddlewareHandler } from "hono";
import type { AppEnv } from "@/presentation/types/env";
import { createRepositories } from "@/infrastructure/container";

export const containerMiddleware: MiddlewareHandler<AppEnv> = async (c, next) => {
  const db = c.env?.DB;
  c.set("repositories", createRepositories(db));
  await next();
};
```

## ルートでの使用

### 基本パターン

```typescript
export const usersRoute = new Hono<AppEnv>()
  .get("/", zValidator("query", ListQuerySchema), async (c) => {
    const { limit, offset } = c.req.valid("query");
    const { userRepository, favoriteRepository } = c.var.repositories;

    // null チェック (DB 未設定の場合)
    if (!userRepository || !favoriteRepository) {
      throw new DatabaseNotConfiguredError();
    }

    // UseCase にコンストラクタ注入
    const usecase = new GetUsersUsecase(userRepository, favoriteRepository);
    const result = await usecase.execute({ limit, offset });

    return c.json(toGetUsersResponse(result.users, result.total));
  });
```

### ヘルパー関数で null チェックを共通化

```typescript
function getRequiredRepo<T>(repo: T | null, name: string): T {
  if (!repo) throw new DatabaseNotConfiguredError(`${name} is not configured`);
  return repo;
}

// 使用例
const userRepo = getRequiredRepo(c.var.repositories.userRepository, "UserRepository");
const usecase = new CreateUserUsecase(userRepo);
```

## Repository 実装

### Repository Interface (Domain層)

```typescript
// domain/repositories/UserRepository.ts
export interface UserRepository {
  findById(id: string): Promise<User | null>;
  findAll(params: { limit: number; offset: number }): Promise<{ items: User[]; total: number }>;
  save(user: User): Promise<void>;
  delete(id: string): Promise<void>;
}
```

### D1 Repository (Infrastructure層)

```typescript
// infrastructure/repositories/d1/D1UserRepository.ts
import { drizzle, type DrizzleD1Database } from "drizzle-orm/d1";
import { eq, desc, count } from "drizzle-orm";
import * as schema from "@/infrastructure/database/schema";

export class D1UserRepository implements UserRepository {
  private readonly db: DrizzleD1Database<typeof schema>;

  constructor(d1Database: D1Database) {
    this.db = drizzle(d1Database, { schema });
  }

  async findById(id: string): Promise<User | null> {
    const row = await this.db
      .select()
      .from(schema.users)
      .where(eq(schema.users.id, id))
      .get();
    return row ? this.toEntity(row) : null;
  }

  async findAll(params: { limit: number; offset: number }) {
    const [rows, countResult] = await this.db.batch([
      this.db.select().from(schema.users)
        .orderBy(desc(schema.users.createdAt))
        .limit(params.limit).offset(params.offset),
      this.db.select({ count: count() }).from(schema.users),
    ]);
    return {
      items: rows.map((r) => this.toEntity(r)),
      total: countResult[0]?.count ?? 0,
    };
  }

  async save(user: User): Promise<void> {
    await this.db.insert(schema.users).values({
      id: user.id,
      nickname: user.nickname,
      createdAt: user.createdAt.toISOString(),
    }).run();
  }

  async delete(id: string): Promise<void> {
    await this.db.delete(schema.users).where(eq(schema.users.id, id)).run();
  }

  private toEntity(row: typeof schema.users.$inferSelect): User {
    return reconstituteUser({
      id: row.id,
      nickname: row.nickname,
      createdAt: new Date(row.createdAt),
    });
  }
}
```

### InMemory Repository (テスト用)

```typescript
// infrastructure/repositories/in-memory/InMemoryUserRepository.ts
export class InMemoryUserRepository implements UserRepository {
  private store: Map<string, User> = new Map();

  async findById(id: string): Promise<User | null> {
    return this.store.get(id) ?? null;
  }

  async findAll(params: { limit: number; offset: number }) {
    const all = Array.from(this.store.values());
    return {
      items: all.slice(params.offset, params.offset + params.limit),
      total: all.length,
    };
  }

  async save(user: User): Promise<void> {
    this.store.set(user.id, user);
  }

  async delete(id: string): Promise<void> {
    this.store.delete(id);
  }

  // テスト用ヘルパー
  reset(): void {
    this.store.clear();
  }

  seed(users: User[]): void {
    for (const user of users) {
      this.store.set(user.id, user);
    }
  }
}
```

## テストでの活用

### InMemory Repository を使った統合テスト

```typescript
import { testClient } from "hono/testing";

describe("Users API", () => {
  const inMemoryUserRepo = new InMemoryUserRepository();
  const inMemoryFavoriteRepo = new InMemoryFavoriteRepository();

  // テスト用コンテナミドルウェアを差し替え
  const testContainerMiddleware: MiddlewareHandler<AppEnv> = async (c, next) => {
    c.set("repositories", {
      itemRepository: new InMemoryItemRepository(),
      userRepository: inMemoryUserRepo,
      favoriteRepository: inMemoryFavoriteRepo,
    });
    await next();
  };

  const app = new Hono<AppEnv>()
    .use("*", testContainerMiddleware)
    .route("/users", usersRoute);

  beforeEach(() => {
    inMemoryUserRepo.reset();
    inMemoryFavoriteRepo.reset();
  });

  it("should create a user", async () => {
    const res = await testClient(app).users.$post({
      json: { nickname: "testuser" },
    });
    expect(res.status).toBe(201);
    const body = await res.json();
    expect(body.nickname).toBe("testuser");
  });
});
```

## 複数データソース対応

### 複数 DB / 外部API の組み合わせ

```typescript
export type Repositories = {
  userRepository: UserRepository;
  itemRepository: ItemRepository;
  notificationService: NotificationService; // 外部API
};

export const createRepositories = (env: Bindings): Repositories => ({
  userRepository: new D1UserRepository(env.DB),
  itemRepository: new D1ItemRepository(env.DB),
  notificationService: new HttpNotificationService(env.NOTIFICATION_API_URL, env.NOTIFICATION_API_KEY),
});
```

## 設計原則

1. **Repository Interface は Domain層**: フレームワーク非依存
2. **実装は Infrastructure層**: D1/Drizzle/外部API 等の具体的実装
3. **注入はミドルウェア**: リクエストスコープでコンテナを生成
4. **UseCase はコンストラクタ注入**: テスト時にモック/InMemory に差し替え可能
5. **null チェックは Presentation層**: DB 未設定時のガード
