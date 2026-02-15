# Fixture パターン詳細

## 目次

- [DB Fixture パターン](#db-fixture-パターン)
  - [トランザクションロールバック方式](#トランザクションロールバック方式)
  - [async DB セッション（SQLAlchemy 2.0）](#async-db-セッション（sqlalchemy-20）)
- [Factory Fixture パターン](#factory-fixture-パターン)
  - [基本パターン](#基本パターン)
  - [関連エンティティを含むファクトリ](#関連エンティティを含むファクトリ)
- [パラメータ化 + Fixture の組み合わせ](#パラメータ化-fixture-の組み合わせ)
  - [indirect パラメータ化](#indirect-パラメータ化)
  - [request.param を使ったカスタマイズ](#requestparam-を使ったカスタマイズ)
- [Fixture 合成パターン](#fixture-合成パターン)
- [tmp_path / tmp_path_factory の活用](#tmp_path-tmp_path_factory-の活用)
- [Fixture のスコープと実行順序](#fixture-のスコープと実行順序)
  - [スコープ選択の指針](#スコープ選択の指針)
  - [注意事項](#注意事項)

## DB Fixture パターン

### トランザクションロールバック方式

テストごとにトランザクションを開始し、終了時にロールバックすることで DB を汚染しない。

```python
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session

@pytest.fixture(scope="session")
def engine():
    """テストセッション全体で1つのエンジンを共有"""
    engine = create_engine("sqlite:///test.db")
    Base.metadata.create_all(engine)
    yield engine
    Base.metadata.drop_all(engine)
    engine.dispose()

@pytest.fixture(scope="session")
def session_factory(engine):
    return sessionmaker(bind=engine)

@pytest.fixture
def db_session(session_factory) -> Session:
    """各テストでトランザクションをロールバック"""
    session = session_factory()
    session.begin_nested()  # SAVEPOINT
    yield session
    session.rollback()
    session.close()
```

### async DB セッション（SQLAlchemy 2.0）

```python
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

@pytest.fixture(scope="session")
def anyio_backend():
    return "asyncio"

@pytest.fixture(scope="session")
async def async_engine():
    engine = create_async_engine("sqlite+aiosqlite:///test.db")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()

@pytest.fixture
async def async_db_session(async_engine) -> AsyncSession:
    async_session = async_sessionmaker(async_engine, expire_on_commit=False)
    async with async_session() as session:
        async with session.begin():
            yield session
            await session.rollback()
```

## Factory Fixture パターン

Fixture 内でファクトリ関数を返し、テスト側でカスタマイズしてオブジェクトを生成する。

### 基本パターン

```python
@pytest.fixture
def create_user(db_session):
    """ユーザー生成ファクトリ"""
    created_users = []

    def _create_user(
        name: str = "Test User",
        email: str | None = None,
        is_active: bool = True,
    ) -> User:
        email = email or f"{name.lower().replace(' ', '.')}@example.com"
        user = User(name=name, email=email, is_active=is_active)
        db_session.add(user)
        db_session.flush()
        created_users.append(user)
        return user

    yield _create_user

    # teardown: 必要に応じてクリーンアップ
    for user in created_users:
        db_session.delete(user)

# テスト側
def test_active_users_only(create_user):
    create_user(name="Active", is_active=True)
    create_user(name="Inactive", is_active=False)

    result = UserService().get_active_users()
    assert len(result) == 1
    assert result[0].name == "Active"
```

### 関連エンティティを含むファクトリ

```python
@pytest.fixture
def create_order(create_user, db_session):
    def _create_order(
        user: User | None = None,
        items: list[dict] | None = None,
        status: str = "pending",
    ) -> Order:
        user = user or create_user()
        order = Order(user_id=user.id, status=status)
        db_session.add(order)
        db_session.flush()

        for item_data in (items or [{"name": "Default Item", "price": 100}]):
            item = OrderItem(order_id=order.id, **item_data)
            db_session.add(item)
        db_session.flush()
        return order

    return _create_order

def test_order_total(create_order):
    order = create_order(items=[
        {"name": "A", "price": 100},
        {"name": "B", "price": 200},
    ])
    assert order.total == 300
```

## パラメータ化 + Fixture の組み合わせ

### indirect パラメータ化

Fixture にパラメータを渡してテストケースを生成する。

```python
@pytest.fixture
def user_with_role(request, db_session):
    """ロールに応じたユーザーを生成"""
    role = request.param
    user = User(name=f"{role}_user", role=role)
    db_session.add(user)
    db_session.flush()
    return user

@pytest.mark.parametrize("user_with_role", ["admin", "editor", "viewer"], indirect=True)
def test_user_permissions(user_with_role):
    permissions = get_permissions(user_with_role)
    assert len(permissions) > 0
```

### request.param を使ったカスタマイズ

```python
@pytest.fixture
def configured_client(request):
    """パラメータでクライアント設定を変更"""
    timeout = getattr(request, "param", {}).get("timeout", 30)
    retries = getattr(request, "param", {}).get("retries", 3)
    return APIClient(timeout=timeout, retries=retries)

@pytest.mark.parametrize(
    "configured_client",
    [{"timeout": 5, "retries": 1}, {"timeout": 60, "retries": 5}],
    indirect=True,
)
def test_client_config(configured_client):
    assert configured_client.timeout in (5, 60)
```

## Fixture 合成パターン

小さな Fixture を組み合わせて複雑なセットアップを構築する。

```python
@pytest.fixture
def base_config():
    return {"debug": False, "log_level": "INFO"}

@pytest.fixture
def db_config():
    return {"db_url": "sqlite:///test.db", "pool_size": 5}

@pytest.fixture
def app_config(base_config, db_config):
    """複数の設定を合成"""
    return {**base_config, **db_config}

@pytest.fixture
def app(app_config):
    """合成された設定でアプリを初期化"""
    application = create_app(app_config)
    yield application
    application.shutdown()
```

## tmp_path / tmp_path_factory の活用

```python
@pytest.fixture
def sample_csv(tmp_path):
    """テスト用 CSV ファイルを生成"""
    csv_file = tmp_path / "data.csv"
    csv_file.write_text("name,age\nTaro,25\nHanako,30\n")
    return csv_file

def test_read_csv(sample_csv):
    result = read_csv(sample_csv)
    assert len(result) == 2
    assert result[0]["name"] == "Taro"

@pytest.fixture(scope="session")
def shared_data_dir(tmp_path_factory):
    """セッション全体で共有する一時ディレクトリ"""
    return tmp_path_factory.mktemp("shared_data")
```

## Fixture のスコープと実行順序

```
session scope  ──┐
  module scope ──┤ 外側から順に setup
    class scope ──┤
      function scope ──┘ テスト実行
      function scope ──┐
    class scope ──┤ 内側から順に teardown
  module scope ──┤
session scope  ──┘
```

### スコープ選択の指針

| スコープ | 用途 | 例 |
|---------|------|-----|
| `function` | テストごとに独立したデータが必要 | テスト用レコード、一時ファイル |
| `class` | 同一クラス内で共有可能 | テストクラス共通の設定 |
| `module` | 同一ファイル内で共有可能 | DB接続、外部サービスモック |
| `session` | 全テストで共有可能 | アプリ設定、エンジン初期化 |

### 注意事項

- 広い scope の Fixture が狭い scope の Fixture に依存するとエラーになる
  - NG: `scope="session"` の Fixture が `scope="function"` の Fixture を要求
- `autouse=True` は慎重に使用する（意図しないテストに影響する場合がある）
- Factory パターンを使えば、session scope でもテストごとに異なるデータを生成可能
