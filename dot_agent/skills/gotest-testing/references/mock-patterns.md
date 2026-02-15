# Go インターフェースベースモックパターン

Go では外部依存をインターフェースで抽象化し、テスト時にモック実装に差し替える。コード生成ツールに頼らず、手動でシンプルなモックを書くパターンを中心に解説する。

## 目次

- [基本原則](#基本原則)
- [パターン1: 関数フィールドモック](#パターン1-関数フィールドモック)
- [パターン2: 呼び出し記録付きモック](#パターン2-呼び出し記録付きモック)
- [パターン3: 固定値返却モック](#パターン3-固定値返却モック)
- [パターン4: 複数インターフェースの合成](#パターン4-複数インターフェースの合成)
- [パターン5: io.Reader / io.Writer のモック](#パターン5-ioreader--iowriter-のモック)
- [パターン6: HTTP クライアントのモック](#パターン6-http-クライアントのモック)
- [パターン7: データベースのモック](#パターン7-データベースのモック)
- [コード生成ツール](#コード生成ツール)
- [設計のベストプラクティス](#設計のベストプラクティス)
  - [インターフェースは小さく保つ](#インターフェースは小さく保つ)
  - [テストヘルパーでモック生成を共通化](#テストヘルパーでモック生成を共通化)

## 基本原則

1. **インターフェースは利用側で定義する**（Accept interfaces, return structs）
2. **小さなインターフェースを好む**（1-3 メソッド）
3. **テストに必要なメソッドだけモックする**

## パターン1: 関数フィールドモック

最も柔軟で推奨されるパターン。テストケースごとに振る舞いを変更可能。

```go
// インターフェース
type Notifier interface {
    Send(ctx context.Context, to, msg string) error
}

// モック
type mockNotifier struct {
    sendFunc func(ctx context.Context, to, msg string) error
}

func (m *mockNotifier) Send(ctx context.Context, to, msg string) error {
    return m.sendFunc(ctx, to, msg)
}

// テスト
func TestAlertService(t *testing.T) {
    tests := []struct {
        name    string
        sendErr error
        wantErr bool
    }{
        {name: "送信成功", sendErr: nil, wantErr: false},
        {name: "送信失敗", sendErr: errors.New("timeout"), wantErr: true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            mock := &mockNotifier{
                sendFunc: func(ctx context.Context, to, msg string) error {
                    return tt.sendErr
                },
            }
            svc := NewAlertService(mock)
            err := svc.Alert(context.Background(), "user@example.com", "test")
            if (err != nil) != tt.wantErr {
                t.Errorf("err = %v, wantErr %v", err, tt.wantErr)
            }
        })
    }
}
```

## パターン2: 呼び出し記録付きモック

メソッドが正しい引数で呼ばれたかを検証する。

```go
type mockRepo struct {
    mu      sync.Mutex
    calls   []saveCall
    saveErr error
}

type saveCall struct {
    ctx  context.Context
    user *User
}

func (m *mockRepo) Save(ctx context.Context, user *User) error {
    m.mu.Lock()
    defer m.mu.Unlock()
    m.calls = append(m.calls, saveCall{ctx: ctx, user: user})
    return m.saveErr
}

func (m *mockRepo) callCount() int {
    m.mu.Lock()
    defer m.mu.Unlock()
    return len(m.calls)
}

// テスト
func TestRegister(t *testing.T) {
    mock := &mockRepo{}
    svc := NewUserService(mock)
    err := svc.Register(context.Background(), "Alice", "alice@example.com")
    if err != nil {
        t.Fatal(err)
    }
    if mock.callCount() != 1 {
        t.Errorf("Save called %d times, want 1", mock.callCount())
    }
    if mock.calls[0].user.Name != "Alice" {
        t.Errorf("saved user name = %q, want Alice", mock.calls[0].user.Name)
    }
}
```

## パターン3: 固定値返却モック

振る舞いが固定の単純なモック。

```go
type stubClock struct {
    now time.Time
}

func (s *stubClock) Now() time.Time {
    return s.now
}

// テスト
func TestExpiry(t *testing.T) {
    clock := &stubClock{now: time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC)}
    svc := NewTokenService(clock)
    token := svc.Issue("user-1")
    want := time.Date(2025, 1, 1, 1, 0, 0, 0, time.UTC) // 1時間後
    if token.ExpiresAt != want {
        t.Errorf("ExpiresAt = %v, want %v", token.ExpiresAt, want)
    }
}
```

## パターン4: 複数インターフェースの合成

テスト対象が複数の依存を持つ場合。

```go
type UserService struct {
    repo     UserRepository
    notifier Notifier
    logger   Logger
}

func TestUserService_Create(t *testing.T) {
    repo := &mockUserRepo{
        saveFunc: func(ctx context.Context, u *User) error { return nil },
    }
    notifier := &mockNotifier{
        sendFunc: func(ctx context.Context, to, msg string) error { return nil },
    }
    logger := &mockLogger{} // ログは検証不要なら空実装

    svc := &UserService{repo: repo, notifier: notifier, logger: logger}
    err := svc.Create(context.Background(), "Alice", "alice@example.com")
    if err != nil {
        t.Fatal(err)
    }
}
```

## パターン5: io.Reader / io.Writer のモック

標準ライブラリのインターフェースを活用。

```go
func TestProcessData(t *testing.T) {
    input := strings.NewReader(`{"name":"Alice"}`)
    var output bytes.Buffer

    err := ProcessData(input, &output)
    if err != nil {
        t.Fatal(err)
    }
    if !strings.Contains(output.String(), "Alice") {
        t.Errorf("output = %q, want containing Alice", output.String())
    }
}

// エラーを返す Reader
type errReader struct{}

func (e *errReader) Read(p []byte) (n int, err error) {
    return 0, errors.New("read error")
}

func TestProcessData_ReadError(t *testing.T) {
    err := ProcessData(&errReader{}, &bytes.Buffer{})
    if err == nil {
        t.Fatal("expected error")
    }
}
```

## パターン6: HTTP クライアントのモック

```go
// インターフェースを定義
type HTTPClient interface {
    Do(req *http.Request) (*http.Response, error)
}

// モック
type mockHTTPClient struct {
    doFunc func(req *http.Request) (*http.Response, error)
}

func (m *mockHTTPClient) Do(req *http.Request) (*http.Response, error) {
    return m.doFunc(req)
}

// テスト
func TestAPIClient_FetchUser(t *testing.T) {
    mock := &mockHTTPClient{
        doFunc: func(req *http.Request) (*http.Response, error) {
            body := `{"id":"1","name":"Alice"}`
            return &http.Response{
                StatusCode: 200,
                Body:       io.NopCloser(strings.NewReader(body)),
            }, nil
        },
    }
    client := NewAPIClient(mock)
    user, err := client.FetchUser(context.Background(), "1")
    if err != nil {
        t.Fatal(err)
    }
    if user.Name != "Alice" {
        t.Errorf("Name = %q, want Alice", user.Name)
    }
}
```

## パターン7: データベースのモック

```go
type Store interface {
    GetUser(ctx context.Context, id int64) (*User, error)
    ListUsers(ctx context.Context, limit int) ([]*User, error)
    CreateUser(ctx context.Context, u *User) error
}

// インメモリ実装
type inMemoryStore struct {
    mu    sync.RWMutex
    users map[int64]*User
    seq   int64
}

func newInMemoryStore() *inMemoryStore {
    return &inMemoryStore{users: make(map[int64]*User)}
}

func (s *inMemoryStore) GetUser(ctx context.Context, id int64) (*User, error) {
    s.mu.RLock()
    defer s.mu.RUnlock()
    u, ok := s.users[id]
    if !ok {
        return nil, ErrNotFound
    }
    return u, nil
}

func (s *inMemoryStore) CreateUser(ctx context.Context, u *User) error {
    s.mu.Lock()
    defer s.mu.Unlock()
    s.seq++
    u.ID = s.seq
    s.users[u.ID] = u
    return nil
}

func (s *inMemoryStore) ListUsers(ctx context.Context, limit int) ([]*User, error) {
    s.mu.RLock()
    defer s.mu.RUnlock()
    var result []*User
    for _, u := range s.users {
        result = append(result, u)
        if len(result) >= limit {
            break
        }
    }
    return result, nil
}
```

## コード生成ツール

手動モックが煩雑な場合はツールを検討する。

| ツール | 特徴 |
|--------|------|
| [gomock](https://github.com/uber-go/mock) | Google 公式（現在 uber-go メンテナンス）。`mockgen` でインターフェースからモック自動生成 |
| [moq](https://github.com/matryer/moq) | 関数フィールドベースのモックを生成。シンプルで読みやすい |
| [counterfeiter](https://github.com/maxbrunsfeld/counterfeiter) | 呼び出し記録と引数キャプチャを自動生成 |

**推奨**: まず手動モックで始め、インターフェースが大きい場合にのみツールを導入する。

## 設計のベストプラクティス

### インターフェースは小さく保つ

```go
// 良い例: 単一責任
type UserReader interface {
    GetUser(ctx context.Context, id string) (*User, error)
}

type UserWriter interface {
    SaveUser(ctx context.Context, u *User) error
}

// 必要なら合成
type UserReadWriter interface {
    UserReader
    UserWriter
}
```

### テストヘルパーでモック生成を共通化

```go
func newTestService(t *testing.T, opts ...func(*mockDeps)) *Service {
    t.Helper()
    deps := &mockDeps{
        repo: &mockRepo{
            saveFunc: func(ctx context.Context, u *User) error { return nil },
        },
        notifier: &mockNotifier{
            sendFunc: func(ctx context.Context, to, msg string) error { return nil },
        },
    }
    for _, opt := range opts {
        opt(deps)
    }
    return NewService(deps.repo, deps.notifier)
}

// 使用例
func TestService_FailOnSave(t *testing.T) {
    svc := newTestService(t, func(d *mockDeps) {
        d.repo = &mockRepo{
            saveFunc: func(ctx context.Context, u *User) error {
                return errors.New("db error")
            },
        }
    })
    err := svc.CreateUser(context.Background(), "Alice")
    if err == nil {
        t.Fatal("expected error")
    }
}
```
