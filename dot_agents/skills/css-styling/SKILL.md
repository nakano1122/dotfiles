---
name: css-styling
description: CSS の包括的なベストプラクティスガイド（フレームワーク非依存）。パフォーマンス最適化、保守性、シンプルなコード、親子要素の相対値設計、モダン CSS 機能（Container Queries、:has()、ネイティブネスティング、Cascade Layers）をカバー。CSS 設計・実装・レビュー時に使用。Tailwind CSS 等のユーティリティフレームワーク使用時は tailwind-css スキルを参照。
---

# CSS ベストプラクティスガイド

フレームワーク非依存の CSS 設計・実装ガイド。モダン CSS 機能を活用し、パフォーマンス・保守性・シンプルさを両立する。

## 基本原則

```
1. 親要素からスタイルを適用し、子要素は親から見た相対値で設計する（必須）
2. クラスベースセレクタを優先し、要素セレクタやIDセレクタを避ける
3. 詳細度は可能な限り低く保つ（@layer で管理）
4. 命名は見た目ではなく目的ベースにする（.text-red → .error-message）
5. マジックナンバーを避け、CSS 変数でトークン化する
6. 論理プロパティ（margin-inline, padding-block）で国際化対応
```

### 詳細度の管理

| 方法 | 詳細度 | 用途 |
|------|--------|------|
| `:where(.class)` | 0,0,0 | リセット、デフォルトスタイル |
| `.class` | 0,1,0 | 通常のスタイリング |
| `@layer` | レイヤー順で制御 | アーキテクチャ全体の設計 |
| `:is(.a, .b)` | 引数の最大詳細度 | グルーピング（詳細度に注意） |

## 親子要素の相対値設計

**必須ルール**: 親要素でベースサイズを定義し、子要素は `em` / `%` / CSS 変数で相対的に指定する。

### 単位の使い分け

| 単位 | 用途 | 例 |
|------|------|-----|
| `rem` | 親要素のフォントサイズ、グローバルスペーシング | `font-size: 1.125rem` |
| `em` | 子要素のフォントサイズ、親に連動するパディング | `font-size: 0.875em`, `padding: 0.5em 1em` |
| `%` | 幅・高さの相対指定 | `width: 100%`, `max-width: 80%` |
| `px` | ボーダー、シャドウ、極小の固定値のみ | `border: 1px solid`, `box-shadow: 0 2px 4px` |
| `cqi` | コンテナ幅に対する相対値 | `font-size: 4cqi` |

### CSS 変数 + calc() パターン

```
設計手順:
1. 親要素で CSS 変数（--component-font-size, --component-spacing）を定義
2. 子要素は calc(var(--parent-token) * 倍率) で相対的に指定
3. バリエーション（--sm, --lg）は親の変数を上書きするだけ
4. Container Queries でコンテナサイズに応じて親の変数を切替
```

実装パターンとコード例: [references/parent-child-sizing.md](references/parent-child-sizing.md)

## パフォーマンス

### レンダリング最適化

```css
/* content-visibility でオフスクリーン要素のレンダリングをスキップ */
.below-fold-section {
  content-visibility: auto;
  contain-intrinsic-size: auto 500px;
}

/* GPU アニメーション対象プロパティ */
/* ✅ transform, opacity, filter */
/* ❌ width, height, top, left, margin, padding */
.animate {
  transition: transform 300ms ease, opacity 300ms ease;
  will-change: transform; /* アニメーション直前のみ付与 */
}
```

### セレクタ効率

```
原則:
- セレクタのネストは 3 階層以内
- ユニバーサルセレクタ（*）の多用を避ける
- 属性セレクタ [class^="icon-"] よりクラスセレクタを優先
- :has() は強力だが、深いネストでの多用はパフォーマンスに影響
```

### リソース最適化

```
- Critical CSS をインラインで配置し、残りは非同期ロード
- 未使用 CSS の削除（PurgeCSS 等）
- メディアクエリ付き <link> で条件付きロード
- フォントは font-display: swap + preload
```

詳細: [references/performance-patterns.md](references/performance-patterns.md)

## 保守性

### Cascade Layers (@layer)

```css
/* レイヤー順序の宣言（先に書いたものが低優先） */
@layer reset, base, components, utilities;

@layer reset {
  *, *::before, *::after { box-sizing: border-box; margin: 0; }
}

@layer base {
  body { font-family: system-ui, sans-serif; line-height: 1.6; }
}

@layer components {
  .button { padding: 0.5em 1em; border-radius: 0.25rem; }
}

@layer utilities {
  .visually-hidden { /* スクリーンリーダー用 */ }
}
```

### @property による型付きカスタムプロパティ

```css
@property --color-primary {
  syntax: "<color>";
  inherits: true;
  initial-value: #3b82f6;
}

/* トランジション・アニメーションでカスタムプロパティを補間可能 */
.button {
  background: var(--color-primary);
  transition: --color-primary 300ms ease;
}
```

### @scope によるスコーピング

```css
@scope (.card) to (.card__footer) {
  /* .card 内だが .card__footer 内には適用しない */
  p { margin-block-end: 0.75em; }
}
```

### 命名規則（BEM）

```
ブロック:    .card, .nav, .form
エレメント:  .card__title, .card__body
モディファイア: .card--featured, .button--primary

原則:
- ブロックは独立して再利用可能な単位
- エレメントはブロック内でのみ意味を持つ
- モディファイアは外見・状態のバリエーション
- BEM + @layer で詳細度を完全に制御
```

### ファイル構成（ITCSS）

```
styles/
├── settings/    # 変数・トークン定義
├── tools/       # ミックスイン（PostCSS 等）
├── generic/     # リセット・正規化
├── elements/    # 素のHTML要素スタイル
├── objects/     # レイアウトパターン
├── components/  # UIコンポーネント
└── utilities/   # ユーティリティクラス
```

## シンプルなコード

### ネイティブネスティング

```css
.nav {
  display: flex;
  gap: 1rem;

  & a {
    color: inherit;
    text-decoration: none;

    &:hover { text-decoration: underline; }
  }

  /* メディアクエリもネスト可能 */
  @media (max-width: 768px) {
    flex-direction: column;
  }
}
```

### Container Queries

```css
.sidebar {
  container-type: inline-size;
  container-name: sidebar;
}

@container sidebar (min-width: 300px) {
  .widget { display: grid; grid-template-columns: 1fr 1fr; }
}

@container sidebar (max-width: 299px) {
  .widget { display: flex; flex-direction: column; }
}
```

### :has() セレクタ

```css
/* 画像を持つカードのレイアウト変更 */
.card:has(img) { grid-template-rows: auto 1fr; }

/* 必須フィールドの親ラベルにスタイル適用 */
label:has(+ input:required)::after {
  content: " *";
  color: var(--color-error);
}

/* 空のリストに対するフォールバック */
.list:has(> :first-child) { /* リストにアイテムがある場合 */ }
.list:not(:has(> :first-child))::after {
  content: "アイテムがありません";
}
```

### clamp() によるレスポンシブ値

```css
/* フォントサイズ: 最小 1rem、推奨 2.5vw、最大 2rem */
h1 { font-size: clamp(1rem, 2.5vw + 0.5rem, 2rem); }

/* スペーシング: ビューポートに応じて自動調整 */
.section { padding: clamp(1rem, 4vw, 3rem); }
```

### 論理プロパティ

```
物理 → 論理の対応:
  margin-left    → margin-inline-start
  margin-right   → margin-inline-end
  padding-top    → padding-block-start
  padding-bottom → padding-block-end
  width          → inline-size
  height         → block-size
  text-align: left → text-align: start

→ RTL（右から左）言語に自動対応
```

## アンチパターン

| NG | OK | 理由 |
|----|-----|------|
| `#header { ... }` | `.header { ... }` | ID は詳細度が高すぎる |
| `div.card > p.text` | `.card__text` | 要素に依存しない命名 |
| `!important` の多用 | `@layer` で優先順位制御 | 保守不能になる |
| `margin-top: 37px` | `margin-block-start: var(--space-md)` | マジックナンバー回避 |
| `font-size: 14px`（子要素） | `font-size: 0.875em` | 親からの相対値で設計 |
| `width: 300px`（子要素） | `width: 100%` or `max-width` | 親に追従する柔軟な設計 |
| `@media` だけでレスポンシブ | `@container` + `@media` 併用 | コンポーネント単位の適応 |
| ネスト 4 階層以上 | 3 階層以内 | セレクタ効率と可読性 |
| `margin` で要素間スペーシング | `gap` + Flexbox/Grid | 予測しやすいレイアウト |
| `.red-text`, `.big-font` | `.error-message`, `.heading-primary` | 目的ベース命名 |

## レビューチェックリスト

- [ ] 親要素でベースサイズを定義し、子要素が相対値で設計されている
- [ ] CSS 変数でデザイントークンが定義されている
- [ ] `@layer` でスタイルの優先順位が管理されている
- [ ] セレクタのネストが 3 階層以内
- [ ] `!important` を使用していない（やむを得ない場合は理由をコメント）
- [ ] マジックナンバーがなく、変数またはトークンを使用している
- [ ] アニメーション対象が `transform` / `opacity` のみ
- [ ] `content-visibility` をスクロール外要素に適用検討済み
- [ ] 論理プロパティを使用している
- [ ] BEM 命名規則に従っている
- [ ] レスポンシブ対応に `@container` を活用している

## リファレンス

- [references/performance-patterns.md](references/performance-patterns.md) - Critical CSS、アニメーション最適化、リソース読み込み戦略の詳細
- [references/parent-child-sizing.md](references/parent-child-sizing.md) - 親子要素の相対値設計パターン、Container Queries 活用、コンポーネント実装例
