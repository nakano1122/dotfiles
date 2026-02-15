---
name: gotest-testing
description: "go test を使った Go テストの包括的な実装ガイド。テストファイル配置、テーブル駆動テスト、サブテスト（t.Run）、テストヘルパー（t.Helper）、インターフェースベースモック、HTTPテスト（httptest）、ベンチマーク、カバレッジ、testifyをカバー。Goでのテスト実装時に使用。"
---

# Go テスト実装ガイド

## ワークフロー

1. テスト対象の関数/メソッドのシグネチャとインターフェースを確認
2. テストファイル (`_test.go`) を同一パッケージに作成
3. テーブル駆動テストで正常系・異常系を網羅
4. サブテスト (`t.Run`) でケースを分離
5. 外部依存はインターフェースベースのモックで分離
6. `go test -race -cover` で実行・カバレッジ確認
7. 必要に応じてベンチマークを追加

## テストファイルの配置と命名規則

```
pkg/
  user.go           # 本体
  user_test.go      # テスト（同一パッケージ）
```

- テストファイルは `_test.go` サフィックス必須
- 同一パッケージ（内部テスト）: `package pkg` - 非公開関数もテスト可能
- 外部パッケージ（ブラックボックス）: `package pkg_test` - 公開APIのみテスト
- テスト用データ: `testdata/` ディレクトリ（go tool に無視される）

## テストの書き方

```go
func TestAdd(t *testing.T) {
    got := Add(2, 3)
    if got != 5 {
        t.Errorf("Add(2, 3) = %d, want 5", got)
    }
}
```

**命名規則**: `Test` + 対象関数名。`t.Errorf` でテスト続行、`t.Fatalf` で即時停止。

## テーブル駆動テスト

Go テストの最重要パターン。すべてのテストでこの形式を基本とする。

```go
func TestCalculate(t *testing.T) {
    tests := []struct {
        name    string
        input   int
        want    int
        wantErr bool
    }{
        {name: "正の値", input: 5, want: 25},
        {name: "ゼロ", input: 0, want: 0},
        {name: "負の値", input: -1, want: 0, wantErr: true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := Calculate(tt.input)
            if (err != nil) != tt.wantErr {
                t.Fatalf("err = %v, wantErr %v", err, tt.wantErr)
            }
            if got != tt.want {
                t.Errorf("Calculate(%d) = %d, want %d", tt.input, got, tt.want)
            }
        })
    }
}
```

**原則**: テストケース構造体に `name` フィールドを必ず含める。詳細は `references/table-driven-tests.md` 参照。

## サブテスト (t.Run)

```go
func TestUser(t *testing.T) {
    t.Run("Create", func(t *testing.T) { /* 作成テスト */ })
    t.Run("Update", func(t *testing.T) { /* 更新テスト */ })
}
```

- 特定サブテストの実行: `go test -run TestUser/Create`
- 並列実行: サブテスト内で `t.Parallel()` を呼ぶ（Go 1.22+ ではループ変数キャプチャ不要）

## テストヘルパー

### t.Helper() / t.Cleanup()

```go
func setupDB(t *testing.T) *sql.DB {
    t.Helper() // エラー報告行を呼び出し元に向ける
    db, err := sql.Open("sqlite3", ":memory:")
    if err != nil {
        t.Fatal(err)
    }
    t.Cleanup(func() { db.Close() }) // テスト終了時に自動解放
    return db
}
```

### TestMain（パッケージ全体のセットアップ）

```go
func TestMain(m *testing.M) {
    setup()
    code := m.Run()
    teardown()
    os.Exit(code)
}
```

## モック / インターフェースベースのテスト

外部依存をインターフェースで抽象化し、テスト用モックに差し替える。

```go
// プロダクションコード
type UserRepository interface {
    FindByID(ctx context.Context, id string) (*User, error)
}

// テスト用モック（関数フィールドパターン）
type mockUserRepo struct {
    findByIDFunc func(ctx context.Context, id string) (*User, error)
}

func (m *mockUserRepo) FindByID(ctx context.Context, id string) (*User, error) {
    return m.findByIDFunc(ctx, id)
}

// テスト
func TestUserService_GetUser(t *testing.T) {
    mock := &mockUserRepo{
        findByIDFunc: func(ctx context.Context, id string) (*User, error) {
            return &User{ID: id, Name: "Alice"}, nil
        },
    }
    svc := &UserService{repo: mock}
    user, err := svc.GetUser(context.Background(), "1")
    if err != nil {
        t.Fatal(err)
    }
    if user.Name != "Alice" {
        t.Errorf("Name = %q, want Alice", user.Name)
    }
}
```

詳細なモックパターンは `references/mock-patterns.md` を参照。

## HTTP テスト

### httptest.NewRecorder（ハンドラ単体テスト）

```go
func TestGetUserHandler(t *testing.T) {
    req := httptest.NewRequest("GET", "/users/1", nil)
    w := httptest.NewRecorder()
    GetUserHandler(w, req)
    if w.Code != http.StatusOK {
        t.Errorf("status = %d, want 200", w.Code)
    }
}
```

### httptest.NewServer（統合テスト）

```go
func TestClient(t *testing.T) {
    srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
    }))
    t.Cleanup(srv.Close)
    resp, err := http.Get(srv.URL + "/health")
    if err != nil {
        t.Fatal(err)
    }
    defer resp.Body.Close()
    if resp.StatusCode != 200 {
        t.Errorf("status = %d, want 200", resp.StatusCode)
    }
}
```

### Gin ルーターテスト

```go
func TestGinRouter(t *testing.T) {
    gin.SetMode(gin.TestMode)
    r := gin.New()
    r.GET("/users/:id", GetUserHandler)
    req := httptest.NewRequest("GET", "/users/1", nil)
    w := httptest.NewRecorder()
    r.ServeHTTP(w, req)
    if w.Code != http.StatusOK {
        t.Errorf("status = %d, want 200", w.Code)
    }
}
```

## ベンチマークテスト

```go
func BenchmarkFib(b *testing.B) {
    for i := 0; i < b.N; i++ {
        Fib(20)
    }
}

// サブベンチマーク
func BenchmarkSort(b *testing.B) {
    for _, size := range []int{100, 1000, 10000} {
        b.Run(fmt.Sprintf("size=%d", size), func(b *testing.B) {
            data := generateData(size)
            b.ResetTimer()
            for i := 0; i < b.N; i++ {
                sort.Ints(append([]int{}, data...))
            }
        })
    }
}
```

実行: `go test -bench=. -benchmem`

## カバレッジ

```bash
go test -cover ./...                                      # カバレッジ表示
go test -coverprofile=coverage.out -covermode=atomic ./... # プロファイル出力
go tool cover -html=coverage.out -o coverage.html          # HTML レポート
go tool cover -func=coverage.out                           # 関数ごと
```

- `-covermode=set`: 実行有無（デフォルト）
- `-covermode=count`: 実行回数
- `-covermode=atomic`: ゴルーチン安全（`-race` 併用時に推奨）

## testify の活用

```go
import (
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestWithTestify(t *testing.T) {
    // assert: 失敗してもテスト続行
    assert.Equal(t, 5, Add(2, 3))
    assert.NoError(t, err)
    assert.Contains(t, "hello world", "hello")
    // require: 失敗で即時停止（前提条件チェックに使用）
    require.NotNil(t, user)
    assert.Equal(t, "Alice", user.Name)
}
```

### testify/suite

```go
type UserSuite struct {
    suite.Suite
    db *sql.DB
}

func (s *UserSuite) SetupSuite()    { s.db = connectDB() }
func (s *UserSuite) TearDownSuite() { s.db.Close() }
func (s *UserSuite) SetupTest()     { truncateTables(s.db) }

func (s *UserSuite) TestCreate() {
    err := CreateUser(s.db, "Alice")
    s.Require().NoError(err)
    s.Equal("Alice", fetchUser(s.db, 1).Name)
}

func TestUserSuite(t *testing.T) { suite.Run(t, new(UserSuite)) }
```

## レビューチェックリスト

- [ ] テーブル駆動テストを使用しているか
- [ ] 正常系・異常系・境界値を網羅しているか
- [ ] サブテスト名が内容を正確に表しているか
- [ ] ヘルパー関数に `t.Helper()` を付与しているか
- [ ] リソースのクリーンアップに `t.Cleanup()` を使用しているか
- [ ] 外部依存はインターフェースで分離されているか
- [ ] `t.Parallel()` の利用を検討したか
- [ ] `-race` フラグでデータ競合を検出しているか
- [ ] エラーメッセージに got/want の両方が含まれているか

## リファレンス

- [Go Testing パッケージ](https://pkg.go.dev/testing)
- [Go Wiki: Table Driven Tests](https://go.dev/wiki/TableDrivenTests)
- [Go Blog: Using Subtests and Sub-benchmarks](https://go.dev/blog/subtests)
- [testify](https://github.com/stretchr/testify)
- `references/table-driven-tests.md` / `references/mock-patterns.md` - 詳細パターン
