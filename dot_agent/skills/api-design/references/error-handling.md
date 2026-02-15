# エラー設計詳細ガイド

## 目次

1. [エラー層の設計](#エラー層の設計)
2. [ドメインエラー](#ドメインエラー)
3. [アプリケーションエラー](#アプリケーションエラー)
4. [エラー変換の原則](#エラー変換の原則)
5. [エラーレスポンスフォーマット](#エラーレスポンスフォーマット)
6. [避けるべきパターン](#避けるべきパターン)

---

## エラー層の設計

エラーは以下の流れで伝播・変換する。

```
Domain Error（ドメイン層で発生）
    ↓ UseCase がそのまま throw / return
Application Error（UseCase 層で発生する場合もある）
    ↓ Presentation 層でキャッチ
HTTP Error Response（クライアントに返却）
```

各層のエラーは上位層でのみ変換する。ドメイン層が HTTP を意識してはならない。

---

## ドメインエラー

### 基底クラス

```
class DomainError:
    code: string      // 機械可読なエラーコード
    message: string   // 人間可読な説明

class NotFoundError extends DomainError:
    constructor(entityName: string, id: string):
        code = "[ENTITY]_NOT_FOUND"  // e.g. "USER_NOT_FOUND"
        message = "{entityName} not found: {id}"
```

### 命名原則

- エラークラス名は `[状況]Error` とする
- エラーコードは `UPPER_SNAKE_CASE` とする
- メッセージは英語で記述し、ログや開発者向けとする

### 分類テーブル

| 分類       | エラークラス           | エラーコード例            | 意味                         |
| ---------- | ---------------------- | ------------------------- | ---------------------------- |
| 存在しない | `NotFoundError`        | `USER_NOT_FOUND`          | 指定されたリソースが存在しない |
| 重複       | `AlreadyExistsError`   | `EMAIL_ALREADY_EXISTS`    | 一意制約に違反する           |
| 検証失敗   | `ValidationError`      | `INVALID_EMAIL_FORMAT`    | 入力値がドメインルールに違反 |
| 状態不正   | `InvalidStateError`    | `ORDER_ALREADY_SHIPPED`   | 現在の状態では操作不可       |
| 権限不足   | `PermissionDeniedError`| `INSUFFICIENT_PERMISSION` | 操作に必要な権限がない       |

---

## アプリケーションエラー

UseCase 固有のエラー。ドメインエラーに該当しない業務的な失敗を表す。

```
class ApplicationError:
    code: string
    message: string

class ExternalServiceError extends ApplicationError:
    constructor(serviceName: string, detail: string):
        code = "EXTERNAL_SERVICE_ERROR"
        message = "External service failed: {serviceName} - {detail}"

class ConcurrencyConflictError extends ApplicationError:
    constructor(entityName: string, id: string):
        code = "CONCURRENCY_CONFLICT"
        message = "Resource was modified by another process: {entityName} {id}"
```

---

## エラー変換の原則

Presentation 層でドメイン/アプリケーションエラーを HTTP レスポンスに変換する。

### マッピングテーブル

| エラークラス             | HTTP ステータス | 補足                     |
| ------------------------ | --------------- | ------------------------ |
| `NotFoundError`          | `404`           |                          |
| `AlreadyExistsError`     | `409`           |                          |
| `ValidationError`        | `400`           | details を含める         |
| `InvalidStateError`      | `409` or `422`  | 状況に応じて選択         |
| `PermissionDeniedError`  | `403`           |                          |
| `ExternalServiceError`   | `502`           | 内部詳細はログのみ       |
| `ConcurrencyConflictError` | `409`         |                          |
| 未知のエラー             | `500`           | スタックトレースはログのみ |

### 変換の実装例

```
function handleError(error) -> HttpResponse:
    if error is NotFoundError:
        return HttpResponse(404, toErrorResponse(error))
    if error is ValidationError:
        return HttpResponse(400, toValidationErrorResponse(error))
    if error is AlreadyExistsError:
        return HttpResponse(409, toErrorResponse(error))
    if error is PermissionDeniedError:
        return HttpResponse(403, toErrorResponse(error))
    // 未知のエラー: 詳細をログに記録し、汎用メッセージを返す
    log.error(error)
    return HttpResponse(500, { code: "INTERNAL_ERROR", message: "Internal server error" })
```

---

## エラーレスポンスフォーマット

### 基本フォーマット

```json
{
  "error": {
    "code": "USER_NOT_FOUND",
    "message": "User not found: usr_12345"
  }
}
```

### バリデーションエラー（details 付き）

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Input validation failed",
    "details": [
      {
        "field": "email",
        "code": "INVALID_FORMAT",
        "message": "Invalid email format"
      },
      {
        "field": "age",
        "code": "OUT_OF_RANGE",
        "message": "Age must be between 0 and 150"
      }
    ]
  }
}
```

---

## 避けるべきパターン

### ドメイン層での HTTP 依存

```
// NG: ドメインエラーが HTTP を知っている
class NotFoundError:
    statusCode = 404  // HTTP の関心事が混入

// OK: ドメインエラーは純粋にドメインの語彙で表現
class NotFoundError:
    code = "USER_NOT_FOUND"
```

### エラーの握りつぶし

```
// NG: エラーを無視して null を返す
execute(id):
    try:
        return repository.findById(id)
    catch:
        return null  // 何が起きたか不明になる

// OK: 適切なエラーを伝播する
execute(id):
    entity = repository.findById(id)
    if entity == null:
        throw NotFoundError("Entity", id)
    return toEntityDto(entity)
```

### 汎用エラーの乱用

```
// NG: すべて同じエラー型で返す
throw Error("something went wrong")

// OK: 具体的なエラー型で返す
throw AlreadyExistsError("User", "email", input.email)
```

### 内部情報の漏洩

```
// NG: スタックトレースや内部実装をクライアントに返す
return HttpResponse(500, {
    message: "NullPointerException at UserRepository.java:42",
    stackTrace: "..."
})

// OK: 汎用メッセージを返し、詳細はサーバーログに記録
log.error(error)  // 詳細はログへ
return HttpResponse(500, {
    code: "INTERNAL_ERROR",
    message: "Internal server error"
})
```
