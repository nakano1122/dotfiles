---
name: api-design
description: DDD + Clean Architecture に基づく API 設計・実装ガイド（フレームワーク非依存）。レイヤー構造と依存の方向、Entity/Repository/UseCase パターン、DTO/Mapper 設計、APIエンドポイント設計、エラーレスポンス設計、ペイロード設計をカバー。新規 API やドメインモデル設計時、レイヤー構造設計時に使用。
---

# API 設計・実装ガイド

DDD + Clean Architecture に基づくフレームワーク非依存の設計ガイド。

## Clean Architecture レイヤー構造

```
┌─────────────────────────────────────┐
│         Presentation 層             │  ← HTTP/gRPC に関する処理
│      (Routes, Middleware)           │
├─────────────────────────────────────┤
│         Application 層              │  ← ユースケース（DTO を返す）
│      (UseCase, DTO, Mapper)         │
├─────────────────────────────────────┤
│           Domain 層                 │  ← ビジネスルール（最内層）
│  (Entity, Repository IF, Service)   │
├─────────────────────────────────────┤
│       Infrastructure 層             │  ← 技術的実装
│   (Repository 実装, 外部連携)        │
└─────────────────────────────────────┘
```

### 依存の方向: 外 → 内

```
Presentation → Application → Domain ← Infrastructure
```

- **Domain 層**は他の層に依存しない（フレームワーク非依存）
- **Infrastructure 層**は Domain 層のインターフェースを実装

### 各層の責務

| 層 | 責務 | 共有スキーマ使用 |
|----|------|-----------------|
| Domain | Entity, Repository IF, Domain Service, Domain Error | ❌ |
| Application | UseCase, DTO, Entity→DTO 変換 | ❌ |
| Infrastructure | Repository 実装, 外部 API 連携 | ❌ |
| Presentation | ルーティング, DTO→Response 変換, ミドルウェア | ✅ |

## ドメイン層

### Entity

```
Entity = 識別子 + ビジネスルール + 状態

設計原則:
- 不変条件をコンストラクタ/ファクトリで保証
- ビジネスロジックを Entity 内にカプセル化
- 永続化の関心事を含めない
```

### Value Object

```
Value Object = 値の同一性（属性で等価判定）

使用例: メールアドレス、金額、住所
- 不変 (Immutable)
- バリデーションをコンストラクタで実施
```

### Repository Interface

```
Repository IF の設計原則:
- Domain 層にインターフェースのみ定義
- CRUD メソッドは必要なものだけ
- ドメインの言葉で命名 (findByEmail, findActive 等)
- 技術的詳細（SQL、ORM）を含めない
```

## アプリケーション層

### UseCase パターン

```
1 UseCase = 1 ユースケース

設計原則:
- コンストラクタで Repository を受け取る (DI)
- DTO を返す（Entity を直接返さない）
- 複数 Repository の連携はここで行う
- トランザクション制御はここで行う
```

**UseCase の種類**:

| パターン | 例 | 入出力 |
|---------|-----|--------|
| 単純取得 | GetUser | ID → DTO |
| 一覧取得 | ListUsers | フィルタ条件 → DTO[] + total |
| 作成 | CreateUser | 入力 DTO → 結果 DTO |
| 更新 | UpdateUser | ID + 入力 DTO → 結果 DTO |
| 削除 | DeleteUser | ID → void |
| 複合操作 | RegisterUser | 入力 → Entity 作成 + メール送信 + DTO |

### DTO / Mapper 設計

**2 種類の Mapper を使い分ける**:

| Mapper | 層 | 変換方向 | スキーマ使用 |
|--------|-----|---------|-------------|
| Application Mapper | Application | Entity → DTO | ❌ |
| Presentation Mapper | Presentation | DTO → Response | ✅ |

詳細: [references/dto-mapper.md](references/dto-mapper.md)

## API エンドポイント設計

### RESTful 命名規則

| 操作 | メソッド | パス | ステータス |
|------|---------|------|-----------|
| 一覧取得 | GET | /resources | 200 |
| 詳細取得 | GET | /resources/:id | 200 |
| 作成 | POST | /resources | 201 |
| 全体更新 | PUT | /resources/:id | 200 |
| 部分更新 | PATCH | /resources/:id | 200 |
| 削除 | DELETE | /resources/:id | 204 |

### パス設計の原則

- リソース名は**複数形の名詞** (`/users`, `/items`)
- ネストは 2 階層まで (`/users/:id/orders`)
- 動詞はメソッドで表現（パスに動詞を入れない）
- バージョニング: `/api/v1/resources`

## エラーレスポンス設計

### 統一エラーフォーマット

```json
{
  "error": {
    "code": "USER_NOT_FOUND",
    "message": "ユーザーが見つかりません"
  }
}
```

### ドメインエラー → HTTP エラーの変換

| ドメインエラー | HTTP ステータス | エラーコード |
|--------------|----------------|-------------|
| NotFound | 404 | RESOURCE_NOT_FOUND |
| AlreadyExists | 409 | CONFLICT |
| ValidationError | 400 | VALIDATION_ERROR |
| Unauthorized | 401 | UNAUTHORIZED |
| Forbidden | 403 | FORBIDDEN |
| 予期しないエラー | 500 | INTERNAL_ERROR |

**原則**: 内部エラーの詳細をクライアントに露出しない

詳細: [references/error-handling.md](references/error-handling.md)

## ペイロード設計

### リクエスト

- 必須/任意フィールドを明確に区別
- バリデーション制約を型レベルで定義
- ネストは浅く保つ

### レスポンス

- 一貫したエンベロープ構造 (`data` / `error`)
- 日付は ISO 8601 形式
- null を避け、省略可能なフィールドは `omitempty` / optional

## ページネーション / フィルタリング / ソート

### ページネーション

| 方式 | 用途 | パラメータ |
|------|------|-----------|
| Offset | 一般的な一覧 | `?offset=0&limit=20` |
| Cursor | 大量データ、リアルタイム | `?cursor=abc&limit=20` |

レスポンスに `total` (Offset) または `nextCursor` (Cursor) を含める。

### フィルタリング / ソート

```
GET /items?status=active&category=books&sort=created_at&order=desc
```

## 新機能追加フロー

```
1. Domain 層: Entity + Repository Interface 定義
2. Application 層: UseCase + DTO + Mapper 実装
3. Infrastructure 層: Repository 実装
4. Presentation 層: Route + Response Mapper 実装
5. 共有スキーマ: Request/Response スキーマ追加（必要に応じて）
```

## レビューチェックリスト

- [ ] 依存の方向が正しい（外→内）
- [ ] Domain 層が他の層に依存していない
- [ ] UseCase が DTO を返している（Entity を直接返していない）
- [ ] UseCase がコンストラクタで Repository を受け取っている（DI）
- [ ] Application Mapper と Presentation Mapper が分離されている
- [ ] 共有スキーマの使用が Presentation 層のみ
- [ ] エラーレスポンスが統一フォーマット
- [ ] RESTful な命名規則に従っている
- [ ] 内部エラー詳細がクライアントに露出していない

## リファレンス

- [references/usecase-patterns.md](references/usecase-patterns.md) - UseCase 実装パターン詳細
- [references/dto-mapper.md](references/dto-mapper.md) - DTO / Mapper 設計詳細
- [references/error-handling.md](references/error-handling.md) - エラー設計詳細
