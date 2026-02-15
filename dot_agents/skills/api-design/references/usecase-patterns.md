# UseCase 実装パターン詳細ガイド

## 目次

1. [基本構造](#基本構造)
2. [CRUD パターン](#crud-パターン)
3. [複合操作パターン](#複合操作パターン)
4. [命名規則テーブル](#命名規則テーブル)
5. [アンチパターン](#アンチパターン)

---

## 基本構造

UseCase は **1クラス = 1責務** で設計する。依存は DI で注入し、戻り値は DTO を返す。

```
class CreateOrderUseCase:
    // DI: Repository や外部サービスをコンストラクタで受け取る
    constructor(orderRepository, productRepository, eventPublisher)

    // 公開メソッドは原則 execute の1つのみ
    execute(input: CreateOrderInput) -> OrderDto:
        // 1. バリデーション / ビジネスルールの検証
        product = productRepository.findById(input.productId)
        if product == null:
            throw NotFoundError("Product", input.productId)

        // 2. ドメインロジックの実行
        order = Order.create(input.userId, product, input.quantity)

        // 3. 永続化（トランザクション境界は UseCase が制御）
        savedOrder = orderRepository.save(order)

        // 4. 副作用（イベント発行など）
        eventPublisher.publish(OrderCreatedEvent(savedOrder.id))

        // 5. DTO に変換して返却
        return toOrderDto(savedOrder)
```

**トランザクション制御** は UseCase の責務とする。宣言的（アノテーション等）またはプログラム的に制御する。

---

## CRUD パターン

### Get（単一取得）

```
execute(id) -> EntityDto:
    entity = repository.findById(id)
    if entity == null:
        throw NotFoundError("Entity", id)
    return toEntityDto(entity)
```

### List（一覧取得）

```
execute(criteria) -> ListResult<EntityDto>:
    entities = repository.findAll(criteria)
    totalCount = repository.count(criteria)
    return ListResult(
        items: entities.map(toEntityDto),
        totalCount: totalCount
    )
```

### Create（作成）

```
execute(input) -> EntityDto:
    // 一意性チェックなどのビジネスルール検証
    existing = repository.findByName(input.name)
    if existing != null:
        throw AlreadyExistsError("Entity", "name", input.name)

    entity = Entity.create(input.name, input.description)
    saved = repository.save(entity)
    return toEntityDto(saved)
```

### Update（更新）

```
execute(id, input) -> EntityDto:
    entity = repository.findById(id)
    if entity == null:
        throw NotFoundError("Entity", id)

    entity.update(input.name, input.description)
    saved = repository.save(entity)
    return toEntityDto(saved)
```

### Delete（削除）

```
execute(id) -> void:
    entity = repository.findById(id)
    if entity == null:
        throw NotFoundError("Entity", id)

    repository.delete(entity)
```

---

## 複合操作パターン

複数の Repository やサービスを連携させる場合も、UseCase 内で一貫して制御する。

```
class TransferFundsUseCase:
    constructor(accountRepository, transferService, auditLogger)

    execute(input: TransferInput) -> TransferResultDto:
        // トランザクション開始
        source = accountRepository.findById(input.sourceId)
        target = accountRepository.findById(input.targetId)

        if source == null or target == null:
            throw NotFoundError("Account")

        // ドメインサービスに委譲
        result = transferService.transfer(source, target, input.amount)

        accountRepository.save(source)
        accountRepository.save(target)

        // 副作用
        auditLogger.log(TransferAuditEntry(input, result))

        return toTransferResultDto(result)
```

---

## 命名規則テーブル

| 操作     | クラス名             | メソッド引数          | 戻り値            |
| -------- | -------------------- | --------------------- | ----------------- |
| 単一取得 | `Get[Entity]UseCase` | `id`                  | `[Entity]Dto`     |
| 一覧取得 | `List[Entity]sUseCase` | `criteria / filter` | `ListResult<Dto>` |
| 作成     | `Create[Entity]UseCase` | `Create[Entity]Input` | `[Entity]Dto`  |
| 更新     | `Update[Entity]UseCase` | `id, Update[Entity]Input` | `[Entity]Dto` |
| 削除     | `Delete[Entity]UseCase` | `id`                | `void`            |
| 検索     | `Search[Entity]sUseCase` | `SearchCriteria`   | `ListResult<Dto>` |

---

## アンチパターン

### Fat UseCase

UseCase にビジネスロジックを詰め込みすぎる。ドメインロジックは Entity やドメインサービスに委譲する。

### Entity 直接返却

```
// NG: Entity をそのまま返すと、内部構造が外部に漏洩する
execute(id) -> Order:
    return repository.findById(id)

// OK: DTO に変換して返す
execute(id) -> OrderDto:
    order = repository.findById(id)
    return toOrderDto(order)
```

### Repository 実装への依存

```
// NG: 具象クラスに依存
constructor(mysqlOrderRepository: MysqlOrderRepository)

// OK: インターフェースに依存
constructor(orderRepository: OrderRepository)
```

### Presentation 関心事の混入

```
// NG: UseCase 内で HTTP ステータスコードや JSON フォーマットを扱う
execute(id) -> HttpResponse(status=200, body=toJson(order))

// OK: DTO を返し、Presentation 層が変換する
execute(id) -> OrderDto
```
