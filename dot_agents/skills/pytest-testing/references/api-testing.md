# FastAPI / HTTP テストパターン詳細

## 目次

- [TestClient の基本パターン](#testclient-の基本パターン)
  - [Fixture による TestClient 共有](#fixture-による-testclient-共有)
  - [依存性のオーバーライド](#依存性のオーバーライド)
  - [エラーレスポンスのテスト](#エラーレスポンスのテスト)
- [非同期テスト（httpx.AsyncClient）](#非同期テスト（httpxasyncclient）)
  - [基本セットアップ](#基本セットアップ)
  - [conftest.py での anyio 設定](#conftestpy-での-anyio-設定)
  - [非同期 + 依存性オーバーライド](#非同期-依存性オーバーライド)
- [認証テストパターン](#認証テストパターン)
  - [JWT トークン Fixture](#jwt-トークン-fixture)
  - [ロールベーステスト（パラメータ化）](#ロールベーステスト（パラメータ化）)
- [CRUD テストパターン](#crud-テストパターン)
- [ファイルアップロードテスト](#ファイルアップロードテスト)
- [WebSocket テスト](#websocket-テスト)
- [レスポンス検証ヘルパー](#レスポンス検証ヘルパー)
- [外部 API モックパターン](#外部-api-モックパターン)
  - [respx を使った httpx モック](#respx-を使った-httpx-モック)
  - [responses を使った requests モック](#responses-を使った-requests-モック)

## TestClient の基本パターン

### Fixture による TestClient 共有

```python
import pytest
from fastapi.testclient import TestClient
from app.main import app

@pytest.fixture
def client():
    """テストごとに新しいクライアントを生成"""
    with TestClient(app) as c:
        yield c
```

### 依存性のオーバーライド

FastAPI の `dependency_overrides` を使って、テスト用のモックに差し替える。

```python
from app.main import app
from app.dependencies import get_db, get_current_user

@pytest.fixture
def client(db_session, test_user):
    def override_get_db():
        yield db_session

    def override_get_current_user():
        return test_user

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = override_get_current_user

    with TestClient(app) as c:
        yield c

    app.dependency_overrides.clear()

def test_get_my_profile(client, test_user):
    response = client.get("/users/me")
    assert response.status_code == 200
    assert response.json()["name"] == test_user.name
```

### エラーレスポンスのテスト

```python
def test_not_found(client):
    response = client.get("/items/99999")
    assert response.status_code == 404
    assert response.json() == {"detail": "Item not found"}

def test_validation_error(client):
    response = client.post("/items", json={"name": ""})
    assert response.status_code == 422
    errors = response.json()["detail"]
    assert any(e["loc"] == ["body", "name"] for e in errors)

def test_unauthorized_without_token(client):
    # dependency_overrides を設定しないクライアント
    with TestClient(app) as raw_client:
        response = raw_client.get("/users/me")
    assert response.status_code == 401
```

## 非同期テスト（httpx.AsyncClient）

### 基本セットアップ

```python
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app

@pytest.fixture
async def async_client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

@pytest.mark.anyio
async def test_async_get(async_client):
    response = await async_client.get("/")
    assert response.status_code == 200
```

### conftest.py での anyio 設定

```python
# tests/conftest.py
@pytest.fixture(scope="session")
def anyio_backend():
    return "asyncio"
```

### 非同期 + 依存性オーバーライド

```python
@pytest.fixture
async def async_client(async_db_session, test_user):
    async def override_get_db():
        yield async_db_session

    app.dependency_overrides[get_db] = override_get_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

    app.dependency_overrides.clear()

@pytest.mark.anyio
async def test_create_item(async_client):
    response = await async_client.post(
        "/items",
        json={"name": "New Item", "price": 500},
    )
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "New Item"
    assert "id" in data
```

## 認証テストパターン

### JWT トークン Fixture

```python
from app.auth import create_access_token

@pytest.fixture
def auth_headers(test_user) -> dict[str, str]:
    token = create_access_token(data={"sub": str(test_user.id)})
    return {"Authorization": f"Bearer {token}"}

@pytest.fixture
def admin_headers(admin_user) -> dict[str, str]:
    token = create_access_token(data={"sub": str(admin_user.id), "role": "admin"})
    return {"Authorization": f"Bearer {token}"}

def test_admin_only_endpoint(client, auth_headers, admin_headers):
    # 一般ユーザーはアクセス不可
    response = client.delete("/admin/users/1", headers=auth_headers)
    assert response.status_code == 403

    # 管理者はアクセス可能
    response = client.delete("/admin/users/1", headers=admin_headers)
    assert response.status_code == 200
```

### ロールベーステスト（パラメータ化）

```python
@pytest.mark.parametrize("role,expected_status", [
    ("admin", 200),
    ("editor", 200),
    ("viewer", 403),
    ("guest", 401),
])
def test_endpoint_access_by_role(client, create_user_with_role, role, expected_status):
    user = create_user_with_role(role)
    headers = get_auth_headers(user)
    response = client.get("/protected", headers=headers)
    assert response.status_code == expected_status
```

## CRUD テストパターン

```python
class TestItemCRUD:
    def test_create(self, client, auth_headers):
        response = client.post(
            "/items",
            json={"name": "Test Item", "price": 100},
            headers=auth_headers,
        )
        assert response.status_code == 201
        data = response.json()
        assert data["name"] == "Test Item"
        return data["id"]

    def test_read(self, client, auth_headers, create_item):
        item = create_item(name="Existing")
        response = client.get(f"/items/{item.id}", headers=auth_headers)
        assert response.status_code == 200
        assert response.json()["name"] == "Existing"

    def test_update(self, client, auth_headers, create_item):
        item = create_item(name="Before")
        response = client.put(
            f"/items/{item.id}",
            json={"name": "After", "price": 200},
            headers=auth_headers,
        )
        assert response.status_code == 200
        assert response.json()["name"] == "After"

    def test_delete(self, client, auth_headers, create_item):
        item = create_item(name="ToDelete")
        response = client.delete(f"/items/{item.id}", headers=auth_headers)
        assert response.status_code == 204

        response = client.get(f"/items/{item.id}", headers=auth_headers)
        assert response.status_code == 404

    def test_list_with_pagination(self, client, auth_headers, create_item):
        for i in range(15):
            create_item(name=f"Item {i}")

        response = client.get("/items?page=1&size=10", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert len(data["items"]) == 10
        assert data["total"] == 15
```

## ファイルアップロードテスト

```python
def test_upload_image(client, auth_headers, tmp_path):
    # テスト用画像ファイルを作成
    image_path = tmp_path / "test.png"
    image_path.write_bytes(b"\x89PNG\r\n\x1a\n" + b"\x00" * 100)

    with open(image_path, "rb") as f:
        response = client.post(
            "/upload",
            files={"file": ("test.png", f, "image/png")},
            headers=auth_headers,
        )
    assert response.status_code == 200
    assert response.json()["filename"] == "test.png"

def test_upload_rejects_large_file(client, auth_headers, tmp_path):
    large_file = tmp_path / "large.bin"
    large_file.write_bytes(b"\x00" * (10 * 1024 * 1024 + 1))  # 10MB超

    with open(large_file, "rb") as f:
        response = client.post(
            "/upload",
            files={"file": ("large.bin", f, "application/octet-stream")},
            headers=auth_headers,
        )
    assert response.status_code == 413
```

## WebSocket テスト

```python
def test_websocket_chat(client):
    with client.websocket_connect("/ws/chat") as ws:
        ws.send_json({"message": "Hello"})
        data = ws.receive_json()
        assert data["message"] == "Hello"
        assert "timestamp" in data

def test_websocket_authentication(client):
    # 認証なしで接続拒否
    with pytest.raises(Exception):
        with client.websocket_connect("/ws/chat") as ws:
            pass
```

## レスポンス検証ヘルパー

テストの可読性を高めるためのユーティリティ。

```python
# tests/helpers.py
from typing import Any

def assert_success_response(response, expected_data: dict | None = None):
    """成功レスポンスの共通検証"""
    assert response.status_code in (200, 201)
    data = response.json()
    if expected_data:
        for key, value in expected_data.items():
            assert data[key] == value, f"Expected {key}={value}, got {data[key]}"
    return data

def assert_error_response(response, status_code: int, detail: str | None = None):
    """エラーレスポンスの共通検証"""
    assert response.status_code == status_code
    if detail:
        assert response.json()["detail"] == detail

def assert_pagination_response(response, expected_total: int, page_size: int):
    """ページネーションレスポンスの検証"""
    data = response.json()
    assert len(data["items"]) <= page_size
    assert data["total"] == expected_total

# テスト側での利用
def test_create_item(client, auth_headers):
    response = client.post("/items", json={"name": "Test"}, headers=auth_headers)
    data = assert_success_response(response, {"name": "Test"})
    assert "id" in data
```

## 外部 API モックパターン

### respx を使った httpx モック

```python
import respx
from httpx import Response

@pytest.fixture
def mock_external_api():
    with respx.mock(assert_all_called=False) as respx_mock:
        respx_mock.get("https://api.example.com/data").mock(
            return_value=Response(200, json={"result": "ok"})
        )
        respx_mock.post("https://api.example.com/webhook").mock(
            return_value=Response(202)
        )
        yield respx_mock

@pytest.mark.anyio
async def test_calls_external_api(async_client, mock_external_api):
    response = await async_client.post("/trigger-sync")
    assert response.status_code == 200
    assert mock_external_api["https://api.example.com/data"].called
```

### responses を使った requests モック

```python
import responses

@responses.activate
def test_fetch_external_data(client, auth_headers):
    responses.add(
        responses.GET,
        "https://api.example.com/users",
        json=[{"id": 1, "name": "External User"}],
        status=200,
    )

    response = client.get("/sync-external-users", headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["synced_count"] == 1
```
