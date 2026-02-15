# Gin ミドルウェアパターン

## 目次

- [ミドルウェアの基本構造](#ミドルウェアの基本構造)
- [認証ミドルウェア](#認証ミドルウェア)
  - [JWT 認証](#jwt-認証)
  - [ロールベース認可](#ロールベース認可)
- [CORS ミドルウェア](#cors-ミドルウェア)
- [リカバリミドルウェア](#リカバリミドルウェア)
- [リクエストログミドルウェア](#リクエストログミドルウェア)
- [リクエスト ID ミドルウェア](#リクエスト-id-ミドルウェア)
- [レートリミット](#レートリミット)
- [タイムアウトミドルウェア](#タイムアウトミドルウェア)
- [ミドルウェアの適用順序](#ミドルウェアの適用順序)
- [テストでのミドルウェア](#テストでのミドルウェア)

## ミドルウェアの基本構造

```go
func MyMiddleware() gin.HandlerFunc {
    // 初期化処理（リクエストごとではなく一度だけ実行）
    return func(c *gin.Context) {
        // リクエスト前処理
        c.Next()
        // レスポンス後処理
    }
}
```

**重要な制御メソッド:**
- `c.Next()` - 後続のハンドラを実行
- `c.Abort()` - 後続のハンドラをスキップ
- `c.AbortWithStatusJSON()` - エラーレスポンスを返して停止

## 認証ミドルウェア

### JWT 認証

```go
type AuthMiddleware struct {
    secret []byte
    logger *slog.Logger
}

func NewAuthMiddleware(secret []byte, logger *slog.Logger) *AuthMiddleware {
    return &AuthMiddleware{secret: secret, logger: logger}
}

func (a *AuthMiddleware) Required() gin.HandlerFunc {
    return func(c *gin.Context) {
        header := c.GetHeader("Authorization")
        if header == "" {
            c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
                "error": gin.H{"code": "UNAUTHORIZED", "message": "authorization header required"},
            })
            return
        }

        parts := strings.SplitN(header, " ", 2)
        if len(parts) != 2 || parts[0] != "Bearer" {
            c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
                "error": gin.H{"code": "INVALID_TOKEN", "message": "invalid authorization format"},
            })
            return
        }

        claims, err := jwt.Parse(parts[1], a.secret)
        if err != nil {
            a.logger.Warn("token validation failed", "error", err)
            c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
                "error": gin.H{"code": "INVALID_TOKEN", "message": "token validation failed"},
            })
            return
        }

        c.Set("user_id", claims.UserID)
        c.Set("role", claims.Role)
        c.Next()
    }
}

// Optional: 認証はあれば使うが必須ではない
func (a *AuthMiddleware) Optional() gin.HandlerFunc {
    return func(c *gin.Context) {
        header := c.GetHeader("Authorization")
        if header == "" {
            c.Next()
            return
        }
        parts := strings.SplitN(header, " ", 2)
        if len(parts) == 2 && parts[0] == "Bearer" {
            if claims, err := jwt.Parse(parts[1], a.secret); err == nil {
                c.Set("user_id", claims.UserID)
                c.Set("role", claims.Role)
            }
        }
        c.Next()
    }
}
```

### ロールベース認可

```go
func RequireRole(allowed ...string) gin.HandlerFunc {
    roleSet := make(map[string]struct{}, len(allowed))
    for _, r := range allowed {
        roleSet[r] = struct{}{}
    }
    return func(c *gin.Context) {
        role, exists := c.Get("role")
        if !exists {
            c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
                "error": gin.H{"code": "FORBIDDEN", "message": "no role assigned"},
            })
            return
        }
        if _, ok := roleSet[role.(string)]; !ok {
            c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
                "error": gin.H{"code": "FORBIDDEN", "message": "insufficient permissions"},
            })
            return
        }
        c.Next()
    }
}
```

**使用例:**
```go
admin := api.Group("/admin", mw.Required(), RequireRole("admin"))
editor := api.Group("/articles", mw.Required(), RequireRole("admin", "editor"))
```

## CORS ミドルウェア

```go
func CORS(allowedOrigins []string) gin.HandlerFunc {
    originSet := make(map[string]struct{}, len(allowedOrigins))
    for _, o := range allowedOrigins {
        originSet[o] = struct{}{}
    }
    return func(c *gin.Context) {
        origin := c.GetHeader("Origin")
        if _, ok := originSet[origin]; ok {
            c.Header("Access-Control-Allow-Origin", origin)
            c.Header("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS")
            c.Header("Access-Control-Allow-Headers", "Authorization,Content-Type")
            c.Header("Access-Control-Max-Age", "86400")
        }
        if c.Request.Method == http.MethodOptions {
            c.AbortWithStatus(http.StatusNoContent)
            return
        }
        c.Next()
    }
}
```

> 推奨: 本番では `github.com/gin-contrib/cors` を使用

## リカバリミドルウェア

```go
func Recovery(logger *slog.Logger) gin.HandlerFunc {
    return func(c *gin.Context) {
        defer func() {
            if r := recover(); r != nil {
                logger.Error("panic recovered",
                    "error", r,
                    "stack", string(debug.Stack()),
                    "path", c.Request.URL.Path,
                    "request_id", c.GetString("request_id"),
                )
                c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{
                    "error": gin.H{"code": "INTERNAL", "message": "internal server error"},
                })
            }
        }()
        c.Next()
    }
}
```

## リクエストログミドルウェア

```go
func RequestLogger(logger *slog.Logger) gin.HandlerFunc {
    return func(c *gin.Context) {
        start := time.Now()
        path := c.Request.URL.Path
        query := c.Request.URL.RawQuery

        c.Next()

        latency := time.Since(start)
        status := c.Writer.Status()

        attrs := []any{
            "method", c.Request.Method,
            "path", path,
            "query", query,
            "status", status,
            "latency_ms", latency.Milliseconds(),
            "ip", c.ClientIP(),
            "user_agent", c.Request.UserAgent(),
            "request_id", c.GetString("request_id"),
        }

        switch {
        case status >= 500:
            logger.Error("server error", attrs...)
        case status >= 400:
            logger.Warn("client error", attrs...)
        default:
            logger.Info("request", attrs...)
        }
    }
}
```

## リクエスト ID ミドルウェア

```go
func RequestID() gin.HandlerFunc {
    return func(c *gin.Context) {
        id := c.GetHeader("X-Request-ID")
        if id == "" {
            id = uuid.NewString()
        }
        c.Set("request_id", id)
        c.Header("X-Request-ID", id)
        c.Next()
    }
}
```

## レートリミット

```go
func RateLimit(rps int) gin.HandlerFunc {
    limiter := rate.NewLimiter(rate.Limit(rps), rps)
    return func(c *gin.Context) {
        if !limiter.Allow() {
            c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
                "error": gin.H{"code": "RATE_LIMITED", "message": "too many requests"},
            })
            return
        }
        c.Next()
    }
}
```

> 分散環境では Redis ベースのレートリミットを検討

## タイムアウトミドルウェア

```go
func Timeout(timeout time.Duration) gin.HandlerFunc {
    return func(c *gin.Context) {
        ctx, cancel := context.WithTimeout(c.Request.Context(), timeout)
        defer cancel()
        c.Request = c.Request.WithContext(ctx)
        c.Next()
    }
}
```

## ミドルウェアの適用順序

```go
r := gin.New()

// グローバル（全リクエスト）
r.Use(
    RequestID(),                    // 1. リクエストID付与
    Recovery(logger),               // 2. パニックリカバリ
    RequestLogger(logger),          // 3. リクエストログ
    CORS(cfg.AllowedOrigins),       // 4. CORS
    Timeout(30 * time.Second),      // 5. タイムアウト
)

// グループ単位
api := r.Group("/api/v1")
api.Use(RateLimit(100))             // API全体にレートリミット

// 認証が必要なグループ
auth := api.Group("", authMw.Required())
auth.Use() // 追加ミドルウェア

// 管理者のみ
admin := auth.Group("/admin", RequireRole("admin"))
```

**適用順序の原則:**
1. リクエストID（他のミドルウェアで使用するため最初）
2. リカバリ（パニック捕捉のため早い段階）
3. ログ（リクエスト/レスポンスの記録）
4. CORS（プリフライトリクエスト処理）
5. 認証/認可（ビジネスロジックの前）

## テストでのミドルウェア

```go
func TestAuthMiddleware(t *testing.T) {
    gin.SetMode(gin.TestMode)
    r := gin.New()

    mw := NewAuthMiddleware([]byte("test-secret"), slog.Default())
    r.GET("/protected", mw.Required(), func(c *gin.Context) {
        userID, _ := c.Get("user_id")
        c.JSON(http.StatusOK, gin.H{"user_id": userID})
    })

    // 認証なし
    w := httptest.NewRecorder()
    req := httptest.NewRequest("GET", "/protected", nil)
    r.ServeHTTP(w, req)
    assert.Equal(t, http.StatusUnauthorized, w.Code)

    // 有効なトークン
    w = httptest.NewRecorder()
    req = httptest.NewRequest("GET", "/protected", nil)
    req.Header.Set("Authorization", "Bearer "+validToken)
    r.ServeHTTP(w, req)
    assert.Equal(t, http.StatusOK, w.Code)
}
```
