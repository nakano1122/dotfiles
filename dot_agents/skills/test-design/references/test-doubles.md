# テストダブル (Test Doubles)

## 目次

- [概要](#概要)
  - [本番コード → テストダブル 対応表](#本番コード--テストダブル-対応表)
- [Stub](#stub)
  - [目的](#目的)
  - [使用場面](#使用場面)
  - [擬似コード例](#擬似コード例)
- [Mock](#mock)
  - [目的](#目的)
  - [使用場面](#使用場面)
  - [擬似コード例](#擬似コード例)
  - [注意点: 実装詳細への依存](#注意点-実装詳細への依存)
- [Fake](#fake)
  - [目的](#目的)
  - [使用場面](#使用場面)
  - [擬似コード例: InMemoryRepository](#擬似コード例-inmemoryrepository)
  - [利点](#利点)
- [Spy](#spy)
  - [目的](#目的)
  - [使用場面](#使用場面)
  - [擬似コード例](#擬似コード例)
- [テストダブル選択フローチャート](#テストダブル選択フローチャート)
- [アンチパターン](#アンチパターン)
  - [1. 過度なモック (Excessive Mocking)](#1-過度なモック-excessive-mocking)
  - [2. 実装詳細への依存 (Testing Implementation Details)](#2-実装詳細への依存-testing-implementation-details)
- [ベストプラクティス](#ベストプラクティス)
  - [1. 境界でのみテストダブルを使用する](#1-境界でのみテストダブルを使用する)
  - [2. Fake を優先する](#2-fake-を優先する)
  - [3. Mock は最小限にする](#3-mock-は最小限にする)
  - [4. Stub はシンプルに保つ](#4-stub-はシンプルに保つ)
  - [5. テストダブルと本番実装のインターフェースを一致させる](#5-テストダブルと本番実装のインターフェースを一致させる)

## 概要

テストダブルとは、テスト対象が依存する外部コンポーネントを置き換えるオブジェクトの総称である。
本番コードの依存を制御可能にし、テストの独立性・速度・再現性を確保する。

### 本番コード → テストダブル 対応表

| 本番コード | テストダブル | 主な用途 |
|---|---|---|
| 外部 API クライアント | Stub / Mock | 固定レスポンスの返却、呼び出し検証 |
| データベースリポジトリ | Fake (InMemory) | 軽量な代替実装による結合テスト |
| メール送信サービス | Mock / Spy | 送信の呼び出し検証 |
| ファイルシステム | Fake (InMemory) | メモリ上での読み書き |
| 時刻プロバイダ | Stub | 固定時刻の返却 |
| 乱数生成器 | Stub | 固定値の返却 |
| ロガー | Spy | ログ出力の記録・検証 |

---

## Stub

### 目的

テスト対象が依存するコンポーネントから**固定の値を返す**ことで、テスト対象の振る舞いを制御する。
Stub は「入力の制御」に特化しており、呼び出されたかどうかの検証は行わない。

### 使用場面

- 外部 API のレスポンスを固定したい
- 時刻や乱数など非決定的な値を固定したい
- 依存先の異常系（エラー、タイムアウト）を再現したい

### 擬似コード例

```
// インターフェース
interface PriceCalculator {
  getTaxRate(region: string): number
}

// Stub 実装
class StubPriceCalculator implements PriceCalculator {
  getTaxRate(region: string): number {
    return 0.10  // 常に10%を返す
  }
}

// テスト
test("税込価格が正しく計算される") {
  calculator = new StubPriceCalculator()
  order = new OrderService(calculator)

  result = order.calculateTotal("jp", 1000)

  expect(result).toBe(1100)
}
```

```
// 異常系の Stub
class ErrorStubPriceCalculator implements PriceCalculator {
  getTaxRate(region: string): number {
    throw new ServiceUnavailableError("税率サービスが応答しません")
  }
}

test("税率サービスがダウンした場合、フォールバック税率が使われる") {
  calculator = new ErrorStubPriceCalculator()
  order = new OrderService(calculator)

  result = order.calculateTotal("jp", 1000)

  expect(result).toBe(1080)  // フォールバック税率8%
}
```

---

## Mock

### 目的

テスト対象が依存コンポーネントを**正しく呼び出したか**を検証する。
Mock は「出力の検証」に特化しており、呼び出し回数・引数・順序を確認できる。

### 使用場面

- メール送信や通知など、副作用が正しく発生したかを確認したい
- 特定の引数で外部サービスが呼ばれたことを保証したい
- 呼び出し順序が重要な処理を検証したい

### 擬似コード例

```
// インターフェース
interface NotificationService {
  send(userId: string, message: string): void
}

// テスト（フレームワークの Mock 機能を使用）
test("注文完了時に通知が送信される") {
  notifier = mock(NotificationService)
  order = new OrderService(notifier)

  order.complete("user-123", orderDetails)

  // 呼び出しの検証
  expect(notifier.send).toHaveBeenCalledWith(
    "user-123",
    "ご注文が完了しました"
  )
  expect(notifier.send).toHaveBeenCalledTimes(1)
}
```

### 注意点: 実装詳細への依存

Mock は強力だが、テスト対象の**内部実装に依存しやすい**という重大なリスクがある。

```
// NG: 実装詳細に依存した Mock 検証
test("ユーザー作成時にバリデーションが呼ばれる") {
  validator = mock(Validator)
  service = new UserService(validator)

  service.createUser(userData)

  // 内部でどのメソッドをどの順序で呼ぶかに依存している
  expect(validator.checkEmail).toHaveBeenCalledBefore(validator.checkName)
  expect(validator.normalize).toHaveBeenCalledTimes(3)
}
// → リファクタリングでテストが壊れる
```

```
// OK: 振る舞いに着目した検証
test("有効なデータでユーザーが作成される") {
  repository = new FakeUserRepository()
  service = new UserService(repository)

  service.createUser(userData)

  saved = repository.findByEmail("test@example.com")
  expect(saved).not.toBeNull()
  expect(saved.name).toBe("テスト太郎")
}
// → 内部実装が変わっても、結果が同じならテストは通る
```

---

## Fake

### 目的

本番実装の**簡易版**を提供する。Stub のように固定値を返すのではなく、実際にロジックを持つ軽量な代替実装である。

### 使用場面

- データベースの代わりにメモリ上のリポジトリを使いたい
- ファイルシステムの代わりにメモリ上のストレージを使いたい
- 外部サービスの振る舞いを簡易的に再現したい

### 擬似コード例: InMemoryRepository

```
// インターフェース
interface UserRepository {
  save(user: User): void
  findById(id: string): User | null
  findByEmail(email: string): User | null
  findAll(): User[]
  delete(id: string): void
}

// Fake 実装
class InMemoryUserRepository implements UserRepository {
  private store: Map<string, User> = new Map()

  save(user: User): void {
    this.store.set(user.id, user)
  }

  findById(id: string): User | null {
    return this.store.get(id) ?? null
  }

  findByEmail(email: string): User | null {
    for (user of this.store.values()) {
      if (user.email === email) return user
    }
    return null
  }

  findAll(): User[] {
    return Array.from(this.store.values())
  }

  delete(id: string): void {
    this.store.delete(id)
  }
}

// テスト
test("ユーザー登録後に検索できる") {
  repository = new InMemoryUserRepository()
  service = new UserService(repository)

  service.register("テスト太郎", "taro@example.com")

  found = repository.findByEmail("taro@example.com")
  expect(found).not.toBeNull()
  expect(found.name).toBe("テスト太郎")
}

test("重複メールアドレスでエラーになる") {
  repository = new InMemoryUserRepository()
  service = new UserService(repository)

  service.register("テスト太郎", "taro@example.com")

  expect(() => {
    service.register("テスト次郎", "taro@example.com")
  }).toThrow(DuplicateEmailError)
}
```

### 利点

- **本番と同じインターフェース**を実装するため、テストの信頼性が高い
- **状態を持つ**ため、CRUD 操作の一連のフローをテストできる
- **高速**であり、外部依存がない
- **リファクタリングに強い**: 内部実装ではなく振る舞いを検証するため、テストが壊れにくい
- **複数テストで再利用**しやすい

---

## Spy

### 目的

実際の処理を実行しつつ、**呼び出し履歴を記録**する。Mock と異なり、本来の処理も実行される点が特徴である。

### 使用場面

- ロガーの出力内容を検証したい（実際のログも出力する）
- イベントの発火回数を記録したい
- 本来の処理は妨げず、呼び出し情報だけ取得したい

### 擬似コード例

```
// インターフェース
interface Logger {
  log(level: string, message: string): void
}

// Spy 実装
class SpyLogger implements Logger {
  calls: Array<{ level: string, message: string }> = []

  log(level: string, message: string): void {
    this.calls.push({ level, message })
    // 必要なら実際のログ出力も行う
    console.log(`[${level}] ${message}`)
  }

  getCallCount(): number {
    return this.calls.length
  }

  getCallsWith(level: string): Array<{ level: string, message: string }> {
    return this.calls.filter(c => c.level === level)
  }
}

// テスト
test("エラー発生時に警告ログが出力される") {
  logger = new SpyLogger()
  service = new PaymentService(logger)

  service.process(invalidPayment)

  warnings = logger.getCallsWith("warn")
  expect(warnings).toHaveLength(1)
  expect(warnings[0].message).toContain("無効な支払い情報")
}
```

```
// フレームワークの spy 機能を使う場合
test("処理完了時にコールバックが呼ばれる") {
  callback = spy()
  processor = new BatchProcessor()

  processor.run(items, callback)

  expect(callback).toHaveBeenCalledTimes(items.length)
}
```

---

## テストダブル選択フローチャート

```
テストダブルが必要か？
│
├─ 依存先の戻り値を制御したいだけ
│  └─→ Stub を使う
│
├─ 依存先が正しく呼ばれたか検証したい
│  │
│  ├─ 呼び出し履歴の記録だけで十分
│  │  └─→ Spy を使う
│  │
│  └─ 引数・回数・順序を厳密に検証したい
│     └─→ Mock を使う（ただし最小限に）
│
└─ 依存先の振る舞いを簡易的に再現したい
   └─→ Fake を使う（推奨）
```

**判断の優先順位:**

1. **Fake が使えるなら Fake を使う** - 最もリファクタリングに強い
2. **Stub で済むなら Stub を使う** - シンプルで壊れにくい
3. **記録が必要なら Spy を使う** - 実処理を妨げない
4. **Mock は最後の手段** - 実装詳細への依存リスクがある

---

## アンチパターン

### 1. 過度なモック (Excessive Mocking)

すべての依存をモックに置き換えると、テストが実装詳細に強く結合し、リファクタリングのたびにテストが壊れる。

```
// NG: すべてをモック化
test("注文処理") {
  repo = mock(OrderRepository)
  validator = mock(OrderValidator)
  calculator = mock(PriceCalculator)
  notifier = mock(NotificationService)
  logger = mock(Logger)

  service = new OrderService(repo, validator, calculator, notifier, logger)

  when(validator.validate(order)).thenReturn(true)
  when(calculator.calculate(order)).thenReturn(1100)

  service.process(order)

  // 内部の呼び出し順序まで検証している
  verify(validator.validate).calledBefore(calculator.calculate)
  verify(calculator.calculate).calledBefore(repo.save)
  verify(repo.save).calledBefore(notifier.send)
  verify(logger.log).calledTimes(3)
}
// → 内部実装の変更でテストが即座に壊れる
```

### 2. 実装詳細への依存 (Testing Implementation Details)

テストが「何をするか」ではなく「どうやるか」を検証してしまう。

```
// NG: 内部メソッドの呼び出しを検証
test("キャッシュが有効に使われる") {
  cache = mock(Cache)
  service = new ProductService(cache)

  service.getProduct("prod-1")
  service.getProduct("prod-1")

  // キャッシュの内部実装に依存
  verify(cache.get).calledTimes(2)
  verify(cache.set).calledTimes(1)
}

// OK: 振る舞い（結果）を検証
test("同じ商品を2回取得しても結果が同じ") {
  repository = new FakeProductRepository()
  repository.save(product)
  service = new ProductService(repository)

  result1 = service.getProduct("prod-1")
  result2 = service.getProduct("prod-1")

  expect(result1).toEqual(result2)
}
```

---

## ベストプラクティス

### 1. 境界でのみテストダブルを使用する

テストダブルは、システムの**境界**（外部 API、データベース、ファイルシステム、時刻など）でのみ使用する。内部のクラス間の依存にはテストダブルを使わず、実際のオブジェクトを使う。

```
// NG: 内部クラスもすべてモック化
service = new OrderService(
  mock(OrderValidator),      // 内部ロジック → モック不要
  mock(PriceCalculator),     // 内部ロジック → モック不要
  mock(OrderRepository),     // 境界 → テストダブルが妥当
  mock(NotificationService)  // 境界 → テストダブルが妥当
)

// OK: 境界のみテストダブル、内部は実オブジェクト
service = new OrderService(
  new OrderValidator(),              // 実オブジェクト
  new PriceCalculator(),             // 実オブジェクト
  new InMemoryOrderRepository(),     // Fake（境界）
  mock(NotificationService)          // Mock（境界・副作用の検証）
)
```

### 2. Fake を優先する

リポジトリやストレージなど、状態を持つ依存には Fake を第一選択とする。Fake は本番と同じインターフェースを実装するため、テストの信頼性が最も高い。

### 3. Mock は最小限にする

Mock を使う場合は、検証する項目を必要最小限に絞る。呼び出し順序や回数の検証は、本当に仕様として重要な場合のみ行う。

```
// NG: 過剰な検証
verify(notifier.send).calledWith("user-1", any(), any())
verify(notifier.send).calledTimes(1)
verify(notifier.send).calledAfter(repo.save)

// OK: 本質的な検証のみ
verify(notifier.send).calledWith("user-1", expectedMessage)
```

### 4. Stub はシンプルに保つ

Stub にロジックを持たせない。条件分岐が必要になったら、それは Fake にすべきサインである。

```
// NG: Stub にロジックを持たせている
stub.getTaxRate = (region) => {
  if (region === "jp") return 0.10
  if (region === "us") return 0.08
  if (region === "eu") return 0.20
  throw new Error("unknown region")
}

// OK: テストケースごとに単純な Stub を使う
// テスト1: 日本の税率
stub.getTaxRate = () => 0.10

// テスト2: 米国の税率
stub.getTaxRate = () => 0.08
```

### 5. テストダブルと本番実装のインターフェースを一致させる

テストダブルは必ず本番コードと同じインターフェースを実装する。型チェックやコンパイル時検証で乖離を防ぐ。

```
// インターフェースを明示的に実装する
class InMemoryUserRepository implements UserRepository { ... }
class StubPriceCalculator implements PriceCalculator { ... }
// → インターフェースが変わればテストダブルもコンパイルエラーになる
```
