# よくあるエラーパターンと解決策

## 目次

- [JavaScript/TypeScript エラー](#javascripttypescript-エラー)
  - [TypeError](#typeerror)
  - [ReferenceError](#referenceerror)
  - [Promise rejection（未処理）](#promise-rejection未処理)
  - [import/export エラー](#importexport-エラー)
- [Python エラー](#python-エラー)
  - [ImportError / ModuleNotFoundError](#importerror--modulenotfounderror)
  - [AttributeError](#attributeerror)
  - [非同期処理エラー](#非同期処理エラー)
- [Go エラー](#go-エラー)
  - [nil pointer dereference](#nil-pointer-dereference)
  - [goroutine リーク](#goroutine-リーク)
  - [interface assertion 失敗](#interface-assertion-失敗)
- [HTTP 通信エラー](#http-通信エラー)
  - [CORS（Cross-Origin Resource Sharing）](#corscross-origin-resource-sharing)
  - [Mixed Content](#mixed-content)
  - [CSP（Content Security Policy）違反](#cspcontent-security-policy違反)
- [DB エラー](#db-エラー)
  - [connection refused / connection timeout](#connection-refused--connection-timeout)
  - [deadlock detected](#deadlock-detected)
  - [constraint violation](#constraint-violation)
  - [migration エラー](#migration-エラー)
- [環境・設定エラー](#環境設定エラー)
  - [環境変数の欠落](#環境変数の欠落)
  - [ポート競合](#ポート競合)
  - [パーミッションエラー](#パーミッションエラー)
- [ビルド/デプロイエラー](#ビルドデプロイエラー)
  - [依存関係の競合](#依存関係の競合)
  - [TypeScript の型エラー](#typescript-の型エラー)
  - [OOM（Out of Memory）](#oomout-of-memory)

## JavaScript/TypeScript エラー

### TypeError

- **`Cannot read properties of undefined/null`**
  - 原因: オブジェクトが `undefined` または `null` の状態でプロパティにアクセスしている
  - 解決: オプショナルチェーン (`?.`) を使用するか、事前に null チェックを行う

```javascript
// エラー
const name = user.profile.name; // user.profile が undefined

// 解決1: オプショナルチェーン
const name = user?.profile?.name;

// 解決2: デフォルト値を設定
const name = user?.profile?.name ?? 'Unknown';

// 解決3: 早期リターン
if (!user?.profile) {
  return;
}
const name = user.profile.name;
```

- **`X is not a function`**
  - 原因: 関数でないものを関数として呼び出している
  - よくあるケース:
    - インポートしたモジュールの名前を間違えている
    - `default` エクスポートと名前付きエクスポートを混同している
    - 非同期関数の戻り値（Promise）に直接メソッドを呼び出している

```javascript
// エラー: default export を named import で取得しようとしている
import { myFunction } from './module'; // module は default export のみ

// 解決
import myFunction from './module';
```

- **`Cannot assign to read only property`**
  - 原因: `Object.freeze()` されたオブジェクトや、Redux/Immer の frozen state を直接変更している
  - 解決: 新しいオブジェクトを作成して置き換える

### ReferenceError

- **`X is not defined`**
  - 原因: 変数が宣言される前に参照されている、またはスコープ外からアクセスしている
  - よくあるケース:
    - `let` / `const` の TDZ（Temporal Dead Zone）に触れている
    - ブラウザ固有の API をサーバーサイドで参照している（`window`, `document`）
    - 循環インポートにより変数が初期化前に参照されている

```javascript
// エラー: TDZ
console.log(value); // ReferenceError
let value = 10;

// エラー: SSR 環境で window を参照
const width = window.innerWidth; // サーバーサイドで ReferenceError

// 解決: 存在チェック
const width = typeof window !== 'undefined' ? window.innerWidth : 0;
```

### Promise rejection（未処理）

- **`Unhandled Promise Rejection`**
  - 原因: Promise チェーンに `.catch()` がない、または `async` 関数内の `await` にエラーハンドリングがない

```javascript
// 問題: catch がない
fetchData().then(data => process(data));

// 解決1: .catch() を追加
fetchData().then(data => process(data)).catch(err => handleError(err));

// 解決2: try-catch で囲む
async function loadData() {
  try {
    const data = await fetchData();
    process(data);
  } catch (err) {
    handleError(err);
  }
}
```

- **グローバルハンドラーで未処理の rejection を捕捉する**:

```javascript
// ブラウザ
window.addEventListener('unhandledrejection', event => {
  console.error('Unhandled rejection:', event.reason);
  event.preventDefault(); // デフォルトのコンソールエラーを抑制
});

// Node.js
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled rejection at:', promise, 'reason:', reason);
});
```

### import/export エラー

- **`SyntaxError: Cannot use import statement outside a module`**
  - 原因: ESM 構文を CommonJS 環境で使用している
  - 解決:
    - `package.json` に `"type": "module"` を追加する
    - ファイル拡張子を `.mjs` にする
    - `require()` に書き換える

- **`ERR_MODULE_NOT_FOUND` / `MODULE_NOT_FOUND`**
  - 原因: パスの誤り、拡張子の省略（ESM では拡張子必須）、パッケージ未インストール
  - 確認:
    - `node_modules` にパッケージが存在するか
    - `package.json` の依存関係に含まれているか
    - パスの大文字/小文字が正しいか（Linux では大文字小文字を区別）

- **TypeScript: `Cannot find module 'X' or its corresponding type declarations`**
  - 解決:
    - `@types/X` パッケージをインストールする
    - `declare module 'X'` で型宣言ファイルを作成する
    - `tsconfig.json` の `moduleResolution` と `paths` の設定を確認する

---

## Python エラー

### ImportError / ModuleNotFoundError

- **`ModuleNotFoundError: No module named 'X'`**
  - 確認手順:
    1. `pip list | grep X` でインストール済みか確認する
    2. `which python` / `python -c "import sys; print(sys.executable)"` で正しい Python を使っているか確認する
    3. 仮想環境が有効か確認する（`echo $VIRTUAL_ENV`）
    4. `pip install X` でインストールする

- **`ImportError: cannot import name 'Y' from 'X'`**
  - 原因:
    - パッケージのバージョンが古く、該当シンボルが存在しない
    - 循環インポートにより、シンボルが定義される前にインポートが実行されている
  - 循環インポートの解決:
    - インポートを関数内に移動する（遅延インポート）
    - モジュール構成を見直して依存関係を整理する
    - `TYPE_CHECKING` ガードを使用する

```python
from __future__ import annotations
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .other_module import OtherClass  # 型チェック時のみインポート
```

### AttributeError

- **`AttributeError: 'NoneType' object has no attribute 'X'`**
  - 原因: 関数が `None` を返しているのに、戻り値にアクセスしている
  - よくあるケース:
    - `list.sort()` や `list.append()` は `None` を返す（インプレース操作）
    - データベースクエリが結果なしで `None` を返す
    - 正規表現のマッチが `None` を返す

```python
# 問題: sort() は None を返す
sorted_list = my_list.sort()  # sorted_list は None
sorted_list[0]  # AttributeError

# 解決: sorted() を使用する
sorted_list = sorted(my_list)

# 問題: re.search が None を返す
match = re.search(r'(\d+)', text)
value = match.group(1)  # match が None の場合 AttributeError

# 解決: None チェック
match = re.search(r'(\d+)', text)
if match:
    value = match.group(1)
```

### 非同期処理エラー

- **`RuntimeError: This event loop is already running`**
  - 原因: Jupyter Notebook や既にイベントループが動作している環境で `asyncio.run()` を呼び出している
  - 解決: `nest_asyncio` を使用するか、`await` で直接呼び出す

```python
# Jupyter Notebook での解決
import nest_asyncio
nest_asyncio.apply()
```

- **`RuntimeWarning: coroutine 'X' was never awaited`**
  - 原因: `async` 関数を `await` なしで呼び出している

```python
# 問題: await がない
async def fetch_data():
    return await http_client.get("/api/data")

result = fetch_data()  # コルーチンオブジェクトが返るだけ

# 解決: await を付ける
result = await fetch_data()
```

- **`asyncio.TimeoutError`**
  - 解決: タイムアウト値を調整するか、`asyncio.wait_for` でタイムアウトを明示する

```python
try:
    result = await asyncio.wait_for(long_operation(), timeout=30.0)
except asyncio.TimeoutError:
    logger.error("Operation timed out after 30s")
    # フォールバック処理
```

---

## Go エラー

### nil pointer dereference

- **`runtime error: invalid memory address or nil pointer dereference`**
  - 原因: `nil` のポインタにアクセスしている
  - よくあるケース:
    - 関数がエラーとともに `nil` を返すが、エラーチェックをしていない
    - マップの値がゼロ値（ポインタ型の場合は `nil`）
    - インターフェース値が `nil`

```go
// 問題: エラーチェックなし
user, err := getUser(id)
fmt.Println(user.Name) // user が nil の場合 panic

// 解決: エラーチェック
user, err := getUser(id)
if err != nil {
    return fmt.Errorf("get user: %w", err)
}
fmt.Println(user.Name)

// 問題: マップの値がゼロ値
m := map[string]*Config{}
cfg := m["nonexistent"]
fmt.Println(cfg.Value) // cfg は nil

// 解決: 存在チェック
cfg, ok := m["nonexistent"]
if !ok {
    return errors.New("config not found")
}
```

### goroutine リーク

- **症状**: メモリ使用量が時間とともに増加し、`runtime.NumGoroutine()` が単調増加する
- **よくある原因**:

```go
// 問題1: チャネルの送信側がブロックされたまま
func process(ctx context.Context) {
    ch := make(chan int)
    go func() {
        result := heavyComputation()
        ch <- result // 受信側がいないとブロック
    }()
    select {
    case <-ctx.Done():
        return // goroutine がリークする
    case result := <-ch:
        use(result)
    }
}

// 解決: バッファ付きチャネルを使用する
ch := make(chan int, 1)

// 問題2: HTTP レスポンスボディの Close 忘れ
resp, err := http.Get(url)
if err != nil {
    return err
}
// resp.Body.Close() を忘れると接続がリークする

// 解決: defer で Close する
resp, err := http.Get(url)
if err != nil {
    return err
}
defer resp.Body.Close()
// エラーレスポンスでも Body を読み切って Close する
io.Copy(io.Discard, resp.Body)
```

### interface assertion 失敗

- **`interface conversion: interface {} is X, not Y`**
  - 原因: 型アサーションで実際の型と異なる型を指定している

```go
// 問題: 型アサーションが失敗して panic
var i interface{} = "hello"
n := i.(int) // panic

// 解決: comma-ok パターンを使用する
n, ok := i.(int)
if !ok {
    return errors.New("expected int")
}

// 型スイッチで複数の型を処理する
switch v := i.(type) {
case string:
    fmt.Println("string:", v)
case int:
    fmt.Println("int:", v)
default:
    fmt.Println("unknown type:", reflect.TypeOf(i))
}
```

---

## HTTP 通信エラー

### CORS（Cross-Origin Resource Sharing）

- **エラーメッセージ**: `Access to fetch at 'X' from origin 'Y' has been blocked by CORS policy`
- **原因と対策**:

| 状況 | 対策 |
|------|------|
| サーバーに CORS ヘッダーが未設定 | `Access-Control-Allow-Origin` を設定する |
| プリフライトリクエストが失敗 | OPTIONS メソッドへの応答に CORS ヘッダーを含める |
| カスタムヘッダーが許可されていない | `Access-Control-Allow-Headers` にヘッダーを追加する |
| 認証情報付きリクエストでワイルドカード使用 | 具体的なオリジンを指定する（`*` は使用不可） |

- **開発環境での一時的な回避策**:
  - フロントエンドの開発サーバーのプロキシ機能を使用する（Vite: `server.proxy`, webpack: `devServer.proxy`）
  - CORS ヘッダーを付与するリバースプロキシを挟む

### Mixed Content

- **エラーメッセージ**: `Mixed Content: The page at 'https://...' was loaded over HTTPS, but requested an insecure resource 'http://...'`
- **原因**: HTTPS ページから HTTP リソースを読み込もうとしている
- **対策**:
  - すべてのリソース URL を HTTPS に変更する
  - プロトコル相対 URL (`//example.com/...`) を使用する
  - `Content-Security-Policy: upgrade-insecure-requests` ヘッダーを設定する
  - `<meta http-equiv="Content-Security-Policy" content="upgrade-insecure-requests">` を追加する

### CSP（Content Security Policy）違反

- **エラーメッセージ**: `Refused to execute inline script because it violates the following Content Security Policy directive`
- **よくあるケースと対策**:

| 違反の種類 | CSP ディレクティブ | 対策 |
|-----------|-------------------|------|
| インラインスクリプト | `script-src` | nonce を付与するか、ハッシュを追加する |
| インラインスタイル | `style-src` | nonce を付与するか、外部ファイルにする |
| 外部スクリプト | `script-src` | ドメインをホワイトリストに追加する |
| 画像の読み込み | `img-src` | ドメインをホワイトリストに追加する |
| フォーム送信先 | `form-action` | 送信先ドメインを追加する |

```
Content-Security-Policy: default-src 'self';
  script-src 'self' 'nonce-abc123' https://cdn.example.com;
  style-src 'self' 'unsafe-inline';
  img-src 'self' data: https:;
  connect-src 'self' https://api.example.com;
```

- **Report-Only モード** で影響を事前に確認する:

```
Content-Security-Policy-Report-Only: default-src 'self'; report-uri /csp-report
```

---

## DB エラー

### connection refused / connection timeout

- **`connection refused`**:
  - DB サーバーが起動しているか確認する
  - ホスト名 / ポート番号が正しいか確認する
  - ファイアウォール / セキュリティグループでポートが開いているか確認する
  - DB サーバーのリッスンアドレスが適切か確認する（`listen_addresses` が `localhost` のみになっていないか）

```bash
# 接続確認
telnet db-host 5432
nc -zv db-host 5432
pg_isready -h db-host -p 5432
```

- **`connection timeout`**:
  - ネットワーク到達性を確認する（VPC, サブネット, ルートテーブル）
  - DNS 解決が正しいか確認する
  - コネクションプールが枯渇していないか確認する

```sql
-- PostgreSQL: 現在の接続数とmax接続数を確認
SELECT count(*) FROM pg_stat_activity;
SHOW max_connections;

-- MySQL: 接続数の確認
SHOW STATUS LIKE 'Threads_connected';
SHOW VARIABLES LIKE 'max_connections';
```

### deadlock detected

- **エラーメッセージ**: `ERROR: deadlock detected` / `Deadlock found when trying to get lock`
- **原因**: 2つ以上のトランザクションが互いにロックの解放を待っている
- **対策**:
  - ロック取得の順序を統一する（テーブル名のアルファベット順など）
  - トランザクションの範囲を最小限にする
  - `SELECT ... FOR UPDATE NOWAIT` / `FOR UPDATE SKIP LOCKED` を使用する
  - リトライロジックを実装する（デッドロックは一方のトランザクションが自動ロールバックされる）

```python
# デッドロック時のリトライ
from tenacity import retry, retry_if_exception_type, stop_after_attempt, wait_exponential

@retry(
    retry=retry_if_exception_type(DeadlockError),
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=0.1, max=2),
)
def transfer_funds(from_id, to_id, amount):
    with db.begin():
        # ロック順序を ID の昇順に統一
        ids = sorted([from_id, to_id])
        accounts = [get_account_for_update(id) for id in ids]
        # ... 送金処理 ...
```

### constraint violation

- **`unique constraint violation`（一意制約違反）**:
  - 重複する値を挿入しようとしている
  - 対策: `INSERT ... ON CONFLICT` (PostgreSQL) / `INSERT ... ON DUPLICATE KEY UPDATE` (MySQL) を使用する

```sql
-- PostgreSQL: UPSERT
INSERT INTO users (email, name)
VALUES ('user@example.com', 'User')
ON CONFLICT (email)
DO UPDATE SET name = EXCLUDED.name;

-- MySQL: UPSERT
INSERT INTO users (email, name)
VALUES ('user@example.com', 'User')
ON DUPLICATE KEY UPDATE name = VALUES(name);
```

- **`foreign key constraint violation`（外部キー制約違反）**:
  - 参照先のレコードが存在しないか、参照されているレコードを削除しようとしている
  - 対策: 参照先を先に作成する / `ON DELETE CASCADE` / `ON DELETE SET NULL` を設定する

- **`check constraint violation`（チェック制約違反）**:
  - カラムの値が制約条件を満たしていない
  - 対策: アプリケーション側でバリデーションを行い、DB 制約と整合させる

### migration エラー

- **`relation "X" already exists`**:
  - マイグレーションが中途半端な状態で停止し、再実行時にテーブルが既に存在する
  - 対策: マイグレーション状態を確認し、手動で修正するか、`IF NOT EXISTS` を使用する

- **`column "X" of relation "Y" does not exist`**:
  - マイグレーションの順序が正しくないか、マイグレーションがスキップされている
  - 対策: マイグレーション履歴テーブルを確認し、未適用のマイグレーションを順番に適用する

- **`cannot alter type of a column used by a view or rule`**:
  - ビューが参照しているカラムの型を変更しようとしている
  - 対策: ビューを一旦削除し、カラム変更後に再作成する

---

## 環境・設定エラー

### 環境変数の欠落

- **症状**: アプリケーション起動時にクラッシュするか、実行時に予期しない動作をする
- **対策**:
  - 起動時に必須環境変数の存在チェックを行う
  - `.env.example` ファイルで必要な環境変数を文書化する

```python
# Python: 必須環境変数のチェック
import os
import sys

REQUIRED_VARS = ["DATABASE_URL", "SECRET_KEY", "API_KEY"]

missing = [var for var in REQUIRED_VARS if not os.getenv(var)]
if missing:
    print(f"Missing required environment variables: {', '.join(missing)}", file=sys.stderr)
    sys.exit(1)
```

```go
// Go: 必須環境変数のチェック
func requireEnv(keys ...string) error {
    var missing []string
    for _, key := range keys {
        if os.Getenv(key) == "" {
            missing = append(missing, key)
        }
    }
    if len(missing) > 0 {
        return fmt.Errorf("missing required environment variables: %s", strings.Join(missing, ", "))
    }
    return nil
}
```

### ポート競合

- **エラーメッセージ**: `EADDRINUSE: address already in use` / `bind: address already in use`
- **確認と対処**:

```bash
# ポートを使用しているプロセスを特定する
# macOS / Linux
lsof -i :8080
# Linux
ss -tlnp | grep 8080
# Windows
netstat -ano | findstr :8080

# プロセスを終了する
kill <PID>
# 強制終了
kill -9 <PID>
```

- **対策**:
  - 開発環境では設定で代替ポートを指定可能にする
  - 前回のプロセスが正常終了していない場合は PID ファイルを確認する
  - Docker の場合、`docker ps` でコンテナの状態を確認する

### パーミッションエラー

- **`EACCES: permission denied`** / **`PermissionError`**
  - ファイル / ディレクトリのパーミッションを確認する

```bash
# パーミッション確認
ls -la /path/to/file
stat /path/to/file

# 所有者の変更
chown user:group /path/to/file

# パーミッションの変更
chmod 644 /path/to/file    # rw-r--r--
chmod 755 /path/to/dir     # rwxr-xr-x
```

- **Docker 環境でのよくある問題**:
  - コンテナ内のプロセスが root 以外のユーザーで実行されているが、ボリュームマウント先のファイルの所有者が異なる
  - 解決: `Dockerfile` でユーザーを作成し、ファイルの所有者を合わせる

```dockerfile
RUN adduser --disabled-password --gecos "" appuser
COPY --chown=appuser:appuser . /app
USER appuser
```

---

## ビルド/デプロイエラー

### 依存関係の競合

- **npm: `ERESOLVE unable to resolve dependency tree`**
  - 原因: パッケージ間のバージョン要件が矛盾している
  - 対処:

```bash
# 競合の詳細を確認
npm ls <package-name>

# 強制インストール（非推奨だが緊急時）
npm install --legacy-peer-deps

# lock ファイルを削除して再インストール
rm -rf node_modules package-lock.json
npm install

# 特定パッケージのバージョンを固定
npm install <package>@<version> --save-exact
```

- **Python: `ResolutionImpossible`** / **`pip` のバージョン競合**
  - 対処:

```bash
# 依存関係の確認
pip check
pipdeptree

# 仮想環境を作り直す
python -m venv .venv --clear
source .venv/bin/activate
pip install -r requirements.txt
```

- **Go: `go mod tidy` で解決しない場合**

```bash
# モジュールキャッシュをクリア
go clean -modcache

# 依存関係グラフを確認
go mod graph | grep <module>

# 特定バージョンを強制指定
go get <module>@<version>

# replace ディレクティブで上書き
# go.mod に以下を追加
# replace old/module => new/module v1.2.3
```

### TypeScript の型エラー

- **`Type 'X' is not assignable to type 'Y'`**
  - 原因: 型の不一致
  - 対処: 期待される型と実際の型を比較し、変換またはアサーションを行う

```typescript
// 問題: API レスポンスの型が不明
const data = await fetch('/api/users').then(r => r.json()); // any 型

// 解決: 型を定義してバリデーションする
interface User {
  id: string;
  name: string;
  email: string;
}

// Zod でランタイムバリデーション
import { z } from 'zod';
const UserSchema = z.object({
  id: z.string(),
  name: z.string(),
  email: z.string().email(),
});
const user = UserSchema.parse(data);
```

- **`Property 'X' does not exist on type 'Y'`**
  - 原因: 型定義にプロパティが含まれていない
  - 対処:
    - 型定義を更新する
    - 型拡張（Declaration Merging）を使用する
    - 型ガードで絞り込む

```typescript
// 型ガードで絞り込む
interface Dog { bark(): void; }
interface Cat { meow(): void; }

function isDog(animal: Dog | Cat): animal is Dog {
  return 'bark' in animal;
}

if (isDog(animal)) {
  animal.bark(); // 型エラーなし
}
```

### OOM（Out of Memory）

- **ビルド時の OOM**:
  - Node.js: `NODE_OPTIONS=--max-old-space-size=4096` でヒープサイズを拡大する
  - Docker: `docker build --memory=4g` でメモリ制限を設定する
  - Webpack: `--max-old-space-size` を設定するか、ビルドの並列度を下げる

```bash
# Node.js のメモリ上限を拡大
export NODE_OPTIONS="--max-old-space-size=4096"
npm run build
```

- **ランタイムの OOM**:
  - コンテナのメモリ制限を確認する（Kubernetes: `resources.limits.memory`）
  - メモリプロファイリングでリーク箇所を特定する
  - Go: `GOMEMLIMIT` 環境変数で GC のメモリターゲットを設定する
  - Java: `-Xmx` / `-Xms` でヒープサイズを調整する

```yaml
# Kubernetes のリソース設定
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

- **OOM Killer による強制終了の確認**:

```bash
# Linux: OOM Killer のログを確認
dmesg | grep -i "out of memory"
journalctl -k | grep -i "oom"

# Kubernetes: Pod の終了理由を確認
kubectl describe pod <pod-name> | grep -A5 "Last State"
# Reason: OOMKilled の場合、メモリ制限を超過している
```

- **対策の優先順位**:
  1. メモリリークを修正する（根本原因の解消）
  2. 大量データの処理をストリーミング / バッチ処理に変更する
  3. キャッシュの有効期限と最大サイズを設定する
  4. メモリ制限を適切な値に調整する（一時的な対処）
