# React コンポーネントテスト詳細

Vitest + React Testing Library によるコンポーネントテストの実践パターン。

## 目次

- [セットアップ](#セットアップ)
  - [必要なパッケージ](#必要なパッケージ)
  - [Vitest 設定](#vitest-設定)
  - [セットアップファイル](#セットアップファイル)
- [クエリの優先順位](#クエリの優先順位)
- [基本パターン](#基本パターン)
  - [レンダリングとテキスト検証](#レンダリングとテキスト検証)
  - [ユーザーインタラクション](#ユーザーインタラクション)
  - [条件付きレンダリング](#条件付きレンダリング)
  - [リスト表示](#リスト表示)
- [非同期テスト](#非同期テスト)
  - [データフェッチ](#データフェッチ)
  - [waitFor でポーリング検証](#waitfor-でポーリング検証)
  - [findBy で非同期要素を検索](#findby-で非同期要素を検索)
- [Hooks テスト](#hooks-テスト)
  - [renderHook](#renderhook)
  - [非同期 Hook](#非同期-hook)
  - [Wrapper でコンテキストを提供](#wrapper-でコンテキストを提供)
- [コンテキスト/プロバイダーのテスト](#コンテキストプロバイダーのテスト)
  - [カスタムレンダー](#カスタムレンダー)
- [React Router のテスト](#react-router-のテスト)
- [フォームのテスト](#フォームのテスト)
  - [React Hook Form](#react-hook-form)
  - [セレクトボックス](#セレクトボックス)
- [アクセシビリティテスト](#アクセシビリティテスト)
  - [axe-core 連携](#axe-core-連携)
- [アンチパターン](#アンチパターン)
  - [1. 実装の詳細をテストしない](#1-実装の詳細をテストしない)
  - [2. container.querySelector を避ける](#2-containerqueryselector-を避ける)
  - [3. snapshot の濫用を避ける](#3-snapshot-の濫用を避ける)
  - [4. act 警告を無視しない](#4-act-警告を無視しない)
- [デバッグ](#デバッグ)

## セットアップ

### 必要なパッケージ

```bash
npm install -D @testing-library/react @testing-library/jest-dom @testing-library/user-event happy-dom
```

### Vitest 設定

```typescript
// vitest.config.ts
import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  test: {
    environment: "happy-dom",
    setupFiles: ["./test/setup-react.ts"],
    css: false, // CSS のパースをスキップ
  },
});
```

### セットアップファイル

```typescript
// test/setup-react.ts
import "@testing-library/jest-dom/vitest";

// グローバルクリーンアップ
afterEach(() => {
  vi.restoreAllMocks();
});
```

## クエリの優先順位

Testing Library が推奨するクエリの優先順位:

1. **`getByRole`** - アクセシビリティに基づく（最優先）
2. **`getByLabelText`** - フォーム要素
3. **`getByPlaceholderText`** - プレースホルダー
4. **`getByText`** - テキストコンテンツ
5. **`getByDisplayValue`** - フォームの現在値
6. **`getByAltText`** - 画像の alt
7. **`getByTitle`** - title 属性
8. **`getByTestId`** - 最終手段（data-testid）

```typescript
// GOOD: セマンティックなクエリ
screen.getByRole("button", { name: "送信" });
screen.getByRole("textbox", { name: "メールアドレス" });
screen.getByRole("heading", { level: 2 });

// AVOID: testid は最終手段
screen.getByTestId("submit-button");
```

## 基本パターン

### レンダリングとテキスト検証

```typescript
import { render, screen } from "@testing-library/react";

it("タイトルを表示する", () => {
  render(<Header title="Hello" />);
  expect(screen.getByRole("heading", { name: "Hello" })).toBeInTheDocument();
});
```

### ユーザーインタラクション

```typescript
import userEvent from "@testing-library/user-event";

it("フォーム送信が動作する", async () => {
  const user = userEvent.setup();
  const onSubmit = vi.fn();

  render(<LoginForm onSubmit={onSubmit} />);

  await user.type(screen.getByRole("textbox", { name: "メール" }), "a@b.com");
  await user.type(screen.getByLabelText("パスワード"), "pass123");
  await user.click(screen.getByRole("button", { name: "ログイン" }));

  expect(onSubmit).toHaveBeenCalledWith({
    email: "a@b.com",
    password: "pass123",
  });
});
```

**注意:** `fireEvent` ではなく `userEvent` を使う。`userEvent` は実際のユーザー操作（focus → keydown → input → keyup）を再現する。

### 条件付きレンダリング

```typescript
it("管理者にだけ削除ボタンを表示する", () => {
  const { rerender } = render(<UserCard user={user} role="viewer" />);
  expect(screen.queryByRole("button", { name: "削除" })).not.toBeInTheDocument();

  rerender(<UserCard user={user} role="admin" />);
  expect(screen.getByRole("button", { name: "削除" })).toBeInTheDocument();
});
```

### リスト表示

```typescript
it("ユーザー一覧を表示する", () => {
  const users = [
    { id: "1", name: "Alice" },
    { id: "2", name: "Bob" },
  ];

  render(<UserList users={users} />);

  const items = screen.getAllByRole("listitem");
  expect(items).toHaveLength(2);
  expect(items[0]).toHaveTextContent("Alice");
});
```

## 非同期テスト

### データフェッチ

```typescript
it("ユーザーデータを取得して表示する", async () => {
  render(<UserProfile userId="1" />);

  // ローディング状態
  expect(screen.getByText("読み込み中...")).toBeInTheDocument();

  // データ表示を待つ
  expect(await screen.findByText("Alice")).toBeInTheDocument();

  // ローディングが消えている
  expect(screen.queryByText("読み込み中...")).not.toBeInTheDocument();
});
```

### waitFor でポーリング検証

```typescript
import { waitFor } from "@testing-library/react";

it("バリデーションエラーを表示する", async () => {
  const user = userEvent.setup();
  render(<Form />);

  await user.click(screen.getByRole("button", { name: "送信" }));

  await waitFor(() => {
    expect(screen.getByRole("alert")).toHaveTextContent("入力必須です");
  });
});
```

### findBy で非同期要素を検索

```typescript
// findBy = getBy + waitFor のショートハンド
const element = await screen.findByText("完了", {}, { timeout: 3000 });
```

## Hooks テスト

### renderHook

```typescript
import { renderHook, act } from "@testing-library/react";

it("useCounter が正しく動作する", () => {
  const { result } = renderHook(() => useCounter(0));

  expect(result.current.count).toBe(0);

  act(() => {
    result.current.increment();
  });

  expect(result.current.count).toBe(1);
});
```

### 非同期 Hook

```typescript
it("useUser がデータを取得する", async () => {
  const { result } = renderHook(() => useUser("1"));

  expect(result.current.isLoading).toBe(true);

  await waitFor(() => {
    expect(result.current.isLoading).toBe(false);
  });

  expect(result.current.data).toEqual({ id: "1", name: "Alice" });
});
```

### Wrapper でコンテキストを提供

```typescript
const wrapper = ({ children }: { children: React.ReactNode }) => (
  <QueryClientProvider client={new QueryClient()}>
    <AuthProvider>{children}</AuthProvider>
  </QueryClientProvider>
);

const { result } = renderHook(() => useAuth(), { wrapper });
```

## コンテキスト/プロバイダーのテスト

### カスタムレンダー

```typescript
// test/helpers/render.tsx
import { render, type RenderOptions } from "@testing-library/react";

type Props = {
  children: React.ReactNode;
};

function AllProviders({ children }: Props) {
  return (
    <ThemeProvider theme="light">
      <AuthProvider>
        {children}
      </AuthProvider>
    </ThemeProvider>
  );
}

export function renderWithProviders(
  ui: React.ReactElement,
  options?: Omit<RenderOptions, "wrapper">
) {
  return render(ui, { wrapper: AllProviders, ...options });
}
```

```typescript
// テストで使用
import { renderWithProviders } from "../test/helpers/render";

it("テーマが適用される", () => {
  renderWithProviders(<ThemedButton />);
  // ...
});
```

## React Router のテスト

```typescript
import { MemoryRouter, Route, Routes } from "react-router-dom";

it("ユーザー詳細ページを表示する", async () => {
  render(
    <MemoryRouter initialEntries={["/users/1"]}>
      <Routes>
        <Route path="/users/:id" element={<UserDetail />} />
      </Routes>
    </MemoryRouter>
  );

  expect(await screen.findByText("Alice")).toBeInTheDocument();
});
```

## フォームのテスト

### React Hook Form

```typescript
it("バリデーションエラーを表示する", async () => {
  const user = userEvent.setup();
  render(<RegistrationForm />);

  // 空のまま送信
  await user.click(screen.getByRole("button", { name: "登録" }));

  expect(await screen.findByText("名前は必須です")).toBeInTheDocument();
  expect(await screen.findByText("メールアドレスは必須です")).toBeInTheDocument();
});

it("正常に送信できる", async () => {
  const user = userEvent.setup();
  const onSuccess = vi.fn();
  render(<RegistrationForm onSuccess={onSuccess} />);

  await user.type(screen.getByRole("textbox", { name: "名前" }), "Alice");
  await user.type(screen.getByRole("textbox", { name: "メール" }), "a@b.com");
  await user.click(screen.getByRole("button", { name: "登録" }));

  await waitFor(() => {
    expect(onSuccess).toHaveBeenCalled();
  });
});
```

### セレクトボックス

```typescript
it("選択肢を選べる", async () => {
  const user = userEvent.setup();
  render(<SelectForm />);

  await user.selectOptions(
    screen.getByRole("combobox", { name: "都道府県" }),
    "東京都"
  );

  expect(screen.getByRole("combobox", { name: "都道府県" })).toHaveValue("tokyo");
});
```

## アクセシビリティテスト

### axe-core 連携

```typescript
import { axe, toHaveNoViolations } from "jest-axe";

expect.extend(toHaveNoViolations);

it("アクセシビリティ違反がない", async () => {
  const { container } = render(<Navigation />);
  const results = await axe(container);
  expect(results).toHaveNoViolations();
});
```

## アンチパターン

### 1. 実装の詳細をテストしない

```typescript
// BAD: state を直接検証
expect(component.state.isOpen).toBe(true);

// GOOD: ユーザーから見える結果を検証
expect(screen.getByRole("dialog")).toBeVisible();
```

### 2. container.querySelector を避ける

```typescript
// BAD: CSS セレクタに依存
const btn = container.querySelector(".btn-primary");

// GOOD: セマンティッククエリ
const btn = screen.getByRole("button", { name: "送信" });
```

### 3. snapshot の濫用を避ける

```typescript
// BAD: コンポーネント全体のスナップショット（変更に弱い）
expect(container).toMatchSnapshot();

// GOOD: 特定の出力を検証
expect(screen.getByRole("heading")).toHaveTextContent("タイトル");
```

### 4. act 警告を無視しない

`act(...)` 警告が出た場合は、非同期更新を正しくハンドリングする:

```typescript
// findBy, waitFor, userEvent は内部で act を使うので通常は不要
// 手動で状態更新する場合のみ act を使う
```

## デバッグ

```typescript
// 現在の DOM を出力
screen.debug();

// 特定要素の DOM を出力
screen.debug(screen.getByRole("form"));

// logRoles で利用可能なロールを確認
import { logRoles } from "@testing-library/react";
const { container } = render(<MyComponent />);
logRoles(container);
```
