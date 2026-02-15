# セキュリティヘッダー設定詳細

## 目次

1. [Content-Security-Policy (CSP)](#content-security-policy-csp)
2. [Strict-Transport-Security (HSTS)](#strict-transport-security-hsts)
3. [X-Content-Type-Options](#x-content-type-options)
4. [X-Frame-Options](#x-frame-options)
5. [Referrer-Policy](#referrer-policy)
6. [Permissions-Policy](#permissions-policy)
7. [その他のセキュリティヘッダー](#その他のセキュリティヘッダー)
8. [シナリオ別推奨設定](#シナリオ別推奨設定)

---

## Content-Security-Policy (CSP)

### 概要
CSP は、XSS やデータインジェクション攻撃を防ぐための強力なセキュリティ機構です。ブラウザに対して、どのリソースの読み込みや実行を許可するかを指定します。

### 基本構文
```
Content-Security-Policy: <directive> <source>; <directive> <source>;
```

### 主要なディレクティブ

#### default-src
すべてのリソースタイプのデフォルトポリシーを設定します。

```
Content-Security-Policy: default-src 'self'
```
- `'self'`: 同一オリジンからのみ読み込み許可
- `'none'`: すべて拒否
- `*`: すべて許可（非推奨）

#### script-src
JavaScript の読み込みと実行を制御します。

```
Content-Security-Policy: script-src 'self' https://trusted.cdn.com
```

**重要なキーワード:**
- `'self'`: 同一オリジン
- `'unsafe-inline'`: インライン JavaScript を許可（非推奨）
- `'unsafe-eval'`: eval() の使用を許可（非推奨）
- `'strict-dynamic'`: nonce または hash で許可されたスクリプトが読み込むスクリプトを許可
- `'nonce-<value>'`: 特定の nonce 値を持つスクリプトのみ許可
- `'sha256-<hash>'`: 特定のハッシュ値を持つスクリプトのみ許可

**推奨例（nonce 使用）:**
```
Content-Security-Policy: script-src 'nonce-random123' 'strict-dynamic'
```

HTML 側:
```html
<script nonce="random123">
  // このスクリプトは実行される
</script>
```

**推奨例（hash 使用）:**
```
Content-Security-Policy: script-src 'sha256-abc123...'
```

#### style-src
CSS の読み込みと適用を制御します。

```
Content-Security-Policy: style-src 'self' https://trusted.cdn.com
```

**キーワード:**
- `'unsafe-inline'`: インライン CSS を許可
- `'nonce-<value>'`: nonce ベースの許可
- `'sha256-<hash>'`: hash ベースの許可

#### img-src
画像の読み込みを制御します。

```
Content-Security-Policy: img-src 'self' https: data:
```

**特殊な値:**
- `data:`: data: URI スキームを許可
- `https:`: すべての HTTPS URL を許可

#### connect-src
XHR, WebSocket, Fetch などの接続を制御します。

```
Content-Security-Policy: connect-src 'self' https://api.example.com
```

#### font-src
フォントの読み込みを制御します。

```
Content-Security-Policy: font-src 'self' https://fonts.gstatic.com
```

#### media-src
音声・動画の読み込みを制御します。

```
Content-Security-Policy: media-src 'self' https://media.example.com
```

#### object-src
プラグイン（Flash, PDF など）を制御します。

```
Content-Security-Policy: object-src 'none'
```

**推奨:** 特別な理由がない限り `'none'` を設定

#### frame-src / child-src
iframe の読み込みを制御します。

```
Content-Security-Policy: frame-src 'self' https://trusted.com
```

#### frame-ancestors
このページを iframe に埋め込めるオリジンを制御します（X-Frame-Options の後継）。

```
Content-Security-Policy: frame-ancestors 'none'
```

- `'none'`: すべての埋め込みを拒否
- `'self'`: 同一オリジンのみ
- 特定のオリジン: `https://trusted.com`

#### base-uri
`<base>` タグで使用できる URL を制限します。

```
Content-Security-Policy: base-uri 'self'
```

#### form-action
フォーム送信先を制限します。

```
Content-Security-Policy: form-action 'self'
```

#### upgrade-insecure-requests
HTTP リクエストを自動的に HTTPS にアップグレードします。

```
Content-Security-Policy: upgrade-insecure-requests
```

#### block-all-mixed-content
HTTPS ページでの HTTP リソース読み込みをブロックします（非推奨、upgrade-insecure-requests を推奨）。

```
Content-Security-Policy: block-all-mixed-content
```

### CSP の段階的導入

#### 1. Report-Only モード
ポリシー違反を報告するが、実際にはブロックしません。

```
Content-Security-Policy-Report-Only: default-src 'self'; report-uri /csp-report
```

#### 2. 報告の設定
違反レポートを受け取るエンドポイントを設定します。

```
Content-Security-Policy: default-src 'self'; report-uri /csp-report; report-to csp-endpoint
```

Report-To ヘッダーとの併用:
```
Report-To: {"group":"csp-endpoint","max_age":10886400,"endpoints":[{"url":"/csp-report"}]}
Content-Security-Policy: default-src 'self'; report-to csp-endpoint
```

### CSP 実装例

#### 厳格な CSP（推奨）
```
Content-Security-Policy:
  default-src 'none';
  script-src 'nonce-{random}' 'strict-dynamic';
  style-src 'nonce-{random}';
  img-src 'self' https: data:;
  font-src 'self';
  connect-src 'self' https://api.example.com;
  frame-ancestors 'none';
  base-uri 'self';
  form-action 'self';
  upgrade-insecure-requests
```

#### 中程度の CSP
```
Content-Security-Policy:
  default-src 'self';
  script-src 'self' https://trusted.cdn.com;
  style-src 'self' 'unsafe-inline';
  img-src 'self' https: data:;
  font-src 'self' https://fonts.gstatic.com;
  connect-src 'self' https://api.example.com;
  frame-ancestors 'self';
  object-src 'none';
  base-uri 'self';
  form-action 'self'
```

#### API 専用
```
Content-Security-Policy:
  default-src 'none';
  frame-ancestors 'none'
```

### ベストプラクティス

1. **段階的に厳格化**
   - Report-Only モードで開始
   - 違反レポートを収集・分析
   - 段階的にポリシーを厳格化

2. **'unsafe-inline' を避ける**
   - nonce または hash を使用
   - インラインスクリプト・スタイルを外部ファイルに移動

3. **'unsafe-eval' を避ける**
   - eval(), Function(), setTimeout(string) を使用しない
   - 代替手段を検討

4. **default-src を設定**
   - すべてのディレクティブの基準となる
   - 明示的に指定しないリソースタイプに適用

5. **object-src は 'none'**
   - Flash などのプラグインは使用しない

---

## Strict-Transport-Security (HSTS)

### 概要
HSTS は、ブラウザに対して HTTPS のみでアクセスすることを強制します。中間者攻撃やプロトコルダウングレード攻撃を防ぎます。

### 基本構文
```
Strict-Transport-Security: max-age=<seconds>; includeSubDomains; preload
```

### ディレクティブ

#### max-age
HSTS ポリシーの有効期間（秒）を指定します。

```
Strict-Transport-Security: max-age=31536000
```

**推奨値:**
- 開発・テスト: `max-age=300` (5分)
- ステージング: `max-age=86400` (1日)
- 本番環境: `max-age=31536000` (1年)
- プリロード対象: `max-age=63072000` (2年)

#### includeSubDomains
すべてのサブドメインにも HSTS を適用します。

```
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

**注意:** サブドメインの HTTP サービスがあると動作しなくなります。

#### preload
ブラウザの HSTS プリロードリストへの登録を希望することを示します。

```
Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
```

**プリロード要件:**
- `max-age` が 31536000 秒（1年）以上
- `includeSubDomains` が指定されている
- `preload` ディレクティブが含まれている
- HTTPS で有効な証明書を使用
- すべてのサブドメインが HTTPS をサポート

### 実装例

#### 基本設定
```
Strict-Transport-Security: max-age=31536000
```

#### サブドメイン含む（推奨）
```
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

#### プリロード対応（最高レベル）
```
Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
```

### 導入手順

1. **準備**
   - すべてのコンテンツを HTTPS 化
   - Mixed Content の解消
   - すべてのサブドメインの確認

2. **段階的導入**
   - 短い max-age で開始（例: 300秒）
   - 問題がないことを確認
   - 徐々に max-age を延長

3. **プリロード登録（オプション）**
   - https://hstspreload.org/ で登録
   - 取り消しが困難なため慎重に

### 注意点

- **取り消しが困難**: max-age の期間中はブラウザにキャッシュされる
- **サブドメインの影響**: includeSubDomains は慎重に使用
- **初回アクセス**: 初回は HTTP でアクセス可能（プリロードで解決）
- **証明書エラー**: HTTPS に問題があるとサイトにアクセス不可

---

## X-Content-Type-Options

### 概要
MIME タイプスニッフィングを無効化し、Content-Type ヘッダーを厳密に遵守させます。XSS 攻撃のリスクを軽減します。

### 構文
```
X-Content-Type-Options: nosniff
```

### 効果

1. **スクリプトの保護**
   - JavaScript ファイルが正しい MIME タイプ（`application/javascript`, `text/javascript`）でない場合、実行を拒否

2. **スタイルシートの保護**
   - CSS ファイルが正しい MIME タイプ（`text/css`）でない場合、適用を拒否

### 実装例
```
X-Content-Type-Options: nosniff
```

### ベストプラクティス

1. **すべてのレスポンスに適用**
   - 静的ファイルも含む

2. **正しい Content-Type の設定**
   - JavaScript: `application/javascript` または `text/javascript`
   - CSS: `text/css`
   - HTML: `text/html; charset=UTF-8`
   - JSON: `application/json`
   - 画像: `image/png`, `image/jpeg` など

3. **ダウンロード可能ファイルの保護**
   - `application/octet-stream` の適切な使用
   - Content-Disposition ヘッダーとの併用

---

## X-Frame-Options

### 概要
クリックジャッキング攻撃を防ぐため、ページが iframe 内で表示されることを制御します。

**注意:** CSP の `frame-ancestors` ディレクティブが推奨されますが、古いブラウザ対応のため併用が望ましいです。

### 構文
```
X-Frame-Options: <directive>
```

### ディレクティブ

#### DENY
すべての iframe での表示を拒否します。

```
X-Frame-Options: DENY
```

**推奨:** クリックジャッキングのリスクが高い場合

#### SAMEORIGIN
同一オリジンの iframe でのみ表示を許可します。

```
X-Frame-Options: SAMEORIGIN
```

**推奨:** 自サイト内で iframe を使用する場合

#### ALLOW-FROM（非推奨）
特定のオリジンからの iframe を許可します。

```
X-Frame-Options: ALLOW-FROM https://trusted.com
```

**注意:** 多くのブラウザでサポート終了。CSP の `frame-ancestors` を使用してください。

### 実装例

#### 完全拒否
```
X-Frame-Options: DENY
Content-Security-Policy: frame-ancestors 'none'
```

#### 同一オリジンのみ許可
```
X-Frame-Options: SAMEORIGIN
Content-Security-Policy: frame-ancestors 'self'
```

#### 特定オリジンを許可
```
# X-Frame-Options では不可
Content-Security-Policy: frame-ancestors 'self' https://trusted.com
```

### ベストプラクティス

1. **CSP との併用**
   ```
   X-Frame-Options: DENY
   Content-Security-Policy: frame-ancestors 'none'
   ```

2. **適切なディレクティブの選択**
   - デフォルト: `DENY`
   - 自サイト内で iframe 使用: `SAMEORIGIN`
   - 特定サイトで使用: CSP の `frame-ancestors`

---

## Referrer-Policy

### 概要
Referer ヘッダーに含まれる情報を制御し、プライバシーを保護します。

### 構文
```
Referrer-Policy: <directive>
```

### ディレクティブ

#### no-referrer
Referer ヘッダーを一切送信しません。

```
Referrer-Policy: no-referrer
```

**プライバシー:** 最高 | **機能性:** 低

#### no-referrer-when-downgrade（デフォルト）
HTTPS から HTTP へのダウングレード時のみ Referer を送信しません。

```
Referrer-Policy: no-referrer-when-downgrade
```

#### origin
オリジン（スキーム、ホスト、ポート）のみを送信します。

```
Referrer-Policy: origin
```

**送信例:** `https://example.com/page?query=1` → `https://example.com/`

#### origin-when-cross-origin
同一オリジンには完全な URL、クロスオリジンにはオリジンのみを送信します。

```
Referrer-Policy: origin-when-cross-origin
```

#### same-origin
同一オリジンにのみ Referer を送信します。

```
Referrer-Policy: same-origin
```

#### strict-origin
HTTPS から HTTP へのダウングレード時を除き、オリジンのみを送信します。

```
Referrer-Policy: strict-origin
```

**プライバシー:** 高 | **機能性:** 中

#### strict-origin-when-cross-origin（推奨）
- 同一オリジン: 完全な URL
- クロスオリジン（HTTPS→HTTPS, HTTP→HTTP, HTTP→HTTPS）: オリジンのみ
- HTTPS→HTTP: 送信しない

```
Referrer-Policy: strict-origin-when-cross-origin
```

**プライバシー:** 高 | **機能性:** 高

#### unsafe-url
常に完全な URL を送信します（非推奨）。

```
Referrer-Policy: unsafe-url
```

**プライバシー:** 低 | **機能性:** 最高

### 実装例

#### 推奨設定
```
Referrer-Policy: strict-origin-when-cross-origin
```

#### 高プライバシー設定
```
Referrer-Policy: same-origin
```

#### API エンドポイント
```
Referrer-Policy: no-referrer
```

### HTML での設定

#### meta タグ
```html
<meta name="referrer" content="strict-origin-when-cross-origin">
```

#### リンク単位
```html
<a href="https://external.com" referrerpolicy="no-referrer">Link</a>
```

### ベストプラクティス

1. **デフォルトポリシーの設定**
   - `strict-origin-when-cross-origin` を推奨

2. **機密性の高いページ**
   - `no-referrer` または `same-origin`

3. **分析ツールの考慮**
   - 外部分析ツールが Referer に依存する場合は調整が必要

---

## Permissions-Policy

### 概要
ブラウザの機能（カメラ、位置情報など）へのアクセスを制御します。Feature-Policy の後継です。

### 構文
```
Permissions-Policy: <feature>=(<allowlist>)
```

### 主要な機能

#### カメラとマイク
```
Permissions-Policy: camera=(), microphone=()
```

- `()`: すべて拒否
- `self`: 同一オリジンのみ許可
- `*`: すべて許可
- `("https://trusted.com")`: 特定オリジンを許可

#### 位置情報
```
Permissions-Policy: geolocation=(self)
```

#### 支払い
```
Permissions-Policy: payment=(self "https://payment.example.com")
```

#### フルスクリーン
```
Permissions-Policy: fullscreen=(self)
```

#### 自動再生
```
Permissions-Policy: autoplay=(self)
```

#### USB デバイス
```
Permissions-Policy: usb=()
```

#### その他
- `accelerometer`: 加速度センサー
- `ambient-light-sensor`: 照度センサー
- `battery`: バッテリー情報
- `display-capture`: 画面キャプチャ
- `encrypted-media`: DRM
- `gyroscope`: ジャイロスコープ
- `magnetometer`: 磁気センサー
- `midi`: MIDI デバイス
- `picture-in-picture`: ピクチャインピクチャ
- `sync-xhr`: 同期 XHR

### 実装例

#### 厳格な設定（推奨）
```
Permissions-Policy:
  camera=(),
  microphone=(),
  geolocation=(),
  interest-cohort=(),
  payment=(),
  usb=(),
  magnetometer=(),
  gyroscope=(),
  accelerometer=()
```

#### Web アプリケーション
```
Permissions-Policy:
  camera=(self),
  microphone=(self),
  geolocation=(self),
  fullscreen=(self),
  autoplay=(self)
```

#### 静的サイト
```
Permissions-Policy:
  camera=(),
  microphone=(),
  geolocation=(),
  payment=(),
  usb=()
```

### ベストプラクティス

1. **デフォルト拒否**
   - 使用しない機能はすべて拒否

2. **最小権限**
   - 必要な機能のみ許可

3. **iframe の制御**
   - 埋め込みコンテンツの機能も制御

---

## その他のセキュリティヘッダー

### X-XSS-Protection（非推奨）

古いブラウザの XSS フィルターを制御しますが、現在は非推奨です。CSP を使用してください。

```
X-XSS-Protection: 0
```

**推奨:** `0` で無効化（誤検知による問題を避けるため）

### Cross-Origin-Opener-Policy (COOP)

トップレベルウィンドウの分離を制御します。

```
Cross-Origin-Opener-Policy: same-origin
```

**オプション:**
- `unsafe-none`: デフォルト、分離なし
- `same-origin-allow-popups`: ポップアップは許可
- `same-origin`: 完全な分離

### Cross-Origin-Embedder-Policy (COEP)

クロスオリジンリソースの埋め込みを制御します。

```
Cross-Origin-Embedder-Policy: require-corp
```

**オプション:**
- `unsafe-none`: デフォルト、制限なし
- `require-corp`: CORP ヘッダーが必要

### Cross-Origin-Resource-Policy (CORP)

リソースがクロスオリジンから読み込まれることを制御します。

```
Cross-Origin-Resource-Policy: same-origin
```

**オプション:**
- `same-site`: 同一サイト
- `same-origin`: 同一オリジン
- `cross-origin`: クロスオリジン許可

### Cache-Control（セキュリティの観点）

機密情報のキャッシュを防ぎます。

```
Cache-Control: no-store, max-age=0
```

機密性の高いページ:
```
Cache-Control: no-store, no-cache, must-revalidate, private
Pragma: no-cache
Expires: 0
```

### Clear-Site-Data

ブラウザのデータをクリアします（ログアウト時など）。

```
Clear-Site-Data: "cache", "cookies", "storage"
```

---

## シナリオ別推奨設定

### API サーバー（JSON API）

```
# 基本セキュリティ
Content-Security-Policy: default-src 'none'; frame-ancestors 'none'
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: no-referrer

# HTTPS 強制
Strict-Transport-Security: max-age=31536000; includeSubDomains

# CORS（必要に応じて）
Access-Control-Allow-Origin: https://trusted-client.com
Access-Control-Allow-Methods: GET, POST, PUT, DELETE
Access-Control-Allow-Headers: Content-Type, Authorization
Access-Control-Max-Age: 3600

# キャッシュ制御
Cache-Control: no-store, max-age=0

# 機能制限
Permissions-Policy: camera=(), microphone=(), geolocation=()
```

### SPA（Single Page Application）

```
# CSP（nonce 使用）
Content-Security-Policy:
  default-src 'self';
  script-src 'self' 'nonce-{random}' 'strict-dynamic';
  style-src 'self' 'nonce-{random}';
  img-src 'self' https: data:;
  font-src 'self';
  connect-src 'self' https://api.example.com;
  frame-ancestors 'none';
  base-uri 'self';
  form-action 'self';
  upgrade-insecure-requests

# HTTPS 強制
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload

# 基本セキュリティ
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: strict-origin-when-cross-origin

# 機能制限
Permissions-Policy:
  camera=(),
  microphone=(),
  geolocation=(self),
  payment=(self),
  usb=()

# クロスオリジン分離（SharedArrayBuffer 使用時）
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

### SSR（Server-Side Rendering）

```
# CSP（段階的）
Content-Security-Policy:
  default-src 'self';
  script-src 'self' 'unsafe-inline' https://cdn.example.com;
  style-src 'self' 'unsafe-inline';
  img-src 'self' https: data:;
  font-src 'self' https://fonts.gstatic.com;
  connect-src 'self' https://api.example.com;
  frame-ancestors 'self';
  base-uri 'self';
  form-action 'self'

# HTTPS 強制
Strict-Transport-Security: max-age=31536000; includeSubDomains

# 基本セキュリティ
X-Content-Type-Options: nosniff
X-Frame-Options: SAMEORIGIN
Referrer-Policy: strict-origin-when-cross-origin

# キャッシュ（動的コンテンツ）
Cache-Control: no-cache, must-revalidate

# 機能制限
Permissions-Policy:
  camera=(),
  microphone=(),
  geolocation=(),
  payment=()
```

### 静的サイト

```
# 厳格な CSP
Content-Security-Policy:
  default-src 'none';
  script-src 'self';
  style-src 'self';
  img-src 'self' https:;
  font-src 'self';
  connect-src 'none';
  frame-ancestors 'none';
  base-uri 'self';
  form-action 'none'

# HTTPS 強制
Strict-Transport-Security: max-age=63072000; includeSubDomains; preload

# 基本セキュリティ
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: no-referrer

# 長期キャッシュ
Cache-Control: public, max-age=31536000, immutable

# すべての機能を拒否
Permissions-Policy:
  camera=(),
  microphone=(),
  geolocation=(),
  payment=(),
  usb=(),
  magnetometer=(),
  gyroscope=(),
  accelerometer=()
```

### 管理画面

```
# 厳格な CSP
Content-Security-Policy:
  default-src 'self';
  script-src 'self' 'nonce-{random}';
  style-src 'self' 'nonce-{random}';
  img-src 'self' data:;
  font-src 'self';
  connect-src 'self';
  frame-ancestors 'none';
  base-uri 'self';
  form-action 'self'

# HTTPS 強制
Strict-Transport-Security: max-age=31536000; includeSubDomains

# 基本セキュリティ
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: no-referrer

# キャッシュ無効化
Cache-Control: no-store, no-cache, must-revalidate, private
Pragma: no-cache
Expires: 0

# 機能制限
Permissions-Policy:
  camera=(),
  microphone=(),
  geolocation=(),
  payment=(),
  usb=()
```

---

## まとめ

### 最小限の設定（すべてのサイト）

```
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Content-Security-Policy: default-src 'self'
Referrer-Policy: strict-origin-when-cross-origin
```

### テストとデバッグ

1. **ブラウザの開発者ツール**
   - Console タブで CSP 違反を確認
   - Network タブでヘッダーを確認

2. **オンラインツール**
   - https://securityheaders.com/
   - https://csp-evaluator.withgoogle.com/

3. **段階的導入**
   - Report-Only モードで開始
   - 違反レポートを収集
   - ポリシーを調整
   - 本番適用

4. **継続的な改善**
   - 定期的なレビュー
   - 新しいヘッダーの採用
   - ブラウザ対応状況の確認
