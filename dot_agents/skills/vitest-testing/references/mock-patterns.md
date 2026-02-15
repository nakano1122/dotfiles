# モックパターン詳細

Vitest におけるモック/スパイ/スタブの使い分けと実践パターン。

## 目次

- [vi.fn() / vi.mock() / vi.spyOn() の使い分け](#vifn--vimock--vispyon-の使い分け)
- [vi.fn() パターン](#vifn-パターン)
  - [基本的な関数モック](#基本的な関数モック)
  - [mockImplementation で動的な戻り値](#mockimplementation-で動的な戻り値)
  - [mockReturnValueOnce で呼び出し順制御](#mockreturnvalueonce-で呼び出し順制御)
  - [呼び出し検証](#呼び出し検証)
- [vi.mock() パターン](#vimock-パターン)
  - [モジュール全体のモック](#モジュール全体のモック)
  - [部分モック（一部だけ差し替え）](#部分モック一部だけ差し替え)
  - [テストごとにモック実装を変更](#テストごとにモック実装を変更)
  - [外部ライブラリのモック](#外部ライブラリのモック)
- [vi.spyOn() パターン](#vispyon-パターン)
  - [メソッドの監視](#メソッドの監視)
  - [戻り値のオーバーライド](#戻り値のオーバーライド)
  - [getter/setter のスパイ](#gettersetter-のスパイ)
- [InMemory Repository パターン](#inmemory-repository-パターン)
- [外部 API モック](#外部-api-モック)
  - [fetch のモック](#fetch-のモック)
  - [MSW (Mock Service Worker) 連携](#msw-mock-service-worker-連携)
- [タイマーモック](#タイマーモック)
- [モックのリセットとクリーンアップ](#モックのリセットとクリーンアップ)
- [アンチパターン](#アンチパターン)
  - [1. 実装の詳細をテストしない](#1-実装の詳細をテストしない)
  - [2. 過度なモックを避ける](#2-過度なモックを避ける)
  - [3. モックの戻り値を実際の型と一致させる](#3-モックの戻り値を実際の型と一致させる)

## vi.fn() / vi.mock() / vi.spyOn() の使い分け

| 手法 | 用途 | 適用場面 |
|------|------|----------|
| `vi.fn()` | 関数モック作成 | コールバック、DI で注入する依存 |
| `vi.mock()` | モジュール全体のモック | import している外部モジュール |
| `vi.spyOn()` | 既存メソッドの監視 | 実装を残しつつ呼び出しを検証 |

**選択基準:**
- 依存を DI で注入できる → `vi.fn()`
- import を差し替える必要がある → `vi.mock()`
- 実装はそのまま、呼び出しだけ検証 → `vi.spyOn()`

## vi.fn() パターン

### 基本的な関数モック

```typescript
const sendEmail = vi.fn();
sendEmail.mockResolvedValue({ success: true });

const service = new NotificationService(sendEmail);
await service.notifyUser("user-1");

expect(sendEmail).toHaveBeenCalledWith(
  expect.objectContaining({ to: "user@example.com" })
);
```

### mockImplementation で動的な戻り値

```typescript
const getPrice = vi.fn().mockImplementation((id: string) => {
  const prices: Record<string, number> = { "A": 100, "B": 200 };
  return prices[id] ?? 0;
});
```

### mockReturnValueOnce で呼び出し順制御

```typescript
const fetchData = vi.fn()
  .mockResolvedValueOnce({ page: 1, items: [1, 2] })
  .mockResolvedValueOnce({ page: 2, items: [3] })
  .mockResolvedValueOnce({ page: 3, items: [] });
```

### 呼び出し検証

```typescript
expect(mockFn).toHaveBeenCalled();
expect(mockFn).toHaveBeenCalledTimes(2);
expect(mockFn).toHaveBeenCalledWith("arg1", "arg2");
expect(mockFn).toHaveBeenNthCalledWith(1, "first-call-arg");
expect(mockFn).toHaveBeenLastCalledWith("last-arg");

// 呼び出し履歴の直接参照
expect(mockFn.mock.calls).toEqual([["arg1"], ["arg2"]]);
expect(mockFn.mock.results[0].value).toBe("return-value");
```

## vi.mock() パターン

### モジュール全体のモック

```typescript
import { fetchUser } from "./api";

vi.mock("./api", () => ({
  fetchUser: vi.fn().mockResolvedValue({ id: "1", name: "Alice" }),
}));

it("fetchUser がモックされている", async () => {
  const user = await fetchUser("1");
  expect(user.name).toBe("Alice");
});
```

### 部分モック（一部だけ差し替え）

```typescript
vi.mock("./utils", async (importOriginal) => {
  const original = await importOriginal<typeof import("./utils")>();
  return {
    ...original,
    generateId: vi.fn().mockReturnValue("fixed-id"),
  };
});
```

### テストごとにモック実装を変更

```typescript
import { getConfig } from "./config";

vi.mock("./config");

const mockGetConfig = vi.mocked(getConfig);

it("本番設定のテスト", () => {
  mockGetConfig.mockReturnValue({ env: "production", debug: false });
  // ...
});

it("開発設定のテスト", () => {
  mockGetConfig.mockReturnValue({ env: "development", debug: true });
  // ...
});
```

### 外部ライブラリのモック

```typescript
// node_modules のモジュール
vi.mock("@aws-sdk/client-s3", () => ({
  S3Client: vi.fn().mockImplementation(() => ({
    send: vi.fn().mockResolvedValue({ Body: "data" }),
  })),
  GetObjectCommand: vi.fn(),
}));
```

## vi.spyOn() パターン

### メソッドの監視

```typescript
const spy = vi.spyOn(userRepo, "save");
await service.createUser({ name: "Bob" });

expect(spy).toHaveBeenCalledWith(
  expect.objectContaining({ name: "Bob" })
);
spy.mockRestore(); // 元の実装に戻す
```

### 戻り値のオーバーライド

```typescript
vi.spyOn(Date, "now").mockReturnValue(1700000000000);
// Date.now() が固定値を返す

vi.spyOn(Math, "random").mockReturnValue(0.5);
```

### getter/setter のスパイ

```typescript
const spy = vi.spyOn(obj, "propName", "get").mockReturnValue("mocked");
expect(obj.propName).toBe("mocked");
```

## InMemory Repository パターン

テスト用のインメモリ実装で DB 依存を排除する。

```typescript
// src/repositories/userRepository.ts
export interface UserRepository {
  findById(id: string): Promise<User | null>;
  save(user: User): Promise<User>;
  delete(id: string): Promise<void>;
}

// test/helpers/inMemoryUserRepository.ts
export class InMemoryUserRepository implements UserRepository {
  private store = new Map<string, User>();

  async findById(id: string): Promise<User | null> {
    return this.store.get(id) ?? null;
  }

  async save(user: User): Promise<User> {
    this.store.set(user.id, user);
    return user;
  }

  async delete(id: string): Promise<void> {
    this.store.delete(id);
  }

  // テストヘルパー
  seed(users: User[]): void {
    for (const user of users) {
      this.store.set(user.id, user);
    }
  }

  clear(): void {
    this.store.clear();
  }
}
```

```typescript
// テストでの使用
describe("UserService", () => {
  let repo: InMemoryUserRepository;
  let service: UserService;

  beforeEach(() => {
    repo = new InMemoryUserRepository();
    service = new UserService(repo);
  });

  it("ユーザーを作成して保存する", async () => {
    const user = await service.createUser({ name: "Alice" });

    const saved = await repo.findById(user.id);
    expect(saved).toEqual(expect.objectContaining({ name: "Alice" }));
  });
});
```

## 外部 API モック

### fetch のモック

```typescript
const mockFetch = vi.fn();
vi.stubGlobal("fetch", mockFetch);

mockFetch.mockResolvedValue(
  new Response(JSON.stringify({ data: "value" }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  })
);

afterEach(() => {
  vi.unstubAllGlobals();
});
```

### MSW (Mock Service Worker) 連携

```typescript
import { setupServer } from "msw/node";
import { http, HttpResponse } from "msw";

const server = setupServer(
  http.get("https://api.example.com/users/:id", ({ params }) => {
    return HttpResponse.json({ id: params.id, name: "Alice" });
  }),
  http.post("https://api.example.com/users", async ({ request }) => {
    const body = await request.json();
    return HttpResponse.json(body, { status: 201 });
  })
);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

// テストごとにハンドラーを上書き
it("エラーレスポンスを処理する", async () => {
  server.use(
    http.get("https://api.example.com/users/:id", () => {
      return HttpResponse.json({ error: "Not Found" }, { status: 404 });
    })
  );
  // ...
});
```

## タイマーモック

```typescript
beforeEach(() => {
  vi.useFakeTimers();
});

afterEach(() => {
  vi.useRealTimers();
});

it("デバウンスが正しく動作する", async () => {
  const callback = vi.fn();
  const debounced = debounce(callback, 300);

  debounced();
  debounced();
  debounced();

  expect(callback).not.toHaveBeenCalled();

  vi.advanceTimersByTime(300);
  expect(callback).toHaveBeenCalledTimes(1);
});

it("setInterval のテスト", () => {
  const fn = vi.fn();
  setInterval(fn, 1000);

  vi.advanceTimersByTime(3000);
  expect(fn).toHaveBeenCalledTimes(3);
});
```

## モックのリセットとクリーンアップ

```typescript
afterEach(() => {
  vi.restoreAllMocks();  // spyOn を元に戻す + mock をリセット
});

// 各リセットメソッドの違い:
// vi.clearAllMocks()   → 呼び出し履歴のみクリア
// vi.resetAllMocks()   → 履歴 + 実装をクリア
// vi.restoreAllMocks() → 履歴 + 実装 + 元の実装を復元
```

## アンチパターン

### 1. 実装の詳細をテストしない

```typescript
// BAD: 内部実装に依存
expect(mockFn.mock.calls[0][0].headers["X-Internal"]).toBe("true");

// GOOD: 振る舞いを検証
expect(result).toEqual(expectedOutput);
```

### 2. 過度なモックを避ける

```typescript
// BAD: 全てモック（何もテストしていない）
vi.mock("./a");
vi.mock("./b");
vi.mock("./c");

// GOOD: テスト対象の境界だけモック
// 内部ロジックは実際のコードを使い、外部依存だけモック
```

### 3. モックの戻り値を実際の型と一致させる

```typescript
// BAD: 不完全なモック
mockFn.mockResolvedValue({ id: "1" }); // name が足りない

// GOOD: 型に準拠
mockFn.mockResolvedValue({ id: "1", name: "Alice", createdAt: new Date() });
```
