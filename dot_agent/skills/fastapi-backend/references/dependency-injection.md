# FastAPI 依存性注入パターン詳細

## 目次

- [概要](#概要)
- [基本パターン](#基本パターン)
  - [関数型依存性](#関数型依存性)
  - [クラス型依存性](#クラス型依存性)
- [yield 依存性（リソース管理）](#yield-依存性リソース管理)
  - [yield 依存性の重要な注意点](#yield-依存性の重要な注意点)
- [サブ依存性（依存性の連鎖）](#サブ依存性依存性の連鎖)
  - [依存性のキャッシュ](#依存性のキャッシュ)
- [認証・認可の DI パターン](#認証認可の-di-パターン)
  - [基本的な認証依存性](#基本的な認証依存性)
  - [ロールベース認可（パラメータ付き依存性）](#ロールベース認可パラメータ付き依存性)
  - [パーミッションベース認可](#パーミッションベース認可)
- [ルーターレベルの依存性](#ルーターレベルの依存性)
  - [アプリケーションレベルの依存性](#アプリケーションレベルの依存性)
- [テストでの依存性オーバーライド](#テストでの依存性オーバーライド)
- [Annotated を使った依存性の型エイリアス](#annotated-を使った依存性の型エイリアス)
- [アンチパターンと注意点](#アンチパターンと注意点)
  - [グローバル状態の回避](#グローバル状態の回避)
  - [同期関数と非同期関数の混在](#同期関数と非同期関数の混在)
  - [循環依存の回避](#循環依存の回避)

## 概要

FastAPI の依存性注入（DI）は `Depends()` を中心とした仕組みで、コードの再利用性・テスタビリティ・関心の分離を実現する。本ドキュメントでは実践的な DI パターンを網羅する。

## 基本パターン

### 関数型依存性

最もシンプルな形。関数を `Depends()` に渡す。

```python
from fastapi import Depends

async def common_parameters(skip: int = 0, limit: int = 100) -> dict:
    return {"skip": skip, "limit": limit}

@router.get("/items")
async def list_items(params: dict = Depends(common_parameters)):
    return get_items(params["skip"], params["limit"])
```

### クラス型依存性

型アノテーションだけで DI が機能する。クエリパラメータの再利用に便利。

```python
class Pagination:
    def __init__(self, skip: int = 0, limit: int = Query(100, le=1000)):
        self.skip = skip
        self.limit = limit

@router.get("/users")
async def list_users(pagination: Pagination = Depends()):
    # Depends() の引数を省略するとアノテーションの型が使われる
    return await repo.find_all(pagination.skip, pagination.limit)
```

## yield 依存性（リソース管理）

`yield` を使うと、レスポンス送信後にクリーンアップ処理を実行できる。DB セッション、ファイルハンドル、外部接続などのリソース管理に使用する。

```python
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise

# ファイルリソースの例
async def get_temp_file() -> AsyncGenerator[Path, None]:
    path = Path(tempfile.mktemp())
    try:
        yield path
    finally:
        path.unlink(missing_ok=True)
```

### yield 依存性の重要な注意点

- `yield` 後のコードは**レスポンス送信後**に実行される
- `yield` 前の例外は通常のエラーレスポンスになる
- `yield` 後の例外はクライアントには伝わらない（レスポンス送信済み）
- `finally` ブロックは常に実行される

## サブ依存性（依存性の連鎖）

依存性は他の依存性に依存できる。FastAPI が依存性グラフを自動解決する。

```python
# レベル 1: DB セッション
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session() as session:
        yield session

# レベル 2: リポジトリ（DB に依存）
async def get_user_repo(db: AsyncSession = Depends(get_db)) -> UserRepository:
    return UserRepository(db)

# レベル 3: サービス（リポジトリに依存）
async def get_user_service(
    repo: UserRepository = Depends(get_user_repo),
    settings: Settings = Depends(get_settings),
) -> UserService:
    return UserService(repo, settings)

# エンドポイントではサービスだけを受け取る
@router.post("/users")
async def create_user(
    user: UserCreate,
    service: UserService = Depends(get_user_service),
):
    return await service.create(user)
```

### 依存性のキャッシュ

同一リクエスト内で同じ依存性が複数回参照されても、**1回だけ実行**される。これにより DB セッションの共有が自然に実現する。

```python
# get_db は 1 リクエスト内で 1 回だけ呼ばれる
async def get_user_repo(db: AsyncSession = Depends(get_db)) -> UserRepository:
    return UserRepository(db)

async def get_order_repo(db: AsyncSession = Depends(get_db)) -> OrderRepository:
    return OrderRepository(db)  # 同じ db セッションが渡される

@router.post("/checkout")
async def checkout(
    user_repo: UserRepository = Depends(get_user_repo),
    order_repo: OrderRepository = Depends(get_order_repo),
):
    # user_repo と order_repo は同じ DB セッションを共有
    ...
```

キャッシュを無効化したい場合は `Depends(get_db, use_cache=False)` を使う。

## 認証・認可の DI パターン

### 基本的な認証依存性

```python
from fastapi.security import OAuth2PasswordBearer

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")

async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=["HS256"])
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")
    user = await db.get(User, payload["sub"])
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return user
```

### ロールベース認可（パラメータ付き依存性）

関数を返す関数で、パラメータ付きの依存性を作成する。

```python
def require_role(*allowed_roles: str):
    """指定ロールを持つユーザーのみ許可する依存性ファクトリ"""
    async def role_checker(
        current_user: User = Depends(get_current_user),
    ) -> User:
        if current_user.role not in allowed_roles:
            raise HTTPException(
                status_code=403,
                detail=f"Role '{current_user.role}' is not authorized",
            )
        return current_user
    return role_checker

# 使用例
@router.delete("/users/{user_id}")
async def delete_user(
    user_id: int,
    admin: User = Depends(require_role("admin")),
):
    ...

@router.put("/articles/{article_id}")
async def update_article(
    article_id: int,
    user: User = Depends(require_role("admin", "editor")),
):
    ...
```

### パーミッションベース認可

```python
def require_permission(*permissions: str):
    async def checker(user: User = Depends(get_current_user)) -> User:
        user_permissions = set(user.permissions)
        required = set(permissions)
        if not required.issubset(user_permissions):
            missing = required - user_permissions
            raise HTTPException(
                status_code=403,
                detail=f"Missing permissions: {missing}",
            )
        return user
    return checker

@router.post("/reports")
async def create_report(
    user: User = Depends(require_permission("reports:create")),
):
    ...
```

## ルーターレベルの依存性

ルーター全体に共通の依存性を適用できる。

```python
# ルーター内の全エンドポイントに認証を適用
admin_router = APIRouter(
    prefix="/admin",
    tags=["admin"],
    dependencies=[Depends(require_role("admin"))],
)

@admin_router.get("/dashboard")
async def admin_dashboard():
    # require_role("admin") が自動適用される
    ...
```

### アプリケーションレベルの依存性

```python
# 全エンドポイントに適用
app = FastAPI(dependencies=[Depends(verify_api_key)])
```

## テストでの依存性オーバーライド

```python
from fastapi.testclient import TestClient

# テスト用の依存性
async def override_get_db():
    async with test_session() as session:
        yield session

async def override_get_current_user():
    return User(id=1, name="Test User", role="admin")

# オーバーライド適用
app.dependency_overrides[get_db] = override_get_db
app.dependency_overrides[get_current_user] = override_get_current_user

# pytest fixture パターン
@pytest.fixture
def client():
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()
```

## Annotated を使った依存性の型エイリアス

Python 3.9+ / FastAPI 0.95+ で推奨されるパターン。

```python
from typing import Annotated

# 型エイリアスとして依存性を定義
DbSession = Annotated[AsyncSession, Depends(get_db)]
CurrentUser = Annotated[User, Depends(get_current_user)]
AdminUser = Annotated[User, Depends(require_role("admin"))]

# エンドポイントがシンプルになる
@router.get("/users/me")
async def get_me(user: CurrentUser):
    return user

@router.post("/users")
async def create_user(
    user: UserCreate,
    db: DbSession,
    current_user: AdminUser,
):
    ...
```

`Annotated` を使うメリット:
- エンドポイントのシグネチャが簡潔になる
- 依存性の定義を一箇所で管理できる
- IDE の型推論が正しく機能する

## アンチパターンと注意点

### グローバル状態の回避

```python
# NG: グローバル変数で状態を共有
db_session = None  # リクエスト間で共有されてしまう

# OK: yield 依存性でリクエストスコープを確保
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session() as session:
        yield session
```

### 同期関数と非同期関数の混在

```python
# 同期依存性も利用可能（FastAPI がスレッドプールで実行）
def get_settings() -> Settings:
    return Settings()

# ただし I/O を含む場合は async を推奨
async def get_external_data() -> dict:
    async with httpx.AsyncClient() as client:
        resp = await client.get("https://api.example.com/data")
        return resp.json()
```

### 循環依存の回避

依存性グラフが循環しないよう設計する。循環する場合はサービス層の責務を見直す。

```python
# NG: A → B → A の循環
# OK: A → B, A → C, B → C の DAG 構造
```
