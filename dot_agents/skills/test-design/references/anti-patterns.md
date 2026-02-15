# テストのアンチパターン

テストコードで頻出するアンチパターンと、その解決策を整理する。
各パターンについて、問題の説明・NG 例・OK 例を示す。

---

## 目次

- [1. テストの相互依存](#1-テストの相互依存)
  - [問題説明](#問題説明)
  - [NG 例](#ng-例)
  - [OK 例](#ok-例)
- [2. 過度なモック](#2-過度なモック)
  - [問題説明](#問題説明)
  - [NG 例](#ng-例)
  - [OK 例](#ok-例)
- [3. 巨大なテスト](#3-巨大なテスト)
  - [問題説明](#問題説明)
  - [NG 例](#ng-例)
  - [OK 例](#ok-例)
- [4. マジックナンバー](#4-マジックナンバー)
  - [問題説明](#問題説明)
  - [NG 例](#ng-例)
  - [OK 例](#ok-例)
- [5. テストの重複](#5-テストの重複)
  - [問題説明](#問題説明)
  - [NG 例](#ng-例)
  - [OK 例](#ok-例)
- [6. 脆いアサーション](#6-脆いアサーション)
  - [問題説明](#問題説明)
  - [NG 例](#ng-例)
  - [OK 例](#ok-例)
- [7. 条件分岐のあるテスト](#7-条件分岐のあるテスト)
  - [問題説明](#問題説明)
  - [NG 例](#ng-例)
  - [OK 例](#ok-例)
- [8. 非決定的テスト](#8-非決定的テスト)
  - [問題説明](#問題説明)
  - [NG 例](#ng-例)
  - [OK 例](#ok-例)
- [9. コメントアウトされたテスト](#9-コメントアウトされたテスト)
  - [問題説明](#問題説明)
  - [NG 例](#ng-例)
  - [OK 例](#ok-例)
- [10. アサーションなし](#10-アサーションなし)
  - [問題説明](#問題説明)
  - [NG 例](#ng-例)
  - [OK 例](#ok-例)
- [11. テストのテスト不足](#11-テストのテスト不足)
  - [問題説明](#問題説明)
  - [NG 例](#ng-例)
  - [OK 例](#ok-例)
- [12. スリープ依存](#12-スリープ依存)
  - [問題説明](#問題説明)
  - [NG 例](#ng-例)
  - [OK 例](#ok-例)

## 1. テストの相互依存

### 問題説明

テスト同士がグローバル状態やクラス変数を共有しており、実行順序によって結果が変わる。
あるテストが別のテストの前提条件に依存しているため、単独実行すると失敗する。

### NG 例

```
// グローバル状態を共有し、テスト間で副作用が残る
let userCount = 0

test("ユーザーを追加する") {
  userCount += 1
  expect(userCount).toBe(1)
}

test("ユーザー数を確認する") {
  // 前のテストが先に実行されていることを前提としている
  expect(userCount).toBe(1)
}

test("ユーザーをさらに追加する") {
  userCount += 1
  // 前の2テストが実行済みであることを前提としている
  expect(userCount).toBe(2)
}
```

### OK 例

```
// 各テストで状態を初期化し、独立性を保つ
let userCount: number

beforeEach(() => {
  userCount = 0
})

test("ユーザーを追加すると数が1になる") {
  userCount += 1
  expect(userCount).toBe(1)
}

test("ユーザーを2人追加すると数が2になる") {
  userCount += 1
  userCount += 1
  expect(userCount).toBe(2)
}

test("初期状態ではユーザー数が0である") {
  expect(userCount).toBe(0)
}
```

---

## 2. 過度なモック

### 問題説明

テスト対象の依存をすべてモックに置き換えてしまい、テストが実装の内部構造に強く結合する。
リファクタリングでメソッドの呼び出し順序や内部構造を変更しただけでテストが壊れる。
テストが「何を達成するか」ではなく「どう実装されているか」を検証してしまっている。

### NG 例

```
// すべての依存をモック化し、内部の呼び出し詳細を検証
test("注文を処理する") {
  repo = mock(OrderRepository)
  validator = mock(OrderValidator)
  calculator = mock(PriceCalculator)
  notifier = mock(NotificationService)
  logger = mock(Logger)

  service = new OrderService(repo, validator, calculator, notifier, logger)

  when(validator.validate(order)).thenReturn(true)
  when(calculator.calculate(order)).thenReturn(1100)

  service.process(order)

  // 呼び出し順序まで検証 → 実装詳細への依存
  verify(validator.validate).calledBefore(calculator.calculate)
  verify(calculator.calculate).calledBefore(repo.save)
  verify(repo.save).calledBefore(notifier.send)
  verify(logger.log).calledTimes(3)
}
```

### OK 例

```
// 境界のみテストダブルを使い、結果を検証する
test("注文を処理すると保存され通知が送られる") {
  repo = new InMemoryOrderRepository()
  notifier = mock(NotificationService)

  // 内部ロジック（validator, calculator）は実オブジェクトを使う
  service = new OrderService(
    repo,
    new OrderValidator(),
    new PriceCalculator(),
    notifier,
    new ConsoleLogger()
  )

  service.process(order)

  // 結果を検証（振る舞い）
  saved = repo.findById(order.id)
  expect(saved).not.toBeNull()
  expect(saved.totalPrice).toBe(1100)

  // 境界の副作用のみ Mock で検証
  verify(notifier.send).calledWith(order.userId, expectedMessage)
}
```

---

## 3. 巨大なテスト

### 問題説明

1つのテストケースで複数の責務を検証している。テストが失敗したとき、何が原因なのかが分かりにくい。
テスト名と検証内容が一致せず、テストがドキュメントとしての役割を果たさない。

### NG 例

```
// 1つのテストで複数の責務を検証
test("ユーザー管理") {
  // 登録のテスト
  user = service.register("太郎", "taro@example.com")
  expect(user).not.toBeNull()
  expect(user.name).toBe("太郎")

  // 更新のテスト
  service.updateEmail(user.id, "new@example.com")
  updated = service.findById(user.id)
  expect(updated.email).toBe("new@example.com")

  // バリデーションのテスト
  expect(() => {
    service.register("", "invalid")
  }).toThrow()

  // 削除のテスト
  service.delete(user.id)
  expect(service.findById(user.id)).toBeNull()

  // 一覧取得のテスト
  service.register("次郎", "jiro@example.com")
  all = service.findAll()
  expect(all).toHaveLength(1)
}
```

### OK 例

```
// 1テスト1責務で分割
describe("ユーザー管理") {
  test("有効なデータでユーザーを登録できる") {
    user = service.register("太郎", "taro@example.com")

    expect(user.name).toBe("太郎")
    expect(user.email).toBe("taro@example.com")
  }

  test("メールアドレスを更新できる") {
    user = service.register("太郎", "taro@example.com")

    service.updateEmail(user.id, "new@example.com")

    updated = service.findById(user.id)
    expect(updated.email).toBe("new@example.com")
  }

  test("名前が空の場合は登録に失敗する") {
    expect(() => {
      service.register("", "taro@example.com")
    }).toThrow(ValidationError)
  }

  test("削除したユーザーは検索できない") {
    user = service.register("太郎", "taro@example.com")

    service.delete(user.id)

    expect(service.findById(user.id)).toBeNull()
  }
}
```

---

## 4. マジックナンバー

### 問題説明

テストデータに意味のない数値や文字列が直接書かれており、何を意図しているのか分からない。
テストを読んだだけでは、なぜその値が使われているのか理解できない。

### NG 例

```
test("割引が正しく適用される") {
  result = calculator.calculate(1000, 3, 0.15, true)

  expect(result).toBe(2550)
}
// → 1000, 3, 0.15, true, 2550 が何を意味するか不明
```

### OK 例

```
test("会員割引15%が3個の商品に適用される") {
  unitPrice = 1000
  quantity = 3
  memberDiscount = 0.15
  isMember = true

  result = calculator.calculate(unitPrice, quantity, memberDiscount, isMember)

  subtotal = unitPrice * quantity  // 3000
  expectedTotal = subtotal * (1 - memberDiscount)  // 2550
  expect(result).toBe(expectedTotal)
}
```

---

## 5. テストの重複

### 問題説明

異なるテストケースが同じ検証を繰り返している。コードの変更時に、複数のテストを同時に修正する必要が生じる。
テストの責務が明確に分離されていないことが原因である。

### NG 例

```
// 複数のテストで同じ検証を重複して行っている
test("ユーザー登録が成功する") {
  user = service.register("太郎", "taro@example.com")

  expect(user.name).toBe("太郎")
  expect(user.email).toBe("taro@example.com")
  expect(user.id).toBeDefined()
  expect(user.createdAt).toBeDefined()     // ← 重複
  expect(user.status).toBe("active")       // ← 重複
}

test("登録されたユーザーがアクティブになる") {
  user = service.register("太郎", "taro@example.com")

  expect(user.name).toBe("太郎")           // ← 重複
  expect(user.email).toBe("taro@example.com")  // ← 重複
  expect(user.createdAt).toBeDefined()     // ← 重複
  expect(user.status).toBe("active")       // ← 重複
}
```

### OK 例

```
// 各テストが固有の責務だけを検証する
test("ユーザー登録で名前とメールが保存される") {
  user = service.register("太郎", "taro@example.com")

  expect(user.name).toBe("太郎")
  expect(user.email).toBe("taro@example.com")
}

test("登録されたユーザーはアクティブ状態になる") {
  user = service.register("太郎", "taro@example.com")

  expect(user.status).toBe("active")
}

test("登録時にIDと作成日時が自動設定される") {
  user = service.register("太郎", "taro@example.com")

  expect(user.id).toBeDefined()
  expect(user.createdAt).toBeDefined()
}
```

---

## 6. 脆いアサーション

### 問題説明

テストが本質的でない部分まで完全一致で検証しており、些細な変更でテストが壊れる。
たとえば、エラーメッセージの文言変更、配列の順序変更、タイムスタンプのミリ秒差などで失敗する。

### NG 例

```
// 完全一致に依存した脆い検証
test("エラーレスポンスが正しい") {
  response = service.validate(invalidData)

  // メッセージの文言変更で壊れる
  expect(response.message).toBe("入力エラー: 「名前」フィールドは必須です。2文字以上で入力してください。")

  // 順序に依存している
  expect(response.errors).toEqual([
    { field: "name", code: "required" },
    { field: "email", code: "invalid_format" }
  ])
}

test("検索結果が正しい") {
  result = service.search("テスト")

  // 全プロパティの完全一致 → 不要なプロパティの変更で壊れる
  expect(result).toEqual({
    items: [{ id: "1", name: "テスト商品", price: 1000, createdAt: "2025-01-01T00:00:00Z", updatedAt: "2025-01-01T00:00:00Z" }],
    total: 1,
    page: 1,
    hasNext: false
  })
}
```

### OK 例

```
// 本質的な部分のみを検証
test("バリデーションエラーに必須項目の不足が含まれる") {
  response = service.validate(invalidData)

  expect(response.errors).toHaveLength(2)
  expect(response.errors).toContainEqual(
    expect.objectContaining({ field: "name", code: "required" })
  )
}

test("検索結果にキーワードに一致する商品が含まれる") {
  result = service.search("テスト")

  expect(result.items).toHaveLength(1)
  expect(result.items[0].name).toContain("テスト")
  expect(result.total).toBe(1)
}
```

---

## 7. 条件分岐のあるテスト

### 問題説明

テストコード内に `if` 文やループが含まれており、テスト自体にロジックが入っている。
テストにバグが紛れ込む可能性があり、テストの信頼性が損なわれる。
テストが失敗した場合に、どの条件分岐で失敗したのか特定しにくい。

### NG 例

```
// テスト内に条件分岐がある
test("ユーザー種別に応じた割引率") {
  userTypes = ["regular", "premium", "vip"]
  expectedDiscounts = [0, 0.10, 0.20]

  for (i = 0; i < userTypes.length; i++) {
    discount = service.getDiscount(userTypes[i])

    if (userTypes[i] === "regular") {
      expect(discount).toBe(0)
    } else if (userTypes[i] === "premium") {
      expect(discount).toBe(0.10)
    } else {
      expect(discount).toBe(0.20)
    }
  }
}
```

### OK 例

```
// ケースごとに独立したテストに分離
test("一般ユーザーの割引率は0%") {
  discount = service.getDiscount("regular")

  expect(discount).toBe(0)
}

test("プレミアムユーザーの割引率は10%") {
  discount = service.getDiscount("premium")

  expect(discount).toBe(0.10)
}

test("VIPユーザーの割引率は20%") {
  discount = service.getDiscount("vip")

  expect(discount).toBe(0.20)
}

// パラメタライズドテストも有効
test.each([
  ["regular", 0],
  ["premium", 0.10],
  ["vip", 0.20],
])("ユーザー種別 %s の割引率は %d", (type, expectedDiscount) => {
  discount = service.getDiscount(type)

  expect(discount).toBe(expectedDiscount)
})
```

---

## 8. 非決定的テスト

### 問題説明

テストが現在時刻、乱数、ネットワーク状態など非決定的な要素に依存しており、実行タイミングによって結果が変わる。
CI で不定期に失敗する「フレーキーテスト」の主な原因である。

### NG 例

```
// 現在時刻に依存するテスト
test("作成日時が今日になる") {
  user = service.createUser("太郎")

  // テスト実行が日付境界（23:59:59）に重なると失敗する
  today = new Date().toISOString().split("T")[0]
  expect(user.createdAt).toContain(today)
}

// 乱数に依存するテスト
test("ランダムIDが生成される") {
  user1 = service.createUser("太郎")
  user2 = service.createUser("次郎")

  // 極めて低確率だが、同じIDが生成される可能性がある
  expect(user1.id).not.toBe(user2.id)
}
```

### OK 例

```
// 時刻を DI で注入し、固定する
test("作成日時に現在時刻が設定される") {
  fixedNow = new Date("2025-06-15T10:00:00Z")
  clock = new StubClock(fixedNow)
  service = new UserService(repository, clock)

  user = service.createUser("太郎")

  expect(user.createdAt).toEqual(fixedNow)
}

// 乱数生成器を DI で注入し、固定する
test("IDが指定されたフォーマットで生成される") {
  idGenerator = new StubIdGenerator("fixed-id-123")
  service = new UserService(repository, clock, idGenerator)

  user = service.createUser("太郎")

  expect(user.id).toBe("fixed-id-123")
}
```

---

## 9. コメントアウトされたテスト

### 問題説明

`test.skip` やコメントアウトでテストが無効化されたまま放置されている。
無効化の理由が記録されず、いつ誰がなぜ無効にしたのか分からなくなる。
テストスイートのカバレッジが実質的に低下しているが、見かけ上は問題がない。

### NG 例

```
// 放置された skip テスト
test.skip("複雑な計算ロジック") {
  // TODO: あとで直す
  result = service.complexCalculation(data)
  expect(result).toBe(expected)
}

// コメントアウトされたテスト
// test("エッジケースの処理") {
//   result = service.process(edgeCaseData)
//   expect(result).toBe(expected)
// }

test.skip("パフォーマンステスト") {
  // 何ヶ月も前から skip されている
  // 誰も理由を覚えていない
}
```

### OK 例

```
// 選択肢1: テストを修正して有効化する
test("複雑な計算ロジックが正しい結果を返す") {
  result = service.complexCalculation(data)

  expect(result).toBe(expected)
}

// 選択肢2: 不要なら削除する（git 履歴に残る）
// → テストを完全に削除し、必要になったら git log から復元する

// 選択肢3: 一時的に skip する場合は理由と期限を明記する
test.skip("外部API変更対応中 - 2025年7月までに修正予定 (TICKET-1234)") {
  result = service.fetchExternalData()
  expect(result).toBeDefined()
}
```

---

## 10. アサーションなし

### 問題説明

テストに `expect` や `assert` が含まれておらず、何も検証していない。
テストが常にパスするため、コードにバグがあっても検出できない。
「例外が出なければ OK」という暗黙の前提に頼っている場合が多い。

### NG 例

```
// expect がないテスト
test("ユーザーを作成する") {
  service.createUser("太郎", "taro@example.com")
  // → 何も検証していない。例外が出なければパスする
}

test("データを処理する") {
  data = loadTestData()
  result = service.process(data)
  console.log(result)  // ログに出すだけで検証していない
}

test("一覧を取得する") {
  users = service.findAll()
  // users の中身を検証していない
}
```

### OK 例

```
// 明示的なアサーションで結果を検証する
test("ユーザーを作成すると保存される") {
  service.createUser("太郎", "taro@example.com")

  user = repository.findByEmail("taro@example.com")
  expect(user).not.toBeNull()
  expect(user.name).toBe("太郎")
}

test("データを処理すると変換結果が返る") {
  data = loadTestData()

  result = service.process(data)

  expect(result.status).toBe("completed")
  expect(result.items).toHaveLength(3)
}

test("全ユーザーが取得できる") {
  repository.save(user1)
  repository.save(user2)

  users = service.findAll()

  expect(users).toHaveLength(2)
}
```

---

## 11. テストのテスト不足

### 問題説明

テスト自体が常に成功するように書かれており、テストとしての検証力がない。
条件が常に `true` になるアサーション、到達しないコードパス、誤った期待値などが原因。
テストが「グリーン」であることに安心してしまい、実際にはバグを見逃している。

### NG 例

```
// 常に true になるアサーション
test("計算結果が正しい") {
  result = service.calculate(100)

  expect(result).toBe(result)  // 自分自身と比較 → 常に true
}

test("エラーがスローされる") {
  try {
    service.process(invalidData)
  } catch (e) {
    expect(e).toBeDefined()  // catch に入った場合のみ検証
  }
  // → 例外がスローされなかった場合、テストはパスしてしまう
}

test("配列に要素が含まれる") {
  items = service.getItems()

  expect(items.length >= 0).toBe(true)  // 常に true
}
```

### OK 例

```
// 意味のある期待値と比較する
test("計算結果が正しい") {
  result = service.calculate(100)

  expect(result).toBe(110)  // 具体的な期待値
}

test("無効なデータでエラーがスローされる") {
  // expect 内で例外を検証する（スローされなければ失敗する）
  expect(() => {
    service.process(invalidData)
  }).toThrow(ValidationError)
}

test("アイテムが3件返される") {
  setupTestItems(3)

  items = service.getItems()

  expect(items).toHaveLength(3)  // 具体的な件数
}
```

---

## 12. スリープ依存

### 問題説明

非同期処理の完了を固定時間の `sleep` / `setTimeout` で待機している。
待機時間が短すぎるとテストが不安定になり、長すぎるとテスト全体の実行時間が膨らむ。
CI 環境では実行マシンの性能差により、ローカルでは通るテストが CI で失敗する。

### NG 例

```
// 固定時間のスリープで非同期処理を待つ
test("非同期でデータが保存される") {
  service.saveAsync(data)

  // 2秒待てば終わるだろう、という希望的観測
  await sleep(2000)

  result = repository.findById(data.id)
  expect(result).not.toBeNull()
}

test("イベントが処理される") {
  emitter.emit("process", payload)

  // 500ms で足りるはず...
  await sleep(500)

  expect(handler.processed).toBe(true)
}
```

### OK 例

```
// ポーリングで条件が満たされるまで待機
test("非同期でデータが保存される") {
  service.saveAsync(data)

  // 条件が満たされるまでポーリング（タイムアウト付き）
  await waitFor(() => {
    result = repository.findById(data.id)
    expect(result).not.toBeNull()
  }, { timeout: 5000 })
}

// イベント完了を Promise で待機
test("イベントが処理される") {
  promise = new Promise(resolve => {
    handler.onComplete(() => resolve())
  })

  emitter.emit("process", payload)

  await promise  // イベント処理完了を確実に待つ

  expect(handler.processed).toBe(true)
}

// コールバック/Promise ベースの API を使う
test("非同期処理の結果を検証する") {
  result = await service.saveAsync(data)  // Promise を直接 await

  expect(result.status).toBe("saved")

  found = repository.findById(data.id)
  expect(found).not.toBeNull()
}
```
