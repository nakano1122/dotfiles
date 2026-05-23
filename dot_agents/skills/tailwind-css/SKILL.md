---
name: tailwind-css
description: Tailwind CSS (v4) のベストプラクティスガイド。CSS ファースト設定（@theme）、デザイントークン、コンポーネント抽出、レスポンシブ設計、ダークモード、Container Queries、パフォーマンス最適化、親子要素の相対値設計をカバー。Tailwind CSS での UI 実装・設計・レビュー時に使用。素の CSS ルールは css-styling スキルを参照。
---

# Tailwind CSS ベストプラクティスガイド

Tailwind CSS v4 前提の実装ガイド。v3 以前の `tailwind.config.js` ベースの設定は対象外。

## 基本方針

```
1. 親要素からスタイルを適用し、子要素は親から見た相対値で設計する（必須）
2. @apply は原則使用禁止（許容ケースは「コンポーネント抽出」参照）
3. デザイントークン（@theme）を優先し、任意値 [value] を最小限にする
4. クラス名の動的構築を禁止する（`text-${color}` → 完全なクラス名を使用）
5. ユーティリティクラスの順序を統一する（レイアウト → ボックス → タイポ → ビジュアル → インタラクション）
```

### クラス順序の目安

```
レイアウト: flex, grid, block, hidden, relative, absolute
ボックス:   w-, h-, p-, m-, gap-
タイポ:     text-, font-, leading-, tracking-
ビジュアル: bg-, border-, rounded-, shadow-
インタラクション: hover:, focus:, transition-, cursor-
```

## v4 設定 (@theme)

v4 では CSS ファイルで直接テーマを定義する。`tailwind.config.js` は不要。

```css
/* app.css */
@import "tailwindcss";

@theme {
  /* カラートークン（セマンティック命名） */
  --color-primary: oklch(0.55 0.2 250);
  --color-primary-hover: oklch(0.48 0.2 250);
  --color-surface: oklch(0.98 0 0);
  --color-surface-elevated: oklch(1 0 0);
  --color-on-surface: oklch(0.15 0 0);
  --color-on-surface-muted: oklch(0.45 0 0);
  --color-error: oklch(0.55 0.2 25);

  /* スペーシング */
  --spacing-xs: 0.25rem;
  --spacing-sm: 0.5rem;
  --spacing-md: 1rem;
  --spacing-lg: 1.5rem;
  --spacing-xl: 2rem;

  /* タイポグラフィ */
  --font-sans: "Inter Variable", system-ui, sans-serif;
  --font-mono: "JetBrains Mono", monospace;

  /* ボーダー半径 */
  --radius-sm: 0.25rem;
  --radius-md: 0.5rem;
  --radius-lg: 1rem;
  --radius-full: 9999px;
}
```

### セマンティックカラー命名

```
原則:
- 用途ベースで命名する（primary, surface, error）
- 色名を直接使わない（blue-500 → primary）
- ダークモード切替はトークンの値を変えるだけで対応

命名体系:
  --color-{role}         → primary, secondary, error, warning, success
  --color-surface        → 背景
  --color-surface-elevated → カード等の浮き上がった背景
  --color-on-{surface}   → surface 上のテキスト/アイコン
  --color-border         → デフォルトのボーダー
```

詳細なトークン設計: [references/design-tokens.md](references/design-tokens.md)

## 親子要素の相対値設計

### em 系ユーティリティの活用

```html
<!-- 親要素でベースサイズを定義 -->
<div class="text-base p-4">
  <!-- 子要素は em ベースで親に追従 -->
  <h3 class="text-[1.25em] mb-[0.5em]">タイトル</h3>
  <p class="text-[0.875em] leading-[1.6em]">本文テキスト</p>
</div>

<!-- バリエーションは親のサイズを変えるだけ -->
<div class="text-lg p-6">
  <h3 class="text-[1.25em] mb-[0.5em]">大きいバリアント</h3>
  <p class="text-[0.875em] leading-[1.6em]">同じ比率で拡大</p>
</div>
```

### Container Queries パターン

```html
<div class="@container">
  <div class="flex flex-col @md:flex-row @md:gap-6 gap-3">
    <img class="w-full @md:w-1/3 rounded-md" src="..." alt="" />
    <div class="flex-1">
      <h3 class="text-lg @md:text-xl">タイトル</h3>
      <p class="text-sm @md:text-base">説明テキスト</p>
    </div>
  </div>
</div>
```

### CSS 変数との連携

```html
<div class="[--card-spacing:1rem] p-[var(--card-spacing)]">
  <h3 class="mb-[calc(var(--card-spacing)*0.5)]">タイトル</h3>
  <p class="mt-[calc(var(--card-spacing)*0.75)]">本文</p>
</div>
```

## レスポンシブ設計

### モバイルファースト

```
原則:
- デフォルトスタイルはモバイル向け
- ブレークポイントは min-width（sm:, md:, lg:, xl:）
- コンポーネント単位のレスポンシブには @container を優先
```

```html
<!-- モバイル: 1列、md以上: 2列、lg以上: 3列 -->
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
  <div>...</div>
</div>
```

### Fluid Spacing

```html
<!-- clamp() で滑らかなスペーシング -->
<section class="p-[clamp(1rem,4vw,3rem)]">
  <h2 class="text-[clamp(1.5rem,3vw+0.5rem,2.5rem)]">見出し</h2>
</section>
```

## ダークモード

### class 戦略

```html
<!-- html または body に dark クラスを付与 -->
<html class="dark">
  <body class="bg-surface text-on-surface">
    <div class="bg-surface-elevated dark:bg-surface-elevated">
      ...
    </div>
  </body>
</html>
```

### セマンティックトークンによる切替

```css
@theme {
  --color-surface: oklch(0.98 0 0);
  --color-on-surface: oklch(0.15 0 0);
}

/* ダークモードはトークンの値を上書き */
.dark {
  --color-surface: oklch(0.15 0 0);
  --color-on-surface: oklch(0.95 0 0);
}
```

```
利点:
- コンポーネント側に dark: プレフィックスが不要
- テーマ切替がトークンの値変更だけで完結
- 新しいテーマ（high-contrast 等）の追加も容易
```

## コンポーネント抽出

### 判断基準

```
抽出する:
- 同じクラスの組み合わせが 3 箇所以上で重複
- ロジック（状態管理、イベント処理）を伴う UI

抽出しない:
- 1-2 箇所でしか使わないスタイル
- ユーティリティクラスの単純なグルーピング
```

### フレームワークコンポーネント優先

```tsx
// ✅ React/Vue 等のコンポーネントで抽出
function Button({ variant = "primary", size = "md", children }) {
  return (
    <button className={cn(
      "inline-flex items-center justify-center rounded-md font-medium transition-colors",
      "focus-visible:outline-2 focus-visible:outline-offset-2",
      variants[variant],
      sizes[size],
    )}>
      {children}
    </button>
  );
}
```

### cn() ユーティリティ

`cn()` = clsx + tailwind-merge。条件付きクラス結合と Tailwind クラスの競合解決を行う。セットアップと詳細な使い方: [references/component-patterns.md](references/component-patterns.md)

### @apply の許容ケース

```css
/* ✅ フレームワーク非依存の基本スタイル（typography 等） */
@layer base {
  .prose h2 {
    @apply text-xl font-semibold mt-8 mb-4;
  }
}

/* ❌ コンポーネントスタイルの抽出 → フレームワークコンポーネントを使う */
```

詳細なパターン: [references/component-patterns.md](references/component-patterns.md)

## パフォーマンス

```
v4 の最適化:
- Rust ベースの新エンジンで高速ビルド
- CSS ファースト設定でビルドステップ削減
- JIT（Just-In-Time）が標準: 使用クラスのみ出力
- PostCSS / Sass / Less 等のプリプロセッサは不要
- Lightning CSS による最適化・ベンダープレフィックス自動付与

実装時の注意:
- 動的クラス名を構築しない（JIT が検出できない）
- safelist は最小限に抑える
- @import による CSS 分割で必要な部分だけロード
```

## 公式プラグイン

| プラグイン | 用途 | v4 での状態 |
|-----------|------|------------|
| `@tailwindcss/typography` | `.prose` クラスでリッチテキストスタイリング | v4 対応済み |
| `@tailwindcss/forms` | フォーム要素のリセット・スタイリング | v4 対応済み |
| `@tailwindcss/container-queries` | `@container` ユーティリティ | v4 にネイティブ統合 |

## アンチパターン

| NG | OK | 理由 |
|----|-----|------|
| `@apply` でコンポーネント作成 | フレームワークコンポーネント | 再利用性・保守性が高い |
| `text-${color}-500` | `text-primary` / 完全なクラス名 | JIT が検出できない |
| `bg-blue-500` 直書き | `bg-primary`（トークン参照） | テーマ変更に対応不可 |
| 任意値 `[37px]` の多用 | トークン定義して使用 | 一貫性がなくなる |
| `dark:bg-gray-800` 全箇所 | セマンティックトークンで切替 | 変更箇所が散在する |
| `className={条件 ? "..." : "..."}` | `cn()` で統合 | クラスの競合が起きる |
| `style={{ fontSize: 14 }}` | Tailwind ユーティリティ | 一貫性を損なう |
| 子要素に固定サイズ `w-[300px]` | `w-full` / 親の `%` ベース | 親に追従しない |
| `sm:` だけでレスポンシブ | `@container` を優先 | コンポーネント単位で適応 |

## レビューチェックリスト

- [ ] 親要素でベースサイズを定義し、子要素が相対値で設計されている
- [ ] `@theme` でデザイントークンが定義されている
- [ ] 動的クラス名構築を行っていない
- [ ] `@apply` をコンポーネント抽出に使用していない
- [ ] カラーがセマンティックトークンで参照されている
- [ ] ダークモードがトークン切替で対応されている
- [ ] `@container` がコンポーネント単位のレスポンシブに活用されている
- [ ] 任意値 `[value]` が最小限（3 箇所以上ならトークン化検討）

## リファレンス

- [references/design-tokens.md](references/design-tokens.md) - トークン 3 層構造（Primitive → Semantic → Component）、@theme 完全設定例
- [references/component-patterns.md](references/component-patterns.md) - cva パターン、cn() セットアップ、レイアウトコンポーネント、@apply 許容ケース
