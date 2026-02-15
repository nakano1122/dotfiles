---
name: pytest-testing
description: "pytest を使った Python テストの包括的な実装ガイド。設定（pyproject.toml, conftest.py）、テストの書き方、Fixtures（scope, yield, autouse）、パラメータ化、モック（unittest.mock, pytest-mock, monkeypatch）、FastAPIテスト（TestClient, httpx.AsyncClient）、カバレッジ、マーカーをカバー。pytestでのテスト実装時に使用。"
---

# pytest テスト実装ガイド

## ワークフロー

1. **テスト対象の確認** - 対象コードの構造・依存関係を把握
2. **テストファイル作成** - `tests/` 配下に `test_*.py` を配置
3. **Fixture 設計** - 共通のセットアップを Fixture として抽出
4. **テスト実装** - Arrange-Act-Assert パターンで記述
5. **カバレッジ確認** - `pytest --cov` で網羅率を確認
6. **リファクタリング** - 重複排除、パラメータ化の適用

## pytest 設定

### pyproject.toml

```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py"]
python_functions = ["test_*"]
addopts = "-v --strict-markers --tb=short"
markers = [
    "slow: 実行に時間がかかるテスト",
    "integration: 結合テスト",
]
filterwarnings = ["error", "ignore::DeprecationWarning"]

[tool.coverage.run]
source = ["src"]
omit = ["*/tests/*", "*/migrations/*"]

[tool.coverage.report]
fail_under = 80
show_missing = true
exclude_lines = ["pragma: no cover", "if TYPE_CHECKING:"]
```

### conftest.py の配置

```
project/
  tests/
    conftest.py          # プロジェクト共通 Fixture
    unit/
      conftest.py        # ユニットテスト共通
      test_service.py
    integration/
      conftest.py        # 結合テスト共通
      test_api.py
```

## テストの書き方

### 基本構造（AAA パターン）

```python
def test_create_user_with_valid_data():
    # Arrange
    user_data = {"name": "Taro", "email": "taro@example.com"}
    # Act
    user = create_user(**user_data)
    # Assert
    assert user.name == "Taro"
    assert user.email == "taro@example.com"
```

### クラスによるグルーピングと例外テスト

```python
class TestUserService:
    def test_create_returns_user(self):
        result = UserService().create(name="Taro")
        assert isinstance(result, User)

    def test_create_raises_on_duplicate(self):
        with pytest.raises(DuplicateError, match="既に存在"):
            UserService().create(name="existing")

def test_validation_error_message():
    with pytest.raises(ValueError, match=r"invalid.*email"):
        validate_email("not-an-email")
```

## Fixtures

### 基本と scope

```python
@pytest.fixture  # scope="function" がデフォルト
def user():
    return User(name="Taro", email="taro@example.com")

@pytest.fixture(scope="module")
def db_connection():
    conn = create_connection()
    yield conn
    conn.close()

@pytest.fixture(scope="session")
def app_config():
    return load_config("test")
```

scope: `function` < `class` < `module` < `package` < `session`

### yield Fixture（setup/teardown）

```python
@pytest.fixture
def tmp_database(tmp_path):
    db = Database(tmp_path / "test.db")
    db.create_tables()
    yield db          # テストに制御を渡す
    db.drop_tables()  # teardown
    db.close()
```

### autouse と conftest.py での共有

```python
@pytest.fixture(autouse=True)
def reset_cache():
    cache.clear()
    yield
    cache.clear()

# tests/conftest.py - 全テストで利用可能
@pytest.fixture
def api_client():
    return TestClient(app)

@pytest.fixture
def auth_headers(test_user):
    token = create_token(test_user.id)
    return {"Authorization": f"Bearer {token}"}
```

詳細パターンは `references/fixture-patterns.md` を参照。

## パラメータ化テスト

```python
@pytest.mark.parametrize("input_val,expected", [
    ("hello", "HELLO"),
    ("world", "WORLD"),
    ("", ""),
])
def test_to_upper(input_val, expected):
    assert to_upper(input_val) == expected

# 複数パラメータの組み合わせ（4通り実行）
@pytest.mark.parametrize("x", [1, 2])
@pytest.mark.parametrize("y", [10, 20])
def test_multiply(x, y):
    assert multiply(x, y) == x * y
```

## モック

### unittest.mock

```python
from unittest.mock import patch, MagicMock

@patch("app.service.send_email")
def test_register_sends_email(mock_send):
    register_user("taro@example.com")
    mock_send.assert_called_once_with("taro@example.com", subject="Welcome")

@patch("app.service.ExternalAPI")
def test_fetch_data(MockAPI):
    MockAPI.return_value.get.return_value = {"key": "value"}
    result = fetch_data()
    assert result == {"key": "value"}
```

### pytest-mock（mocker Fixture）

```python
def test_service_calls_repository(mocker):
    mock_repo = mocker.patch("app.service.UserRepository")
    mock_repo.return_value.find.return_value = User(name="Taro")
    result = UserService().get_user(1)
    assert result.name == "Taro"
    mock_repo.return_value.find.assert_called_once_with(1)
```

### monkeypatch

```python
def test_with_env_var(monkeypatch):
    monkeypatch.setenv("API_KEY", "test-key-123")
    assert get_api_key() == "test-key-123"

def test_with_patched_attr(monkeypatch):
    monkeypatch.setattr("app.config.DEBUG", True)
    assert is_debug_mode() is True

def test_disable_network(monkeypatch):
    monkeypatch.setattr("requests.get", lambda *a, **k: (_ for _ in ()).throw(ConnectionError))
```

## FastAPI テスト

### 同期テスト（TestClient）

```python
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_read_root():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "Hello"}

def test_create_item():
    response = client.post("/items", json={"name": "Item1", "price": 100})
    assert response.status_code == 201
```

### 非同期テスト（httpx.AsyncClient）

```python
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app

@pytest.mark.anyio
async def test_async_root():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        response = await ac.get("/")
    assert response.status_code == 200
```

詳細パターンは `references/api-testing.md` を参照。

## カバレッジ設定（pytest-cov）

```bash
pytest --cov=src --cov-report=term-missing          # 基本
pytest --cov=src --cov-report=html                   # HTML レポート
pytest --cov=src --cov-fail-under=80                 # 閾値チェック
```

## マーカーとテスト分類

```python
@pytest.mark.slow
def test_heavy_computation():
    assert compute_large_dataset() is not None

@pytest.mark.skip(reason="外部APIが未準備")
def test_external_api(): ...

@pytest.mark.skipif(sys.platform == "win32", reason="Linux専用")
def test_linux_only(): ...

@pytest.mark.xfail(reason="既知のバグ #123")
def test_known_bug():
    assert buggy_function() == "expected"
```

```bash
pytest -m "not slow"                                 # マーカーフィルタ
pytest -m "integration"
pytest -k "test_user and not test_user_delete"       # キーワードフィルタ
```

## レビューチェックリスト

- [ ] テスト名が振る舞いを説明（`test_<何を>_<条件>_<期待結果>`）
- [ ] AAA パターンで構造化されている
- [ ] 1テスト = 1アサーション（論理的な単位）
- [ ] Fixture の scope が適切（不要に広い scope を避ける）
- [ ] モックの対象が正しい（利用側のパスで patch）
- [ ] パラメータ化で重複テストを削減
- [ ] エッジケース（空文字、None、境界値）をカバー
- [ ] テスト間に依存関係がない（実行順序に非依存）
- [ ] CI 環境で安定動作（外部依存をモック化）

## リファレンス

- [pytest 公式](https://docs.pytest.org/) / [pytest-mock](https://pytest-mock.readthedocs.io/) / [pytest-cov](https://pytest-cov.readthedocs.io/)
- [FastAPI Testing](https://fastapi.tiangolo.com/tutorial/testing/) / [httpx AsyncClient](https://www.python-httpx.org/async/)
- `references/fixture-patterns.md` - Fixture パターン詳細
- `references/api-testing.md` - FastAPI/HTTP テストパターン詳細
