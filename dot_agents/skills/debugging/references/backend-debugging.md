# バックエンドデバッグガイド

## 目次

- [ログベースデバッグ](#ログベースデバッグ)
  - [構造化ログの検索](#構造化ログの検索)
  - [ログレベル切り替え](#ログレベル切り替え)
  - [リクエスト ID 追跡](#リクエスト-id-追跡)
- [DB デバッグ](#db-デバッグ)
  - [スロークエリ特定](#スロークエリ特定)
  - [実行計画の読み方](#実行計画の読み方)
  - [ロック待ち検出](#ロック待ち検出)
  - [N+1 問題](#n1-問題)
- [認証/認可デバッグ](#認証認可デバッグ)
  - [トークン検証フロー](#トークン検証フロー)
  - [権限チェックの追跡](#権限チェックの追跡)
- [外部 API 連携デバッグ](#外部-api-連携デバッグ)
  - [タイムアウト問題](#タイムアウト問題)
  - [リトライ戦略](#リトライ戦略)
  - [サーキットブレーカー](#サーキットブレーカー)
- [メモリ/CPU 問題](#メモリcpu-問題)
  - [プロファイリング](#プロファイリング)
  - [ヒープダンプ解析](#ヒープダンプ解析)
- [並行処理デバッグ](#並行処理デバッグ)
  - [デッドロック](#デッドロック)
  - [競合状態](#競合状態)
  - [goroutine リーク](#goroutine-リーク)
- [デプロイ関連問題](#デプロイ関連問題)
  - [環境差異](#環境差異)
  - [設定ミス](#設定ミス)
  - [マイグレーション失敗](#マイグレーション失敗)

## ログベースデバッグ

### 構造化ログの検索

- JSON 形式の構造化ログを使用して、フィールドベースのクエリを可能にする

```json
{
  "timestamp": "2025-01-15T10:30:00Z",
  "level": "error",
  "message": "Failed to process payment",
  "request_id": "req-abc123",
  "user_id": "user-456",
  "service": "payment",
  "error": "timeout after 30s",
  "duration_ms": 30012
}
```

- **検索テクニック**:
  - `jq` でローカルログを絞り込む: `cat app.log | jq 'select(.level == "error" and .service == "payment")'`
  - CloudWatch Logs Insights: `fields @timestamp, @message | filter level = "error" | sort @timestamp desc`
  - Elasticsearch / OpenSearch: `level: "error" AND service: "payment" AND @timestamp >= "2025-01-15"`
  - Loki / LogQL: `{service="payment"} |= "error" | json | duration_ms > 1000`
- ログの出力量が過大な場合、サンプリングレートを設定して抑制する

### ログレベル切り替え

- ランタイムでログレベルを変更できる仕組みを設けておく
- **設定例（Go / zerolog）**:

```go
// 環境変数で切り替え
level, _ := zerolog.ParseLevel(os.Getenv("LOG_LEVEL"))
zerolog.SetGlobalLevel(level)

// HTTP エンドポイントで動的に切り替え
mux.HandleFunc("/admin/log-level", func(w http.ResponseWriter, r *http.Request) {
    newLevel := r.URL.Query().Get("level")
    level, err := zerolog.ParseLevel(newLevel)
    if err != nil {
        http.Error(w, "invalid level", http.StatusBadRequest)
        return
    }
    zerolog.SetGlobalLevel(level)
})
```

- **設定例（Python / logging）**:

```python
import logging

# ランタイムでレベル変更
logging.getLogger("app").setLevel(logging.DEBUG)

# 特定モジュールだけ DEBUG に変更
logging.getLogger("app.payment").setLevel(logging.DEBUG)
```

- 本番環境で一時的に DEBUG レベルに変更する場合、自動で元に戻すタイマーを設けると安全

### リクエスト ID 追跡

- すべてのリクエストに一意な ID を付与し、ログ・レスポンスヘッダー・下流サービスに伝播する
- **分散トレーシングとの連携**:
  - OpenTelemetry の Trace ID / Span ID をログに含める
  - ログとトレースを紐付けることで、問題発生時の全体像を把握する

```python
# FastAPI ミドルウェアの例
import uuid
from contextvars import ContextVar

request_id_var: ContextVar[str] = ContextVar("request_id", default="")

@app.middleware("http")
async def add_request_id(request: Request, call_next):
    request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
    request_id_var.set(request_id)
    response = await call_next(request)
    response.headers["X-Request-ID"] = request_id
    return response
```

```go
// Go ミドルウェアの例
func RequestIDMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        requestID := r.Header.Get("X-Request-ID")
        if requestID == "" {
            requestID = uuid.New().String()
        }
        ctx := context.WithValue(r.Context(), "request_id", requestID)
        w.Header().Set("X-Request-ID", requestID)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}
```

- マイクロサービス間の呼び出しでは、リクエスト ID を HTTP ヘッダーで伝播する
- メッセージキュー経由の場合はメッセージ属性にリクエスト ID を含める

---

## DB デバッグ

### スロークエリ特定

- **PostgreSQL**:
  - `pg_stat_statements` 拡張でクエリ統計を取得する
  - `log_min_duration_statement` でスロークエリをログに記録する

```sql
-- スロークエリの統計を確認
SELECT query, calls, mean_exec_time, total_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 20;

-- 現在実行中のクエリを確認
SELECT pid, now() - pg_stat_activity.query_start AS duration, query, state
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY duration DESC;
```

- **MySQL**:
  - `slow_query_log` を有効にしてスロークエリを記録する
  - `performance_schema` でクエリ統計を取得する

```sql
-- スロークエリログの有効化
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 1; -- 1秒以上をスローとみなす

-- プロセスリストで実行中のクエリを確認
SHOW FULL PROCESSLIST;
```

### 実行計画の読み方

- `EXPLAIN ANALYZE` で実際の実行統計を含む実行計画を取得する

```sql
-- PostgreSQL
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) SELECT ...;

-- MySQL
EXPLAIN ANALYZE SELECT ...;
```

- **注目すべきポイント**:
  - **Seq Scan（全表スキャン）**: 大きなテーブルでの全表スキャンはインデックスの追加を検討する
  - **Nested Loop**: 内側のテーブルが大きい場合、Hash Join や Merge Join への切り替えを検討する
  - **Sort**: `work_mem` が不足してディスクソートになっていないか確認する
  - **Rows（推定行数）と Actual Rows**: 大きな乖離はテーブル統計の更新（`ANALYZE`）が必要
  - **Buffers**: shared hit（キャッシュヒット）と shared read（ディスク読み取り）の比率を確認する

### ロック待ち検出

- **PostgreSQL**:

```sql
-- ロック待ちの確認
SELECT
  blocked.pid AS blocked_pid,
  blocked.query AS blocked_query,
  blocking.pid AS blocking_pid,
  blocking.query AS blocking_query
FROM pg_catalog.pg_locks AS bl
JOIN pg_catalog.pg_stat_activity AS blocked ON bl.pid = blocked.pid
JOIN pg_catalog.pg_locks AS kl ON bl.transactionid = kl.transactionid AND bl.pid != kl.pid
JOIN pg_catalog.pg_stat_activity AS blocking ON kl.pid = blocking.pid
WHERE NOT bl.granted;
```

- **MySQL**:

```sql
-- InnoDB ロック待ちの確認
SELECT
  r.trx_id AS waiting_trx_id,
  r.trx_mysql_thread_id AS waiting_thread,
  r.trx_query AS waiting_query,
  b.trx_id AS blocking_trx_id,
  b.trx_mysql_thread_id AS blocking_thread,
  b.trx_query AS blocking_query
FROM information_schema.innodb_lock_waits AS w
JOIN information_schema.innodb_trx AS b ON b.trx_id = w.blocking_trx_id
JOIN information_schema.innodb_trx AS r ON r.trx_id = w.requesting_trx_id;
```

- **対策**:
  - トランザクションの範囲を最小限にする
  - ロック取得の順序を統一する（デッドロック防止）
  - `SELECT ... FOR UPDATE NOWAIT` でロック取得に失敗したら即座にエラーとする

### N+1 問題

- ORM のクエリログを有効にして、同一パターンのクエリが大量に発行されていないか確認する

```python
# SQLAlchemy でのクエリログ有効化
import logging
logging.getLogger('sqlalchemy.engine').setLevel(logging.INFO)
```

```go
// GORM でのログ有効化
db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
    Logger: logger.Default.LogMode(logger.Info),
})
```

- **解決パターン**:
  - **Eager Loading**: 関連データを事前に結合して取得する

```python
# SQLAlchemy: joinedload で関連を事前取得
users = session.query(User).options(joinedload(User.posts)).all()
```

```go
// GORM: Preload で関連を事前取得
var users []User
db.Preload("Posts").Find(&users)
```

  - **DataLoader パターン**: バッチ処理で複数の ID を一括取得する（GraphQL で特に有効）
  - **クエリカウンターミドルウェア**: リクエストあたりのクエリ数を計測し、閾値を超えた場合にアラートする

---

## 認証/認可デバッグ

### トークン検証フロー

- **JWT の検証手順**:
  1. トークンの構造（header.payload.signature）が正しいか確認する
  2. 署名の検証に使用する鍵（公開鍵 / 共有秘密鍵）が正しいか確認する
  3. `exp`（有効期限）、`nbf`（有効開始）、`iss`（発行者）、`aud`（対象者）のクレームを検証する
  4. トークンがブラックリストに登録されていないか確認する（リボケーション）

```python
# JWT デコードによるデバッグ（検証なし、デバッグ用途のみ）
import jwt
decoded = jwt.decode(token, options={"verify_signature": False})
print(f"Issuer: {decoded.get('iss')}")
print(f"Audience: {decoded.get('aud')}")
print(f"Expiry: {datetime.fromtimestamp(decoded.get('exp'))}")
print(f"Issued At: {datetime.fromtimestamp(decoded.get('iat'))}")
```

- **よくある問題**:
  - 署名アルゴリズムの不一致（RS256 と HS256 の混同）
  - 鍵のローテーション後に古い鍵で署名されたトークンが拒否される
  - クロック・スキューによる時刻検証の失敗（`leeway` パラメータで許容範囲を設定する）
  - OAuth2 / OIDC のリダイレクト URI の不一致

### 権限チェックの追跡

- 認可の判断ポイントに詳細なログを仕込み、どの段階で拒否されたかを特定する

```python
# ロールベース認可のデバッグログ
def check_permission(user, resource, action):
    logger.debug(f"Checking permission: user={user.id}, roles={user.roles}, "
                 f"resource={resource}, action={action}")

    # ロールの確認
    required_roles = get_required_roles(resource, action)
    logger.debug(f"Required roles: {required_roles}")

    has_permission = bool(set(user.roles) & set(required_roles))
    logger.debug(f"Permission {'granted' if has_permission else 'denied'}")

    return has_permission
```

- ABAC（属性ベースアクセス制御）の場合、ポリシー評価のトレースログを出力する
- OPA（Open Policy Agent）を使用している場合、`opa eval` コマンドでポリシーをローカル評価する

---

## 外部 API 連携デバッグ

### タイムアウト問題

- **切り分け手順**:
  1. 外部 API の応答時間をログで確認する
  2. ネットワークレベルの問題（DNS 解決、TCP 接続、TLS ハンドシェイク）を切り分ける
  3. 接続タイムアウトとリードタイムアウトを別々に設定する

```python
import httpx

# タイムアウトを細かく設定
timeout = httpx.Timeout(
    connect=5.0,   # TCP 接続確立のタイムアウト
    read=30.0,     # レスポンス読み取りのタイムアウト
    write=10.0,    # リクエスト書き込みのタイムアウト
    pool=5.0,      # コネクションプールからの取得タイムアウト
)
client = httpx.Client(timeout=timeout)
```

```go
client := &http.Client{
    Timeout: 30 * time.Second, // 全体タイムアウト
    Transport: &http.Transport{
        DialContext: (&net.Dialer{
            Timeout: 5 * time.Second, // TCP 接続タイムアウト
        }).DialContext,
        TLSHandshakeTimeout:   5 * time.Second,
        ResponseHeaderTimeout: 10 * time.Second,
        IdleConnTimeout:       90 * time.Second,
    },
}
```

### リトライ戦略

- **エクスポネンシャルバックオフ**: リトライ間隔を指数関数的に増やし、ジッターを加える

```python
import random
import time

def retry_with_backoff(func, max_retries=3, base_delay=1.0):
    for attempt in range(max_retries + 1):
        try:
            return func()
        except (ConnectionError, TimeoutError) as e:
            if attempt == max_retries:
                raise
            delay = base_delay * (2 ** attempt) + random.uniform(0, 1)
            logger.warning(f"Retry {attempt + 1}/{max_retries} after {delay:.1f}s: {e}")
            time.sleep(delay)
```

- **リトライ可能なエラーの判別**:
  - リトライ可能: 429 (Too Many Requests), 502, 503, 504, ネットワークエラー, タイムアウト
  - リトライ不可: 400, 401, 403, 404, 409, 422（クライアント起因のエラー）
- `Retry-After` ヘッダーが返される場合は、そのヘッダーの値を優先する

### サーキットブレーカー

- 外部サービスの障害時に呼び出しを遮断し、システム全体の連鎖障害を防ぐ
- **状態遷移**:
  - **Closed（通常）**: リクエストを通過させ、失敗回数を記録する
  - **Open（遮断）**: 失敗率が閾値を超えた場合、リクエストを即座に拒否する
  - **Half-Open（試行）**: 一定時間後に少数のリクエストを通過させ、回復を確認する
- **デバッグ時の確認ポイント**:
  - サーキットブレーカーの現在の状態（Closed / Open / Half-Open）
  - 失敗率の閾値と現在の失敗率
  - Open 状態への遷移タイミングと回復タイミング
  - フォールバック処理が正しく機能しているか

---

## メモリ/CPU 問題

### プロファイリング

- **Go**:

```go
import _ "net/http/pprof"

// HTTP サーバーに pprof エンドポイントを追加
go func() {
    log.Println(http.ListenAndServe("localhost:6060", nil))
}()
```

```bash
# CPU プロファイルの取得と可視化
go tool pprof http://localhost:6060/debug/pprof/profile?seconds=30
# (pprof) top 20
# (pprof) web  # ブラウザで可視化

# メモリプロファイルの取得
go tool pprof http://localhost:6060/debug/pprof/heap
# (pprof) top 20 -cum
```

- **Python**:

```python
# cProfile でプロファイリング
import cProfile
import pstats

profiler = cProfile.Profile()
profiler.enable()
# ... 計測対象のコード ...
profiler.disable()

stats = pstats.Stats(profiler)
stats.sort_stats('cumulative')
stats.print_stats(20)

# memory_profiler でメモリ使用量を計測
from memory_profiler import profile

@profile
def process_data():
    # ... メモリ使用量が行ごとに表示される ...
    pass
```

- **Node.js**:

```bash
# --inspect フラグで Chrome DevTools に接続
node --inspect app.js

# --prof フラグで V8 プロファイルを生成
node --prof app.js
node --prof-process isolate-*.log > profile.txt
```

### ヒープダンプ解析

- **Go**: `debug/pprof/heap` でヒープダンプを取得し、`go tool pprof` で解析する

```bash
# ヒープのアロケーション量を確認
go tool pprof -alloc_space http://localhost:6060/debug/pprof/heap
# (pprof) top 20

# goroutine の状態を確認
go tool pprof http://localhost:6060/debug/pprof/goroutine
```

- **Java**: `jmap` でヒープダンプを取得し、Eclipse MAT や VisualVM で解析する

```bash
# ヒープダンプの取得
jmap -dump:format=b,file=heapdump.hprof <PID>

# ヒストグラムで上位オブジェクトを確認
jmap -histo <PID> | head -30
```

- **共通の確認ポイント**:
  - メモリ使用量が時間とともに増加し続けるか（リーク）
  - 特定のオブジェクト種別が異常に多いか
  - GC の頻度と停止時間が許容範囲内か

---

## 並行処理デバッグ

### デッドロック

- **検出方法**:
  - アプリケーションが応答しなくなった場合、スレッド/goroutine のダンプを取得する
  - Go: `SIGQUIT` シグナルを送信して goroutine ダンプを出力する（`kill -QUIT <PID>`）
  - Java: `jstack <PID>` でスレッドダンプを取得する
  - Python: `faulthandler.enable()` を有効にして `SIGUSR1` でトレースバックを出力する

- **よくある原因**:
  - 複数のロックを異なる順序で取得する
  - チャネル操作でバッファなしチャネルの送受信が噛み合わない（Go）
  - データベースのトランザクション間でロック順序が統一されていない

```go
// 問題: ロック順序が異なる
// goroutine 1: mu1.Lock() -> mu2.Lock()
// goroutine 2: mu2.Lock() -> mu1.Lock()

// 解決: ロック順序を統一する
// goroutine 1: mu1.Lock() -> mu2.Lock()
// goroutine 2: mu1.Lock() -> mu2.Lock()
```

- Go の `-race` フラグでレースコンディションを検出する: `go test -race ./...`

### 競合状態

- **Go の Data Race Detector**:

```bash
# レースコンディション検出付きでビルド・テスト
go build -race ./...
go test -race ./...
```

```go
// 問題: 共有変数への同時アクセス
var counter int
go func() { counter++ }()
go func() { counter++ }()

// 解決1: Mutex で保護する
var mu sync.Mutex
var counter int
go func() { mu.Lock(); counter++; mu.Unlock() }()
go func() { mu.Lock(); counter++; mu.Unlock() }()

// 解決2: atomic パッケージを使用する
var counter int64
go func() { atomic.AddInt64(&counter, 1) }()
go func() { atomic.AddInt64(&counter, 1) }()

// 解決3: チャネルで通信する
ch := make(chan int, 2)
go func() { ch <- 1 }()
go func() { ch <- 1 }()
counter := <-ch + <-ch
```

### goroutine リーク

- **検出方法**: `runtime.NumGoroutine()` を定期的に計測し、単調増加していないか確認する

```go
// goroutine 数の監視
go func() {
    ticker := time.NewTicker(10 * time.Second)
    defer ticker.Stop()
    for range ticker.C {
        log.Printf("goroutine count: %d", runtime.NumGoroutine())
    }
}()
```

- **よくある原因と対策**:
  - チャネルの受信側が存在しない: `context.WithCancel` でキャンセルを伝播する
  - HTTP レスポンスボディを Close しない: `defer resp.Body.Close()` を忘れない
  - 無限ループの goroutine: `context.Done()` でループの終了条件を設ける

```go
// 問題: キャンセルされない goroutine
go func() {
    for {
        data := <-ch // ch が close されないと永遠にブロック
        process(data)
    }
}()

// 解決: context でキャンセルを伝播する
go func() {
    for {
        select {
        case data := <-ch:
            process(data)
        case <-ctx.Done():
            return
        }
    }
}()
```

- `goleak` パッケージをテストで使用して、goroutine リークを自動検出する

```go
func TestMain(m *testing.M) {
    goleak.VerifyTestMain(m)
}
```

---

## デプロイ関連問題

### 環境差異

- **「ローカルでは動くがステージング/本番では動かない」場合の確認ポイント**:
  - 環境変数の値が正しいか（特に接続先 URL、APIキー、シークレット）
  - ネットワーク到達性（VPC、セキュリティグループ、ファイアウォール）
  - ファイルシステムのパス（コンテナ環境ではローカルファイルが存在しない場合がある）
  - DNS 解決（内部 DNS と外部 DNS の違い）
  - タイムゾーンの違い（UTC vs ローカル時間）
  - OS / ランタイムのバージョン差異

- **Docker 環境の差異チェック**:

```bash
# ローカルと本番のイメージの差異を確認
docker inspect <image> | jq '.[0].Config.Env'
docker diff <container>

# コンテナ内からの接続テスト
docker exec -it <container> sh
curl -v http://internal-service:8080/health
nslookup internal-service
```

### 設定ミス

- **確認手順**:
  1. アプリケーションの起動ログで設定値の読み込みを確認する
  2. 環境変数の一覧を出力する（シークレットはマスクする）
  3. 設定ファイルのパスと内容を確認する
  4. デフォルト値が意図通りか確認する

```python
# 起動時に設定値をログ出力する（シークレットはマスク）
def log_config(config: dict):
    secret_keys = {"password", "secret", "api_key", "token"}
    for key, value in config.items():
        if any(s in key.lower() for s in secret_keys):
            logger.info(f"Config {key} = ****")
        else:
            logger.info(f"Config {key} = {value}")
```

- **よくある設定ミス**:
  - 環境変数名のタイポ（大文字/小文字の違い、アンダースコアの有無）
  - `.env` ファイルが `.gitignore` に含まれており、デプロイ時にコピーされていない
  - ConfigMap / Secret のマウントパスが誤っている（Kubernetes）
  - Feature Flag の状態が環境間で異なる

### マイグレーション失敗

- **事前チェック**:
  - マイグレーションがべき等か（再実行しても安全か）確認する
  - ロールバック手順を事前に用意する
  - 大きなテーブルへのマイグレーションはオンラインスキーマ変更ツールを検討する
    - PostgreSQL: `pg_repack`, `pgroll`
    - MySQL: `pt-online-schema-change`, `gh-ost`

- **失敗時の対応**:

```bash
# マイグレーション状態の確認
# Alembic (Python)
alembic current
alembic history

# golang-migrate
migrate -database "postgres://..." -path ./migrations version

# Rails
rails db:migrate:status
```

- **よくある問題**:
  - NOT NULL カラムの追加時にデフォルト値が未設定
  - 外部キー制約の追加時に既存データが制約に違反している
  - インデックスの作成が長時間ロックを取得する（`CREATE INDEX CONCURRENTLY` を使用する）
  - マイグレーションのバージョン番号が衝突している（チーム開発時）
  - トランザクション内で DDL を実行した場合のロールバック（MySQL は DDL の暗黙コミットに注意）
