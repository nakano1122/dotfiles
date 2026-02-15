---
name: fastapi-backend
description: "FastAPI (Python) バックエンドAPIの包括的な実装ガイド。プロジェクト構造、ルーティング（APIRouter）、依存性注入（Depends）、Pydanticモデル、バリデーション、エラーハンドリング、認証/認可実装、構造化ログ、非同期処理、ORM連携、環境設定（BaseSettings）をカバー。FastAPIでのAPI実装時に使用。"
---

# FastAPI バックエンド実装ガイド

## ワークフロー

1. **プロジェクト構造の確認** - 既存構造に従うか、新規なら推奨構造で作成
2. **環境設定の定義** - `BaseSettings` で設定クラスを作成
3. **Pydanticモデルの定義** - リクエスト/レスポンススキーマを定義
4. **依存性注入の設計** - DB セッション、認証、共通ロジックを DI で設計
5. **ルーティングの実装** - `APIRouter` でエンドポイントを実装
6. **エラーハンドリングの実装** - カスタム例外とハンドラを設定
7. **テストの作成** - `httpx.AsyncClient` + `pytest-asyncio` でテスト

## プロジェクト構造

```
app/
├── main.py            # FastAPI 初期化、lifespan、router 登録
├── config.py          # BaseSettings
├── dependencies.py    # 共通 DI
├── exceptions.py      # カスタム例外・ハンドラ
├── models/            # SQLAlchemy モデル
├── schemas/           # Pydantic スキーマ
├── routers/           # APIRouter モジュール
├── services/          # ビジネスロジック
├── db/session.py      # DB 接続・セッション管理
└── tests/
```

```python
from fastapi import FastAPI
from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    yield  # 起動/終了処理を yield の前後に記述

app = FastAPI(title="My API", lifespan=lifespan)
app.include_router(users_router, prefix="/api/v1")
```

## ルーティング

```python
from fastapi import APIRouter, Path, Query, status

router = APIRouter(prefix="/users", tags=["users"])

@router.get("/", response_model=list[UserResponse])
async def list_users(skip: int = Query(0, ge=0), limit: int = Query(100, le=1000)):
    ...

@router.post("/", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def create_user(user: UserCreate):
    ...

@router.get("/{user_id}", response_model=UserResponse)
async def get_user(user_id: int = Path(..., ge=1, description="ユーザーID")):
    ...
```

## 依存性注入

詳細は `references/dependency-injection.md` を参照。

```python
from fastapi import Depends
from typing import Annotated

# yield 依存性でリソース管理
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session() as session:
        yield session

# Annotated で型エイリアス化（推奨）
DbSession = Annotated[AsyncSession, Depends(get_db)]
CurrentUser = Annotated[User, Depends(get_current_user)]

# サブ依存性の連鎖
async def get_user_service(db: DbSession, user: CurrentUser) -> UserService:
    return UserService(db, user)

@router.get("/users")
async def list_users(db: DbSession):
    ...
```

## Pydantic モデルとバリデーション

```python
from pydantic import BaseModel, Field, ConfigDict, field_validator, model_validator

class UserCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    email: str = Field(..., pattern=r"^[\w\.-]+@[\w\.-]+\.\w+$")
    age: int = Field(..., ge=0, le=150)

    @field_validator("name")
    @classmethod
    def strip_name(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("空白のみの名前は不可")
        return v.strip()

class UserResponse(BaseModel):
    id: int
    name: str
    email: str
    model_config = ConfigDict(from_attributes=True)  # ORM 連携に必須

class DateRange(BaseModel):
    start: date
    end: date

    @model_validator(mode="after")
    def check_range(self) -> "DateRange":
        if self.start > self.end:
            raise ValueError("start は end より前である必要がある")
        return self
```

## エラーハンドリング

```python
from fastapi import HTTPException, Request
from fastapi.responses import JSONResponse

class AppException(Exception):
    def __init__(self, code: str, message: str, status_code: int = 400):
        self.code, self.message, self.status_code = code, message, status_code

@app.exception_handler(AppException)
async def handle_app_exception(request: Request, exc: AppException):
    return JSONResponse(status_code=exc.status_code, content={"code": exc.code, "message": exc.message})

# 使用例
raise AppException(code="USER_NOT_FOUND", message="ユーザーが見つかりません", status_code=404)
raise HTTPException(status_code=404, detail="Not found")  # 標準的な場合
```

## 認証/認可実装

```python
from fastapi import Depends, Security
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")

async def get_current_user(token: str = Depends(oauth2_scheme)) -> User:
    payload = decode_jwt(token)
    user = await user_repo.get(payload["sub"])
    if not user:
        raise HTTPException(status_code=401, detail="Invalid token")
    return user

# パラメータ付き依存性ファクトリでロールベース認可
def require_role(*roles: str):
    async def checker(user: User = Depends(get_current_user)):
        if user.role not in roles:
            raise HTTPException(status_code=403, detail="Forbidden")
        return user
    return checker

@router.delete("/{user_id}", dependencies=[Security(require_role("admin"))])
async def delete_user(user_id: int):
    ...

@router.post("/auth/token")
async def login(form: OAuth2PasswordRequestForm = Depends()):
    user = await authenticate(form.username, form.password)
    return {"access_token": create_jwt({"sub": str(user.id)}), "token_type": "bearer"}
```

## ロギング実装

```python
import structlog
from uuid import uuid4

structlog.configure(processors=[
    structlog.contextvars.merge_contextvars,
    structlog.processors.add_log_level,
    structlog.processors.TimeStamper(fmt="iso"),
    structlog.dev.ConsoleRenderer(),  # 本番: JSONRenderer()
])
logger = structlog.get_logger()

@app.middleware("http")
async def logging_middleware(request: Request, call_next):
    structlog.contextvars.clear_contextvars()
    structlog.contextvars.bind_contextvars(
        request_id=request.headers.get("x-request-id", str(uuid4())),
        path=request.url.path, method=request.method,
    )
    logger.info("request_started")
    response = await call_next(request)
    logger.info("request_completed", status=response.status_code)
    return response
```

## 非同期処理

```python
from fastapi import BackgroundTasks
import asyncio

# BackgroundTasks: レスポンス返却後に実行
@router.post("/users")
async def create_user(user: UserCreate, bg: BackgroundTasks):
    new_user = await user_service.create(user)
    bg.add_task(send_welcome_email, new_user.email)
    return new_user

# 並行 I/O
async def fetch_dashboard():
    users, orders = await asyncio.gather(user_service.get_all(), order_service.get_recent())
    return {"users": users, "orders": orders}

# CPU バウンド処理はスレッド/プロセスプールへ
from concurrent.futures import ProcessPoolExecutor
executor = ProcessPoolExecutor(max_workers=4)

@router.post("/analyze")
async def analyze(data: AnalysisRequest):
    result = await asyncio.get_event_loop().run_in_executor(executor, heavy_computation, data.payload)
    return result
```

## ORM 連携パターン

```python
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import DeclarativeBase

class Base(DeclarativeBase):
    pass

engine = create_async_engine(settings.database_url)
async_session = async_sessionmaker(engine, expire_on_commit=False)

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
```

## 環境設定

```python
from pydantic_settings import BaseSettings
from pydantic import Field, ConfigDict
from functools import lru_cache

class Settings(BaseSettings):
    app_name: str = "My API"
    debug: bool = False
    database_url: str = Field(..., alias="DATABASE_URL")
    secret_key: str = Field(..., min_length=32)
    cors_origins: list[str] = ["http://localhost:3000"]
    model_config = ConfigDict(env_file=".env", env_file_encoding="utf-8")

@lru_cache
def get_settings() -> Settings:
    return Settings()

@router.get("/info")
async def info(settings: Settings = Depends(get_settings)):
    return {"app": settings.app_name}
```

## レビューチェックリスト

- [ ] `response_model` が全エンドポイントに設定されている
- [ ] パスパラメータに `Path()` で制約が付与されている
- [ ] DB セッションが `yield` 依存性で適切に管理されている
- [ ] 認証が必要なエンドポイントに `Depends(get_current_user)` がある
- [ ] カスタム例外に対する `exception_handler` が登録されている
- [ ] `BackgroundTasks` の処理内で例外が握りつぶされていない
- [ ] `BaseSettings` で環境変数が管理され、ハードコードされていない
- [ ] Pydantic モデルに `from_attributes=True` が設定されている (ORM 利用時)
- [ ] `structlog` のコンテキスト情報 (request_id 等) がログに含まれている
- [ ] 非同期 I/O に `await` が正しく使われている

## リファレンス

- [FastAPI 公式ドキュメント](https://fastapi.tiangolo.com/)
- [Pydantic V2 ドキュメント](https://docs.pydantic.dev/latest/)
- [SQLAlchemy 2.0 Async](https://docs.sqlalchemy.org/en/20/orm/extensions/asyncio.html)
- [pydantic-settings](https://docs.pydantic.dev/latest/concepts/pydantic_settings/)
- [structlog](https://www.structlog.org/en/stable/)
- `references/dependency-injection.md` - 依存性注入パターン詳細
