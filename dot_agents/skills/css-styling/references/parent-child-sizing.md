# 親子要素の相対値設計パターン

SKILL.md の「親子要素の相対値設計」セクションの詳細パターン集。ここでは設計原則の深掘り、実践的なコンポーネント実装例を扱う。

## 目次

- [設計原則の詳細](#設計原則の詳細)
- [rem / em / % の使い分け判断フロー](#rem--em---の使い分け判断フロー)
- [CSS 変数による連携パターン](#css-変数による連携パターン)
- [Container Queries 活用パターン](#container-queries-活用パターン)
- [コンポーネント実装例](#コンポーネント実装例)

## 設計原則の詳細

### なぜ親→子の相対値設計か

```
1. 一箇所の変更で全体が連動する
   → 親の font-size を変えるだけで、子のサイズ・余白が自動調整

2. コンポーネントのサイズバリエーションが容易
   → .card--sm, .card--lg は親の CSS 変数を上書きするだけ

3. Container Queries との親和性が高い
   → コンテナサイズに応じて親の値を変更 → 子が自動追従

4. レスポンシブ対応がシンプルになる
   → ブレークポイントごとに親の値だけ調整
```

### 設計の階層

```
[ルート (:root)]
  └─ グローバルトークン定義（--space-unit, --font-size-base）

[コンポーネントルート (.card)]
  └─ コンポーネントトークン定義（--card-spacing, --card-font-size）
  └─ 親要素のスタイル適用

[子要素 (.card__title, .card__body)]
  └─ 親トークンからの相対値（calc(), em）
  └─ 直接的な px 値は使わない
```

## rem / em / % の使い分け判断フロー

```
「この値は何に対して相対的か？」

親要素のフォントサイズに対して
  → em を使用
  例: 子要素の font-size, padding, margin（テキストに連動すべきもの）

ルートのフォントサイズに対して
  → rem を使用
  例: コンポーネントルートの font-size, グローバルスペーシング

親要素のサイズ（幅・高さ）に対して
  → % を使用
  例: width, max-width, flex-basis

コンテナのサイズに対して
  → cqi / cqb を使用
  例: Container Queries 内のフォントサイズ、スペーシング

固定値が必要
  → px を使用（ボーダー、シャドウ、1px ラインのみ）
```

### em の注意点: 累積的な計算

```css
/* ❌ em は親の font-size を基準にするため累積する */
.parent { font-size: 1.25em; }       /* 20px (16 * 1.25) */
.parent .child { font-size: 1.25em; } /* 25px (20 * 1.25) ← 意図しない */

/* ✅ コンポーネントルートは rem、子要素は em */
.parent { font-size: 1.25rem; }       /* 20px */
.parent .child { font-size: 0.875em; } /* 17.5px (20 * 0.875) */
```

## CSS 変数による連携パターン

### トークンの継承チェーン

```css
:root {
  --font-size-base: 1rem;
  --space-unit: 0.25rem;
}

.card {
  /* コンポーネントトークンを定義 */
  --card-font-size: var(--font-size-base);
  --card-spacing: calc(var(--space-unit) * 4); /* 1rem */
  --card-radius: 0.5rem;

  font-size: var(--card-font-size);
  padding: var(--card-spacing);
  border-radius: var(--card-radius);
}

.card__title {
  /* 親トークンから計算 */
  font-size: calc(var(--card-font-size) * 1.5);
  margin-block-end: calc(var(--card-spacing) * 0.5);
}

.card__meta {
  font-size: calc(var(--card-font-size) * 0.75);
  color: var(--color-on-surface-muted);
}

.card__body {
  font-size: calc(var(--card-font-size) * 0.875);
  line-height: 1.6;
}

.card__actions {
  padding-block-start: var(--card-spacing);
  display: flex;
  gap: calc(var(--card-spacing) * 0.5);
}
```

### バリエーションパターン

```css
/* サイズバリエーション: 親の変数を上書きするだけ */
.card--sm {
  --card-font-size: 0.875rem;
  --card-spacing: 0.75rem;
  --card-radius: 0.375rem;
}

.card--lg {
  --card-font-size: 1.125rem;
  --card-spacing: 1.5rem;
  --card-radius: 0.75rem;
}

/* テーマバリエーション: 色トークンのみ上書き */
.card--featured {
  --card-bg: var(--color-primary);
  --card-text: var(--color-on-primary);
}
```

## Container Queries 活用パターン

### 基本: コンテナサイズに応じたトークン切替

```css
.card-container {
  container-type: inline-size;
  container-name: card;
}

/* デフォルト（狭い幅） */
.card {
  --card-font-size: 0.875rem;
  --card-spacing: 0.75rem;
}

/* 中間幅 */
@container card (min-width: 350px) {
  .card {
    --card-font-size: 1rem;
    --card-spacing: 1rem;
  }
}

/* 広い幅 */
@container card (min-width: 600px) {
  .card {
    --card-font-size: 1.125rem;
    --card-spacing: 1.5rem;
    /* レイアウトも変更可能 */
    display: grid;
    grid-template-columns: 1fr 2fr;
  }
}
```

### コンテナクエリ単位 (cqi)

```css
.card-container {
  container-type: inline-size;
}

.card__title {
  /* コンテナ幅の 5% をフォントサイズに */
  font-size: clamp(1rem, 5cqi, 2rem);
}

.card__body {
  font-size: clamp(0.875rem, 3.5cqi, 1.125rem);
}
```

## コンポーネント実装例

### プロフィールカード

```css
.profile-card {
  --pc-font-size: 1rem;
  --pc-spacing: 1.25rem;
  --pc-avatar-size: 4em; /* font-size に連動 */

  font-size: var(--pc-font-size);
  padding: var(--pc-spacing);
  display: flex;
  gap: var(--pc-spacing);
  align-items: flex-start;
  border-radius: 0.5rem;
  background: var(--color-surface-elevated);
}

.profile-card__avatar {
  inline-size: var(--pc-avatar-size);
  block-size: var(--pc-avatar-size);
  border-radius: var(--radius-full);
  flex-shrink: 0;
}

.profile-card__name {
  font-size: calc(var(--pc-font-size) * 1.25);
  font-weight: 600;
  margin-block-end: calc(var(--pc-spacing) * 0.25);
}

.profile-card__role {
  font-size: calc(var(--pc-font-size) * 0.875);
  color: var(--color-on-surface-muted);
}

.profile-card__bio {
  font-size: calc(var(--pc-font-size) * 0.875);
  margin-block-start: calc(var(--pc-spacing) * 0.5);
  line-height: 1.6;
}

/* Container Query 対応 */
.profile-card-container {
  container-type: inline-size;
  container-name: profile;
}

@container profile (max-width: 300px) {
  .profile-card {
    --pc-font-size: 0.875rem;
    --pc-spacing: 1rem;
    --pc-avatar-size: 3em;
    flex-direction: column;
    align-items: center;
    text-align: center;
  }
}
```

### レスポンシブナビゲーション

```css
.nav {
  --nav-font-size: 0.875rem;
  --nav-spacing: 1rem;
  --nav-height: 3.5rem;

  font-size: var(--nav-font-size);
  display: flex;
  align-items: center;
  gap: var(--nav-spacing);
  block-size: var(--nav-height);
  padding-inline: var(--nav-spacing);
}

.nav__link {
  font-size: 1em; /* 親の font-size をそのまま継承 */
  padding: 0.5em 0.75em;
  border-radius: 0.25rem;
  color: inherit;
  text-decoration: none;

  &:hover {
    background: color-mix(in oklch, currentColor 10%, transparent);
  }
}

.nav__logo {
  font-size: calc(var(--nav-font-size) * 1.25);
  font-weight: 700;
}

/* 大画面では少し大きく */
@media (min-width: 1024px) {
  .nav {
    --nav-font-size: 1rem;
    --nav-spacing: 1.5rem;
    --nav-height: 4rem;
  }
}
```

### 価格テーブル

```css
.pricing {
  --pricing-font-size: 1rem;
  --pricing-spacing: 1.5rem;

  font-size: var(--pricing-font-size);
  padding: var(--pricing-spacing);
  border: 1px solid var(--color-border);
  border-radius: 0.75rem;
  text-align: center;
}

.pricing__name {
  font-size: calc(var(--pricing-font-size) * 1.125);
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.pricing__price {
  font-size: calc(var(--pricing-font-size) * 3);
  font-weight: 700;
  margin-block: calc(var(--pricing-spacing) * 0.5);
}

.pricing__price-unit {
  font-size: calc(var(--pricing-font-size) * 0.875);
  font-weight: 400;
  color: var(--color-on-surface-muted);
}

.pricing__features {
  font-size: calc(var(--pricing-font-size) * 0.875);
  list-style: none;
  padding: 0;
  margin-block: var(--pricing-spacing);
  display: flex;
  flex-direction: column;
  gap: calc(var(--pricing-spacing) * 0.5);
}

/* 強調プラン */
.pricing--featured {
  --pricing-font-size: 1.125rem;
  --pricing-spacing: 2rem;
  border-color: var(--color-primary);
  box-shadow: 0 4px 24px color-mix(in oklch, var(--color-primary) 20%, transparent);
}
```
