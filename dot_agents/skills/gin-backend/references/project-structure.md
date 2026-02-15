# Go プロジェクト構造詳細

## 目次

- [標準レイアウト](#標準レイアウト)
- [各ディレクトリの責務](#各ディレクトリの責務)
  - [cmd/](#cmd)
  - [internal/](#internal)
  - [internal/handler/](#internalhandler)
  - [internal/service/](#internalservice)
  - [internal/repository/](#internalrepository)
  - [internal/model/](#internalmodel)
  - [internal/dto/](#internaldto)
  - [pkg/](#pkg)
- [依存方向](#依存方向)
- [ファイル命名規則](#ファイル命名規則)
- [パッケージ設計の原則](#パッケージ設計の原則)

## 標準レイアウト

```
project-root/
├── cmd/                          # エントリポイント
│   └── server/
│       └── main.go               # サーバー起動
├── internal/                     # 外部非公開（Go コンパイラが強制）
│   ├── handler/                  # HTTP ハンドラ（Presentation 層）
│   │   ├── user_handler.go
│   │   ├── user_handler_test.go
│   │   └── health_handler.go
│   ├── middleware/                # カスタムミドルウェア
│   │   ├── auth.go
│   │   ├── cors.go
│   │   ├── logger.go
│   │   └── recovery.go
│   ├── service/                  # ビジネスロジック
│   │   ├── user_service.go
│   │   └── user_service_test.go
│   ├── repository/               # データアクセス
│   │   ├── user_repository.go
│   │   └── user_repository_test.go
│   ├── model/                    # ドメインモデル
│   │   └── user.go
│   ├── dto/                      # リクエスト/レスポンス DTO
│   │   ├── request.go
│   │   └── response.go
│   ├── config/                   # 設定管理
│   │   └── config.go
│   └── router/                   # ルーティング設定
│       └── router.go
├── pkg/                          # 外部公開可能なユーティリティ
│   ├── validator/
│   └── httputil/
├── migrations/                   # DBマイグレーション
├── docs/                         # API ドキュメント（Swagger 等）
├── .env.example
├── Dockerfile
├── Makefile
├── go.mod
└── go.sum
```

## 各ディレクトリの責務

### cmd/

アプリケーションのエントリポイント。複数バイナリが必要な場合はサブディレクトリを分ける。

```go
// cmd/server/main.go
package main

import (
    "log"

    "myapp/internal/config"
    "myapp/internal/handler"
    "myapp/internal/repository"
    "myapp/internal/router"
    "myapp/internal/service"
)

func main() {
    cfg := config.Load()

    // DI: 依存を外側から注入
    userRepo := repository.NewUserRepository(cfg.DB)
    userSvc := service.NewUserService(userRepo)
    userHandler := handler.NewUserHandler(userSvc)

    r := router.Setup(userHandler)
    log.Fatal(r.Run(cfg.Port))
}
```

### internal/

Go コンパイラが外部パッケージからのインポートを禁止する。プロジェクト固有のコードはすべてここに配置。

### internal/handler/

HTTP リクエストの受付とレスポンス返却のみを担当。ビジネスロジックは含めない。

```go
// internal/handler/user_handler.go
package handler

type UserHandler struct {
    svc *service.UserService
}

func NewUserHandler(svc *service.UserService) *UserHandler {
    return &UserHandler{svc: svc}
}

func (h *UserHandler) GetUser(c *gin.Context) {
    id := c.Param("id")

    user, err := h.svc.GetByID(c.Request.Context(), id)
    if err != nil {
        mapError(c, err)
        return
    }
    Success(c, toUserResponse(user))
}
```

### internal/service/

ビジネスロジックを実装。リポジトリインターフェースに依存する。

```go
// internal/service/user_service.go
package service

type UserService struct {
    repo UserRepository
}

// インターフェースは利用側で定義
type UserRepository interface {
    FindByID(ctx context.Context, id string) (*model.User, error)
    Save(ctx context.Context, user *model.User) error
    Delete(ctx context.Context, id string) error
}

func NewUserService(repo UserRepository) *UserService {
    return &UserService{repo: repo}
}

func (s *UserService) GetByID(ctx context.Context, id string) (*model.User, error) {
    user, err := s.repo.FindByID(ctx, id)
    if err != nil {
        return nil, fmt.Errorf("get user: %w", err)
    }
    return user, nil
}
```

### internal/repository/

データアクセスの実装。service パッケージで定義されたインターフェースを満たす。

```go
// internal/repository/user_repository.go
package repository

type userRepository struct {
    db *sql.DB
}

func NewUserRepository(db *sql.DB) *userRepository {
    return &userRepository{db: db}
}

func (r *userRepository) FindByID(ctx context.Context, id string) (*model.User, error) {
    var u model.User
    err := r.db.QueryRowContext(ctx, "SELECT id, name, email FROM users WHERE id = $1", id).
        Scan(&u.ID, &u.Name, &u.Email)
    if errors.Is(err, sql.ErrNoRows) {
        return nil, service.ErrNotFound
    }
    return &u, err
}
```

### internal/model/

ドメインモデル。外部依存なし。

```go
// internal/model/user.go
package model

import "time"

type User struct {
    ID        string
    Name      string
    Email     string
    CreatedAt time.Time
    UpdatedAt time.Time
}
```

### internal/dto/

HTTP リクエスト/レスポンスの構造体。バリデーションタグを含む。

```go
// internal/dto/request.go
package dto

type CreateUserRequest struct {
    Name  string `json:"name"  binding:"required,min=1,max=100"`
    Email string `json:"email" binding:"required,email"`
}

type UpdateUserRequest struct {
    Name  *string `json:"name"  binding:"omitempty,min=1,max=100"`
    Email *string `json:"email" binding:"omitempty,email"`
}

// internal/dto/response.go
type UserResponse struct {
    ID    string `json:"id"`
    Name  string `json:"name"`
    Email string `json:"email"`
}
```

### pkg/

他プロジェクトでも再利用可能な汎用パッケージ。プロジェクト固有のロジックを含めない。

## 依存方向

```
handler → service → repository
   ↓          ↓
  dto       model
```

- handler は service のインターフェースに依存
- service は repository のインターフェースを自身で定義
- repository は service のインターフェースを実装

## ファイル命名規則

| 対象 | 命名パターン | 例 |
|------|-------------|-----|
| ハンドラ | `{resource}_handler.go` | `user_handler.go` |
| サービス | `{resource}_service.go` | `user_service.go` |
| リポジトリ | `{resource}_repository.go` | `user_repository.go` |
| モデル | `{resource}.go` | `user.go` |
| テスト | `{file}_test.go` | `user_service_test.go` |
| ミドルウェア | `{機能}.go` | `auth.go`, `cors.go` |

## パッケージ設計の原則

1. **パッケージ名は短く**: `userservice` ではなく `service`
2. **循環依存を避ける**: インターフェースを利用側で定義
3. **internal で公開範囲を制限**: 不用意な外部依存を防ぐ
4. **テストは同じパッケージ内**: `_test.go` サフィックスで配置
5. **ドメインモデルは最小依存**: フレームワーク依存なし
