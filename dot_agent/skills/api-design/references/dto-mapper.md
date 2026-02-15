# DTO / Mapper 設計詳細ガイド

## 目次

1. [DTO の役割](#dto-の役割)
2. [2 種類の Mapper](#2-種類の-mapper)
3. [なぜ 2 つに分けるか](#なぜ-2-つに分けるか)
4. [命名規則テーブル](#命名規則テーブル)
5. [設計原則](#設計原則)

---

## DTO の役割

DTO（Data Transfer Object）は層間のデータ受け渡しに使う不変のデータ構造である。

### Application DTO

UseCase が返すデータ構造。ドメイン Entity の必要なフィールドを公開用に整形したもの。

```
// Entity（ドメイン層）
class User:
    id: UserId
    name: UserName
    email: Email
    passwordHash: string
    createdAt: DateTime

// Application DTO（UseCase の戻り値）
class UserDto:
    id: string
    name: string
    email: string
    createdAt: string  // ISO 8601 文字列
    // passwordHash は含めない
```

### Presentation DTO（Response）

API のレスポンス形式に対応するデータ構造。API スキーマの変更はここに閉じる。

```
// Presentation DTO（API レスポンス）
class GetUserResponse:
    user: UserResponseItem

class UserResponseItem:
    id: string
    name: string
    email: string
    createdAt: string
```

---

## 2 種類の Mapper

### Application Mapper（Entity → DTO）

ドメイン Entity を Application DTO に変換する。Application 層に配置する。

```
// Application Mapper
function toUserDto(user: User) -> UserDto:
    return UserDto(
        id: user.id.value,
        name: user.name.value,
        email: user.email.value,
        createdAt: user.createdAt.toIso8601()
    )
```

### Presentation Mapper（DTO → Response）

Application DTO を API レスポンス形式に変換する。Presentation 層に配置する。

```
// Presentation Mapper
function toGetUserResponse(dto: UserDto) -> GetUserResponse:
    return GetUserResponse(
        user: UserResponseItem(
            id: dto.id,
            name: dto.name,
            email: dto.email,
            createdAt: dto.createdAt
        )
    )

// 一覧取得の場合
function toListUsersResponse(result: ListResult<UserDto>) -> ListUsersResponse:
    return ListUsersResponse(
        users: result.items.map(toUserResponseItem),
        totalCount: result.totalCount
    )
```

---

## なぜ 2 つに分けるか

### 関心事の分離

| 層            | 関心事                     | 変更理由                       |
| ------------- | -------------------------- | ------------------------------ |
| Application   | ドメインデータの安全な公開 | Entity 構造の変更              |
| Presentation  | API スキーマへの適合       | API バージョン変更、形式変更   |

### スキーマ依存の局所化

API スキーマ（フィールド名、ネスト構造、ページネーション形式）が変わっても、影響は Presentation Mapper に閉じる。UseCase は変更不要。

```
// API v1: フラットなレスポンス
function toGetUserResponseV1(dto: UserDto) -> object:
    return { id: dto.id, name: dto.name }

// API v2: ネストしたレスポンス（UseCase は変更なし）
function toGetUserResponseV2(dto: UserDto) -> object:
    return { data: { user: { id: dto.id, displayName: dto.name } } }
```

### テスト容易性

- Application Mapper: Entity のモックだけでテスト可能
- Presentation Mapper: DTO のモックだけでテスト可能（ドメイン知識不要）

---

## 命名規則テーブル

### Application Mapper

| 変換方向        | 関数名              | 例                    |
| --------------- | ------------------- | --------------------- |
| Entity → DTO    | `to[Entity]Dto`     | `toUserDto(user)`     |
| Entity[] → DTO[] | `to[Entity]Dtos`   | `toUserDtos(users)`   |

### Presentation Mapper

| 変換方向        | 関数名                              | 例                              |
| --------------- | ----------------------------------- | ------------------------------- |
| DTO → Response  | `to[Method][Resource]Response`      | `toGetUserResponse(dto)`        |
| DTO[] → Response | `to[Method][Resource]Response`     | `toListUsersResponse(result)`   |
| Input → Command | `to[Operation]Input`                | `toCreateUserInput(request)`    |

### Request Mapper（リクエスト → UseCase 入力）

```
// Presentation 層で Request を UseCase の Input に変換
function toCreateUserInput(request: CreateUserRequest) -> CreateUserInput:
    return CreateUserInput(
        name: request.name,
        email: request.email
    )
```

---

## 設計原則

### 不変性

DTO は生成後に変更しない。すべてのフィールドを読み取り専用にする。

```
// DTO は不変データ構造として定義する
class UserDto:
    readonly id: string
    readonly name: string
    readonly email: string
```

### 純粋関数

Mapper は外部状態に依存しない純粋関数とする。副作用を持たない。

```
// OK: 入力のみに依存する純粋関数
function toUserDto(user: User) -> UserDto:
    return UserDto(id: user.id.value, name: user.name.value)

// NG: 外部状態に依存する
function toUserDto(user: User) -> UserDto:
    config = GlobalConfig.get()  // 外部状態への依存
    return UserDto(id: user.id.value, name: config.format(user.name))
```

### null の扱い

Optional なフィールドは型で明示し、Mapper 内で安全に変換する。

```
function toUserDto(user: User) -> UserDto:
    return UserDto(
        id: user.id.value,
        name: user.name.value,
        // Optional フィールドは明示的に扱う
        bio: user.bio?.value ?? null,
        avatarUrl: user.avatarUrl?.toString() ?? null
    )
```
