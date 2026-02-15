---
name: vitest-testing
description: "Vitest を使った TypeScript テストの包括的な実装ガイド。設定、テストの書き方、モック/スパイ/スタブ（vi.fn, vi.mock, vi.spyOn）、Reactコンポーネントテスト（Testing Library連携）、APIテスト（Hono testClient）、カバレッジ、スナップショットテスト、並列実行をカバー。Vitestでのユニットテスト・統合テスト実装時に使用。"
---

# Vitest Testing

Vitest を使った TypeScript テストの実装ガイド。ユニットテスト・統合テスト・コンポーネントテストの書き方、モック戦略、パフォーマンス最適化までカバーする。

## ワークフロー

```
テスト依頼を受ける
  ├─ テスト種別を判定
  │   ├─ ユニットテスト → 単一関数/クラスのテスト
  │   ├─ 統合テスト → 複数モジュール連携のテスト
  │   ├─ コンポーネントテスト → references/component-testing.md
  │   └─ API テスト → Hono testClient 連携
  ├─ モック戦略を決定 → references/mock-patterns.md
  ├─ テスト実装
  ├─ カバレッジ確認
  └─ レビューチェックリスト確認
```

**テスト種別の判定基準:**
- 純粋関数・ユーティリティ → ユニットテスト（モック最小限）
- DB/外部API連携 → 統合テスト（InMemory実装 or モック）
- UIコンポーネント → コンポーネントテスト（Testing Library）
- HTTPエンドポイント → APIテスト（testClient）

## Vitest 設定

### 基本設定 (vitest.config.ts)

```typescript
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
    environment: "node", // or "happy-dom" for React
    include: ["src/**/*.test.ts", "src/**/*.test.tsx"],
    coverage: {
      provider: "v8",
      reporter: ["text", "html", "lcov"],
      include: ["src/**/*.ts"],
      exclude: ["src/**/*.test.ts", "src/**/*.d.ts"],
    },
  },
});
```

### ワークスペース設定 (vitest.workspace.ts)

```typescript
import { defineWorkspace } from "vitest/config";

export default defineWorkspace([
  { test: { name: "unit", include: ["src/**/*.test.ts"], environment: "node" } },
  { test: { name: "component", include: ["src/**/*.test.tsx"], environment: "happy-dom", setupFiles: ["./test/setup-react.ts"] } },
]);
```

## テストの書き方

### 基本構造

```typescript
import { describe, it, expect, beforeEach } from "vitest";

describe("UserService", () => {
  let service: UserService;
  beforeEach(() => { service = new UserService(); });

  describe("findById", () => {
    it("存在するユーザーを返す", async () => {
      const user = await service.findById("1");
      expect(user).toEqual({ id: "1", name: "Alice" });
    });

    it("存在しない場合はnullを返す", async () => {
      expect(await service.findById("999")).toBeNull();
    });
  });
});
```

### 主要なマッチャー

```typescript
expect(value).toBe(1);                // 厳密等値 (===)
expect(obj).toEqual({ a: 1 });        // 深い等値
expect(obj).toStrictEqual({ a: 1 });   // 型まで厳密
expect(value).toBeTruthy();            // 真偽
expect(value).toBeNull();
expect(value).toBeDefined();
expect(value).toBeGreaterThan(3);
expect(str).toMatch(/pattern/);
expect(arr).toContain(item);
expect(arr).toHaveLength(3);
expect(() => fn()).toThrow(Error);
await expect(asyncFn()).resolves.toBe(value);
await expect(asyncFn()).rejects.toThrow(Error);
```

## モック/スパイ/スタブ

詳細は `references/mock-patterns.md` を参照。

### vi.fn() - 関数モック

```typescript
const mockFn = vi.fn();
mockFn.mockReturnValue(42);
mockFn.mockResolvedValue({ id: "1" });
mockFn.mockImplementation((x: number) => x * 2);

expect(mockFn).toHaveBeenCalledWith("arg");
expect(mockFn).toHaveBeenCalledTimes(1);
```

### vi.mock() - モジュールモック

```typescript
vi.mock("./userRepository", () => ({
  UserRepository: vi.fn().mockImplementation(() => ({
    findById: vi.fn().mockResolvedValue({ id: "1", name: "Alice" }),
  })),
}));
```

### vi.spyOn() - スパイ

```typescript
const spy = vi.spyOn(console, "log");
doSomething();
expect(spy).toHaveBeenCalledWith("expected message");
spy.mockRestore();
```

## React コンポーネントテスト

詳細は `references/component-testing.md` を参照。

### セットアップ (test/setup-react.ts)

```typescript
import "@testing-library/jest-dom/vitest";
```

### 基本パターン

```typescript
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

it("ボタンクリックでカウントが増える", async () => {
  const user = userEvent.setup();
  render(<Counter />);
  await user.click(screen.getByRole("button", { name: "increment" }));
  expect(screen.getByText("1")).toBeInTheDocument();
});
```

### 非同期コンポーネント

```typescript
it("データ取得後にユーザー名を表示する", async () => {
  render(<UserProfile userId="1" />);
  expect(screen.getByText("Loading...")).toBeInTheDocument();
  expect(await screen.findByText("Alice")).toBeInTheDocument();
});
```

## API テスト (Hono testClient)

### testClient セットアップ

```typescript
import { testClient } from "hono/testing";
import { app } from "./app";

describe("GET /api/users/:id", () => {
  const client = testClient(app);

  it("ユーザーを返す", async () => {
    const res = await client.api.users[":id"].$get({ param: { id: "1" } });
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ id: "1", name: "Alice" });
  });

  it("存在しない場合は404", async () => {
    const res = await client.api.users[":id"].$get({ param: { id: "999" } });
    expect(res.status).toBe(404);
  });
});
```

### リクエストボディ・ヘッダー付き

```typescript
it("ユーザーを作成する", async () => {
  const res = await client.api.users.$post({
    json: { name: "Bob", email: "bob@example.com" },
    header: { Authorization: "Bearer token" },
  });
  expect(res.status).toBe(201);
});
```

## カバレッジ設定と閾値

```typescript
// vitest.config.ts
export default defineConfig({
  test: {
    coverage: {
      provider: "v8",
      thresholds: { statements: 80, branches: 80, functions: 80, lines: 80 },
    },
  },
});
```

```bash
vitest run --coverage
```

## スナップショットテスト

```typescript
it("正しいHTMLを出力する", () => {
  const { container } = render(<Card title="Test" />);
  expect(container).toMatchSnapshot();
});

// インラインスナップショット
it("オブジェクト構造が正しい", () => {
  expect(buildConfig()).toMatchInlineSnapshot();
});
```

```bash
vitest run --update  # スナップショット更新
```

## 並列実行とパフォーマンス最適化

```typescript
// ファイル内のテストを並列化:
describe.concurrent("並列テスト", () => {
  it.concurrent("テスト1", async () => { /* ... */ });
  it.concurrent("テスト2", async () => { /* ... */ });
});

// 順序依存のテストを直列化:
describe.sequential("直列テスト", () => {
  it("ステップ1", () => { /* ... */ });
  it("ステップ2", () => { /* ... */ });
});
```

**最適化のポイント:**
- `--pool=forks` で隔離性を高める（デフォルトは `threads`）
- `--reporter=dot` でCI出力を簡潔にする
- `--bail=1` で最初の失敗で停止する
- 重いセットアップは `beforeAll` で一度だけ実行する

## レビューチェックリスト

- [ ] テスト名が「何を」「どういう条件で」「どうなるか」を表現している
- [ ] Arrange-Act-Assert パターンに従っている
- [ ] モックは必要最小限に留めている
- [ ] 非同期処理で `await` の漏れがない
- [ ] `afterEach` / `afterAll` でクリーンアップしている
- [ ] テストが他のテストに依存していない（独立している）
- [ ] エッジケース（null, 空配列, 境界値）をカバーしている
- [ ] スナップショットが意図的に使われている（濫用していない）

## リファレンス

- [Vitest 公式ドキュメント](https://vitest.dev/)
- [Testing Library](https://testing-library.com/)
- [Hono Testing](https://hono.dev/docs/guides/testing)
- `references/mock-patterns.md` - モックパターン詳細
- `references/component-testing.md` - React コンポーネントテスト詳細
