# テーブル駆動テスト詳細パターン

Go テストにおける最重要パターン。すべてのテストの基本形として採用する。

## 目次

- [基本構造](#基本構造)
- [パターン1: シンプルな入出力](#パターン1-シンプルな入出力)
- [パターン2: エラーを返す関数](#パターン2-エラーを返す関数)
- [パターン3: 構造体の比較](#パターン3-構造体の比較)
- [パターン4: セットアップ関数付き](#パターン4-セットアップ関数付き)
- [パターン5: 検証関数付き](#パターン5-検証関数付き)
- [パターン6: 並列実行](#パターン6-並列実行)
- [パターン7: マップベースのテストケース](#パターン7-マップベースのテストケース)
- [テストケース設計の指針](#テストケース設計の指針)
  - [網羅すべきケース](#網羅すべきケース)
  - [命名規則](#命名規則)
  - [エラーメッセージのフォーマット](#エラーメッセージのフォーマット)

## 基本構造

```go
func TestFunc(t *testing.T) {
    tests := []struct {
        name string
        // 入力フィールド
        // 期待値フィールド
    }{
        // テストケース
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // テスト実行と検証
        })
    }
}
```

## パターン1: シンプルな入出力

```go
func TestAbs(t *testing.T) {
    tests := []struct {
        name  string
        input int
        want  int
    }{
        {name: "正の値", input: 5, want: 5},
        {name: "負の値", input: -5, want: 5},
        {name: "ゼロ", input: 0, want: 0},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            if got := Abs(tt.input); got != tt.want {
                t.Errorf("Abs(%d) = %d, want %d", tt.input, got, tt.want)
            }
        })
    }
}
```

## パターン2: エラーを返す関数

```go
func TestParseAge(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    int
        wantErr bool
        errMsg  string // 任意: エラーメッセージも検証
    }{
        {name: "有効な年齢", input: "25", want: 25},
        {name: "空文字列", input: "", wantErr: true, errMsg: "empty input"},
        {name: "負の数", input: "-1", wantErr: true},
        {name: "数字以外", input: "abc", wantErr: true},
        {name: "境界値_0", input: "0", want: 0},
        {name: "境界値_150", input: "150", want: 150},
        {name: "境界値超過", input: "151", wantErr: true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := ParseAge(tt.input)
            if tt.wantErr {
                if err == nil {
                    t.Fatal("expected error, got nil")
                }
                if tt.errMsg != "" && !strings.Contains(err.Error(), tt.errMsg) {
                    t.Errorf("error = %q, want containing %q", err.Error(), tt.errMsg)
                }
                return
            }
            if err != nil {
                t.Fatalf("unexpected error: %v", err)
            }
            if got != tt.want {
                t.Errorf("ParseAge(%q) = %d, want %d", tt.input, got, tt.want)
            }
        })
    }
}
```

## パターン3: 構造体の比較

```go
func TestNewUser(t *testing.T) {
    tests := []struct {
        name  string
        input string
        want  *User
    }{
        {
            name:  "通常の入力",
            input: "alice@example.com",
            want:  &User{Email: "alice@example.com", Role: "member"},
        },
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := NewUser(tt.input)
            // reflect.DeepEqual または go-cmp を使用
            if diff := cmp.Diff(tt.want, got); diff != "" {
                t.Errorf("NewUser() mismatch (-want +got):\n%s", diff)
            }
        })
    }
}
```

**`go-cmp` の使用を推奨**: `reflect.DeepEqual` より詳細な差分が得られる。

```go
import "github.com/google/go-cmp/cmp"
```

## パターン4: セットアップ関数付き

テストケースごとにセットアップが異なる場合。

```go
func TestOrderService(t *testing.T) {
    tests := []struct {
        name      string
        setupFunc func(t *testing.T) *OrderService
        orderID   string
        want      OrderStatus
        wantErr   bool
    }{
        {
            name: "正常取得",
            setupFunc: func(t *testing.T) *OrderService {
                t.Helper()
                repo := &mockOrderRepo{
                    orders: map[string]*Order{"1": {Status: Completed}},
                }
                return NewOrderService(repo)
            },
            orderID: "1",
            want:    Completed,
        },
        {
            name: "存在しない注文",
            setupFunc: func(t *testing.T) *OrderService {
                t.Helper()
                return NewOrderService(&mockOrderRepo{orders: map[string]*Order{}})
            },
            orderID: "999",
            wantErr: true,
        },
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            svc := tt.setupFunc(t)
            got, err := svc.GetStatus(tt.orderID)
            if (err != nil) != tt.wantErr {
                t.Fatalf("err = %v, wantErr %v", err, tt.wantErr)
            }
            if !tt.wantErr && got != tt.want {
                t.Errorf("GetStatus(%q) = %v, want %v", tt.orderID, got, tt.want)
            }
        })
    }
}
```

## パターン5: 検証関数付き

期待値が複雑な場合、カスタム検証関数を使用。

```go
func TestProcess(t *testing.T) {
    tests := []struct {
        name    string
        input   []byte
        checkFn func(t *testing.T, result *Result, err error)
    }{
        {
            name:  "JSONレスポンス",
            input: []byte(`{"key":"value"}`),
            checkFn: func(t *testing.T, result *Result, err error) {
                t.Helper()
                if err != nil {
                    t.Fatalf("unexpected error: %v", err)
                }
                if result.Count < 1 {
                    t.Errorf("Count = %d, want >= 1", result.Count)
                }
                if !strings.HasPrefix(result.ID, "proc-") {
                    t.Errorf("ID = %q, want prefix 'proc-'", result.ID)
                }
            },
        },
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result, err := Process(tt.input)
            tt.checkFn(t, result, err)
        })
    }
}
```

## パターン6: 並列実行

```go
func TestConcurrent(t *testing.T) {
    tests := []struct {
        name  string
        input int
        want  int
    }{
        {name: "case1", input: 1, want: 2},
        {name: "case2", input: 2, want: 4},
        {name: "case3", input: 3, want: 6},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel() // 各サブテストが並列実行される
            got := Double(tt.input)
            if got != tt.want {
                t.Errorf("Double(%d) = %d, want %d", tt.input, got, tt.want)
            }
        })
    }
}
```

**注意**: Go 1.22 以降はループ変数が各イテレーションでスコープされるため `tt := tt` は不要。Go 1.21 以前では `t.Run` の前に `tt := tt` が必要。

## パターン7: マップベースのテストケース

ケースが少なく名前が一意な場合に有用。ただし実行順序は非決定的。

```go
func TestStatusCode(t *testing.T) {
    tests := map[string]struct {
        input int
        want  string
    }{
        "OK":        {input: 200, want: "OK"},
        "Not Found": {input: 404, want: "Not Found"},
        "Server Error": {input: 500, want: "Internal Server Error"},
    }
    for name, tt := range tests {
        t.Run(name, func(t *testing.T) {
            got := StatusText(tt.input)
            if got != tt.want {
                t.Errorf("StatusText(%d) = %q, want %q", tt.input, got, tt.want)
            }
        })
    }
}
```

## テストケース設計の指針

### 網羅すべきケース

1. **正常系**: 典型的な入力
2. **境界値**: 最小値、最大値、0、空、nil
3. **異常系**: 不正入力、エラー条件
4. **エッジケース**: Unicode、特殊文字、巨大入力

### 命名規則

テストケース名は以下を意識する:

- **何をテストしているか** が明確
- **失敗時に原因が特定しやすい** 名前
- スペースではなくアンダースコアを使用（`go test -run` で扱いやすい）

```go
// 良い例
{name: "空文字列でエラー返却"}
{name: "上限値_100を超過"}
{name: "nilスライスで空配列返却"}

// 避ける例
{name: "test1"}
{name: "エラー"}
{name: "正常"}
```

### エラーメッセージのフォーマット

```go
// 推奨: got/want 形式
t.Errorf("FuncName(%v) = %v, want %v", input, got, want)

// コンテキスト付き
t.Errorf("FuncName(%v) with option %v: got %v, want %v", input, opt, got, want)
```
