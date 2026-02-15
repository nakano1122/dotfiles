---
name: env-config
description: 環境設定管理の設計ガイド（フレームワーク非依存）。環境分離の原則、環境変数の設計パターン、設定ファイル構成、シークレットとの分離、ローカル開発設定、Feature Flag、バージョン管理方針をカバー。環境変数設計、設定管理方針の決定時に使用。
---

# 環境設定管理ガイド

環境設定管理のフレームワーク非依存な設計ガイド。

## 環境分離の原則

### 環境の種類

| 環境 | 目的 | 特徴 |
|------|------|------|
| development | ローカル開発 | デバッグ有効、モック/ローカル DB |
| test | テスト実行 | テスト用 DB、外部サービスのモック |
| staging | 本番前検証 | 本番に近い構成、テストデータ |
| production | 本番運用 | 最適化済み、実データ |

### 設定の階層

```
デフォルト値（コード内）
  ↓ 上書き
環境別設定ファイル
  ↓ 上書き
環境変数
  ↓ 上書き
コマンドライン引数（あれば）

→ 環境変数が最も優先度が高い
```

## 環境変数の設計

### 命名規則

```
{APP_PREFIX}_{CATEGORY}_{NAME}

例:
  MYAPP_DB_HOST
  MYAPP_DB_PORT
  MYAPP_REDIS_URL
  MYAPP_AUTH_JWT_SECRET
  MYAPP_FEATURE_DARK_MODE

原則:
  - UPPER_SNAKE_CASE
  - アプリケーションプレフィックスを付ける（衝突防止）
  - カテゴリでグルーピング
  - 意味が明確な名前
```

### 型安全性とバリデーション

```
原則:
  - アプリケーション起動時にすべての必須変数を検証する
  - 型変換を明示的に行う（文字列 → 数値、真偽値）
  - 不足している場合は即座にエラーで停止する（サイレント失敗しない）
  - デフォルト値は開発環境用のみ設定

バリデーション対象:
  - 必須変数の存在確認
  - 型の妥当性（ポート番号が数値か、URL が有効か）
  - 値の範囲（ポート番号が 1-65535 か）
  - 形式の妥当性（メールアドレス、URL の形式）
```

### よくある環境変数

```
アプリケーション:
  NODE_ENV / APP_ENV     : 環境名
  PORT                   : リッスンポート
  LOG_LEVEL              : ログレベル

データベース:
  DATABASE_URL           : 接続文字列
  DB_HOST / DB_PORT      : 個別指定
  DB_POOL_SIZE           : コネクションプール

認証:
  JWT_SECRET             : JWT 署名キー
  SESSION_SECRET         : セッション秘密鍵
  OAUTH_CLIENT_ID        : OAuth クライアント ID

外部サービス:
  API_BASE_URL           : バックエンド API の URL
  REDIS_URL              : Redis 接続先
  S3_BUCKET              : ストレージバケット
```

## 設定ファイルの構成

### パターン 1: 環境別設定ファイル

```
config/
  ├── default.ts       # 共通デフォルト値
  ├── development.ts   # 開発環境
  ├── test.ts          # テスト環境
  ├── staging.ts       # ステージング環境
  └── production.ts    # 本番環境

→ APP_ENV に基づいて読み込むファイルを選択
```

### パターン 2: 単一設定ファイル + 環境変数

```
config.ts
  export const config = {
    port: env("PORT", 3000),
    db: {
      host: env("DB_HOST", "localhost"),
      port: env("DB_PORT", 5432),
    },
  };

→ 環境変数で上書き可能なデフォルト値を定義
```

### 設定のグルーピング

```
config = {
  app: { port, env, logLevel },
  db: { host, port, name, poolSize },
  auth: { jwtSecret, sessionTtl },
  external: { apiBaseUrl, redisUrl },
  features: { darkMode, betaFeatures },
}

→ カテゴリごとにグループ化して可読性を向上
```

## シークレットとの分離

```
環境変数として管理するもの（非機密）:
  - ポート番号
  - ログレベル
  - 環境名
  - Feature Flag

シークレットとして管理するもの（機密）:
  - API キー
  - DB パスワード
  - JWT シークレット
  - OAuth クライアントシークレット
  - 暗号化キー

シークレットの管理方法:
  - 開発環境: .env ファイル（git 管理外）
  - 本番環境: シークレットマネージャー or CI/CD の変数
  - ❌ ソースコードにハードコード
  - ❌ git にコミット
```

## ローカル開発環境の設定

### .env ファイルの管理

```
.env              → git 管理外（.gitignore に追加）
.env.example      → git 管理対象（テンプレート）
.env.test         → テスト用（git 管理対象可）
.env.local        → 個人設定（git 管理外）

.env.example の記載方法:
  DB_HOST=localhost
  DB_PORT=5432
  DB_NAME=myapp_dev
  JWT_SECRET=            # ← 空にして「要設定」を示す
  API_KEY=               # ← 空にして「要設定」を示す
```

### セットアップスクリプト

```
原則:
  - 新しい開発者が最小限の手順で環境構築できる
  - .env.example → .env のコピーを自動化
  - 必要な外部サービス（DB等）の起動を自動化
  - セットアップ手順を README に明記
```

## Feature Flag

### 設計パターン

```
基本: 環境変数で管理
  FEATURE_DARK_MODE=true
  FEATURE_NEW_CHECKOUT=false

判断基準:
  - シンプルなフラグ → 環境変数
  - ユーザーごとの出し分け → Feature Flag サービス
  - A/B テスト → 専用サービス

原則:
  - フラグ名は機能を明確に表す
  - デフォルトは無効（false）
  - 使い終わったフラグは速やかに削除
  - フラグの一覧を管理する
```

### ライフサイクル

```
1. フラグ作成（新機能開発開始）
2. 開発環境で有効化
3. ステージングで検証
4. 本番で段階的にロールアウト
5. 全ユーザーに展開完了
6. フラグとコード分岐を削除
```

## バージョン管理方針

### コミットすべきもの

```
✅ コミット対象:
  - 設定ファイルのテンプレート（.env.example）
  - 環境別設定ファイル（非機密）
  - ロックファイル（package-lock.json 等）
  - CI/CD 設定ファイル
  - Docker / docker-compose 設定

❌ コミットしてはいけないもの:
  - .env ファイル（シークレット含む）
  - 個人の IDE 設定
  - ローカル用の設定上書きファイル
  - ビルド成果物
```

### .gitignore の設定

```
# 環境設定
.env
.env.local
.env.*.local

# コミットすべきテンプレート（gitignore しない）
# .env.example
# .env.test（テスト用、機密情報なし）
```

## レビューチェックリスト

- [ ] 環境変数に命名規則が適用されている
- [ ] 必須の環境変数が起動時にバリデーションされている
- [ ] シークレットがソースコードにハードコードされていない
- [ ] .env が .gitignore に含まれている
- [ ] .env.example が更新されている
- [ ] 開発/テスト/本番の設定が適切に分離されている
- [ ] Feature Flag に不要なものが残っていない
- [ ] デフォルト値が開発環境でのみ使用されている

## リファレンス

- [references/env-patterns.md](references/env-patterns.md) - 環境設定パターン詳細
