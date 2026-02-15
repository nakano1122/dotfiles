---
name: gin-backend
description: "Gin (Go) バックエンドAPIの包括的な実装ガイド。プロジェクト構造、ルーティング、ミドルウェア、リクエストバインディング、バリデーション、レスポンスパターン、認証/認可ミドルウェア、slogによる構造化ログ、DI（wire/manual）、Goイディオム、環境設定をカバー。GinでのAPI実装、ミドルウェア設計時に使用。"
---

# Gin Backend

Gin フレームワークを使った Go バックエンド API の実装ガイド。Tier 2（フレームワーク固有）スキル。

## ワークフロー

```
1. タスク種別を判定
   ├─ 新規API実装 → 「プロジェクト構造」→「ルーティング」→「リクエスト/レスポンス」
   ├─ ミドルウェア追加 → 「ミドルウェア」→「認証/認可」
   ├─ 横断的関心事 → 「ロギング」→「環境設定」→「DI」
   └─ レビュー → 「レビューチェックリスト」へ
```

## プロジェクト構造

```
project-root/
├── cmd/server/main.go          # エントリポイント
├── internal/                   # 外部非公開パッケージ
│   ├── handler/                # HTTPハンドラ
│   ├── middleware/              # カスタムミドルウェア
│   ├── service/                # ビジネスロジック
│   ├── repository/             # データアクセス
│   ├── model/                  # ドメインモデル
│   ├── dto/                    # リクエスト/レスポンス構造体
│   └── config/                 # 設定管理
├── pkg/                        # 外部公開可能パッケージ
├── go.mod / go.sum
```

- `internal/` で可視性を制御、`cmd/` にエントリポイント配置
- 詳細: [references/project-structure.md](references/project-structure.md)

## ルーティング

```go
func SetupRouter(h *handler.UserHandler, mw *middleware.Auth) *gin.Engine {
    r := gin.New()
    r.Use(gin.Recovery(), middleware.RequestLogger())
    api := r.Group("/api/v1")
    {
        api.POST("/login", h.Login)
        auth := api.Group("", mw.Required())
        {
            auth.GET("/users/:id", h.GetUser)
            auth.PUT("/users/:id", h.UpdateUser)
        }
    }
    return r
}
```

- パスパラメータ: `c.Param("id")` / クエリ: `c.DefaultQuery("limit", "20")`
- ルートグループでミドルウェアを階層的に適用

## ミドルウェア

```go
r.Use(gin.Recovery())  // パニックリカバリ
r.Use(gin.Logger())    // リクエストログ（本番ではカスタム推奨）

// カスタムミドルウェアの基本形
func RequestID() gin.HandlerFunc {
    return func(c *gin.Context) {
        id := c.GetHeader("X-Request-ID")
        if id == "" { id = uuid.NewString() }
        c.Set("request_id", id)
        c.Header("X-Request-ID", id)
        c.Next()
    }
}
```

- 詳細: [references/middleware-patterns.md](references/middleware-patterns.md)

## リクエストバインディングとバリデーション

```go
type CreateUserRequest struct {
    Name  string `json:"name"  binding:"required,min=1,max=100"`
    Email string `json:"email" binding:"required,email"`
    Age   int    `json:"age"   binding:"omitempty,gte=0,lte=150"`
}

func (h *UserHandler) Create(c *gin.Context) {
    var req CreateUserRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        Fail(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
        return
    }
    // ビジネスロジック呼び出し
}
```

| メソッド | 用途 |
|---------|------|
| `ShouldBindJSON` | JSON ボディ |
| `ShouldBindQuery` | クエリパラメータ |
| `ShouldBindUri` | パスパラメータ |

- `ShouldBind` 系を使用（`Bind` 系はエラー時に自動400を返すため制御しづらい）

## レスポンスパターン

```go
type Response struct {
    Data  any    `json:"data,omitempty"`
    Error *Error `json:"error,omitempty"`
}
type Error struct {
    Code    string `json:"code"`
    Message string `json:"message"`
}

func Success(c *gin.Context, data any) { c.JSON(http.StatusOK, Response{Data: data}) }
func Created(c *gin.Context, data any) { c.JSON(http.StatusCreated, Response{Data: data}) }
func Fail(c *gin.Context, status int, code, msg string) {
    c.JSON(status, Response{Error: &Error{Code: code, Message: msg}})
}
```

## 認証/認可ミドルウェア

```go
func (a *AuthMiddleware) Required() gin.HandlerFunc {
    return func(c *gin.Context) {
        token := extractBearerToken(c)
        if token == "" {
            c.AbortWithStatusJSON(http.StatusUnauthorized,
                Response{Error: &Error{Code: "UNAUTHORIZED", Message: "token required"}})
            return
        }
        claims, err := validateJWT(token, a.secret)
        if err != nil {
            c.AbortWithStatusJSON(http.StatusUnauthorized,
                Response{Error: &Error{Code: "INVALID_TOKEN", Message: "invalid token"}})
            return
        }
        c.Set("user_id", claims.UserID)
        c.Set("role", claims.Role)
        c.Next()
    }
}

func RequireRole(roles ...string) gin.HandlerFunc {
    return func(c *gin.Context) {
        role, _ := c.Get("role")
        for _, r := range roles {
            if role == r { c.Next(); return }
        }
        c.AbortWithStatusJSON(http.StatusForbidden,
            Response{Error: &Error{Code: "FORBIDDEN", Message: "insufficient permissions"}})
    }
}
```

- Optional認証、ロールベース認可の詳細: [references/middleware-patterns.md](references/middleware-patterns.md)

## ロギング実装

```go
func NewLogger(env string) *slog.Logger {
    var h slog.Handler
    if env == "production" {
        h = slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo})
    } else {
        h = slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelDebug})
    }
    return slog.New(h)
}

func RequestLogger() gin.HandlerFunc {
    return func(c *gin.Context) {
        start := time.Now()
        c.Next()
        slog.Info("request",
            "method", c.Request.Method, "path", c.Request.URL.Path,
            "status", c.Writer.Status(), "latency_ms", time.Since(start).Milliseconds(),
            "request_id", c.GetString("request_id"))
    }
}
```

- 本番: JSON / Info以上、開発: Text / Debug以上
- リクエストIDでトレーサビリティ確保

## DI パターン

```go
// Manual DI（小〜中規模推奨）
func main() {
    cfg := config.Load()
    db := database.New(cfg.DatabaseURL)
    userRepo := repository.NewUserRepository(db)
    userSvc := service.NewUserService(userRepo)
    userHandler := handler.NewUserHandler(userSvc)
    SetupRouter(userHandler).Run(cfg.Port)
}

// Wire DI（大規模推奨）
//go:build wireinject
func InitializeServer() (*gin.Engine, error) {
    wire.Build(config.Set, database.Set, repository.Set, service.Set, handler.Set, NewRouter)
    return nil, nil
}
```

- いずれも**コンストラクタインジェクション**を基本とする

## Go イディオム

```go
// ドメインエラー定義
var (
    ErrNotFound = errors.New("not found")
    ErrConflict = errors.New("conflict")
)

// ハンドラでのエラーマッピング
func mapError(c *gin.Context, err error) {
    switch {
    case errors.Is(err, service.ErrNotFound):
        Fail(c, http.StatusNotFound, "NOT_FOUND", err.Error())
    case errors.Is(err, service.ErrConflict):
        Fail(c, http.StatusConflict, "CONFLICT", err.Error())
    default:
        slog.Error("unexpected error", "error", err)
        Fail(c, http.StatusInternalServerError, "INTERNAL", "internal server error")
    }
}

// インターフェースは利用側で定義（Go の慣例）
type UserRepository interface {
    FindByID(ctx context.Context, id string) (*model.User, error)
    Save(ctx context.Context, user *model.User) error
}
```

- `gin.Context` をゴルーチンに渡す場合は `c.Copy()` を使う
- `sync.Mutex` / `sync.RWMutex` で共有状態を保護

## 環境設定

```go
type Config struct {
    Port        string `mapstructure:"PORT"`
    DatabaseURL string `mapstructure:"DATABASE_URL"`
    JWTSecret   string `mapstructure:"JWT_SECRET"`
    Env         string `mapstructure:"ENV"`
}

func Load() *Config {
    viper.SetConfigFile(".env")
    viper.AutomaticEnv()
    _ = viper.ReadInConfig()
    var cfg Config
    if err := viper.Unmarshal(&cfg); err != nil { log.Fatalf("config: %v", err) }
    return &cfg
}
```

- `viper` で環境変数と `.env` を統合、デフォルト値は `viper.SetDefault()`

## レビューチェックリスト

### ルーティング/ハンドラ
- [ ] `ShouldBind` 系を使用（`Bind` 系でない）
- [ ] エラー時に `return` している（ミドルウェアでは `c.Abort`）
- [ ] パスパラメータのバリデーションがある

### ミドルウェア
- [ ] `c.Next()` / `c.Abort` の使い分けが正しい
- [ ] 認証ミドルウェアが適切なグループに適用されている

### エラーハンドリング
- [ ] エラーを握り潰していない
- [ ] `errors.Is` / `errors.As` を使用
- [ ] 内部エラーをクライアントに露出していない

### ロギング・並行性
- [ ] 構造化ログ（`slog`）使用、機密情報非含有
- [ ] リクエストIDがログに含まれている
- [ ] ゴルーチンへの `gin.Context` 渡しに `c.Copy()` 使用

## リファレンス

- [references/project-structure.md](references/project-structure.md) - Go プロジェクト構造詳細
- [references/middleware-patterns.md](references/middleware-patterns.md) - ミドルウェアパターン集
- [Gin 公式](https://gin-gonic.com/docs/) / [Go レイアウト](https://github.com/golang-standards/project-layout)
- [slog](https://pkg.go.dev/log/slog) / [wire](https://github.com/google/wire) / [validator](https://github.com/go-playground/validator)
