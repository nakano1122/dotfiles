# CSS パフォーマンス最適化パターン

SKILL.md の「パフォーマンス」セクションの詳細パターン集。ここでは具体的な実装パターンと設定例を扱う。

## 目次

- [Critical CSS](#critical-css)
- [content-visibility 詳細](#content-visibility-詳細)
- [アニメーション最適化](#アニメーション最適化)
- [リソース読み込み戦略](#リソース読み込み戦略)
- [フォント最適化](#フォント最適化)

## Critical CSS

### インライン Critical CSS

```html
<head>
  <!-- Critical CSS: ファーストビューに必要なスタイルのみインライン化 -->
  <style>
    /* リセット */
    *, *::before, *::after { box-sizing: border-box; margin: 0; }

    /* ファーストビューのレイアウト */
    .header { display: flex; align-items: center; padding: 1rem; }
    .hero { min-height: 60vh; display: grid; place-items: center; }
  </style>

  <!-- 残りの CSS は非同期ロード -->
  <link rel="preload" href="/styles/main.css" as="style"
        onload="this.onload=null;this.rel='stylesheet'">
  <noscript><link rel="stylesheet" href="/styles/main.css"></noscript>
</head>
```

### 抽出の目安

```
Critical CSS に含めるもの:
- リセット / 正規化
- ファーストビューのレイアウト（header, hero）
- フォント宣言（font-face の一部）
- ベースのカラー・タイポグラフィ

含めないもの:
- スクロール下のコンポーネント
- hover / focus 等のインタラクション
- アニメーション定義
- メディアクエリの大部分
```

### 自動化ツール

```
- critters: ビルド時に Critical CSS を自動抽出・インライン化
- critical: HTMLからファーストビューCSSを抽出
- Next.js / Nuxt: フレームワークが自動処理
```

## content-visibility 詳細

### 基本パターン

```css
/* スクロール下のセクションに適用 */
.lazy-section {
  content-visibility: auto;
  contain-intrinsic-size: auto 500px; /* 推定高さ */
}

/* auto キーワードで実測値を記憶 */
/* 一度レンダリングされた後は実測サイズを使用 */
```

### 適用判断

```
✅ 適用すべき場所:
- 長いリスト・フィードの各アイテム
- タブパネルの非表示コンテンツ
- アコーディオンの閉じたパネル
- フッター付近のセクション
- 大量の商品カード

❌ 避けるべき場所:
- ファーストビュー内の要素
- アニメーション中の要素
- position: sticky を含む要素
- ユーザーがすぐスクロールする短いページ
```

### contain-intrinsic-size の設定

```css
/* 高さのみ指定（幅は親に追従） */
.item { contain-intrinsic-size: auto 200px; }

/* 幅と高さを指定 */
.card { contain-intrinsic-size: auto 300px auto 400px; }

/* auto を付けると一度レンダリング後に実測値を記憶 */
/* auto なしだと常に推定値を使用 */
```

## アニメーション最適化

### GPU 合成レイヤーの活用

```css
/* ✅ GPU で処理されるプロパティ */
.optimized {
  transform: translateX(100px);    /* GPU */
  opacity: 0.5;                    /* GPU */
  filter: blur(4px);               /* GPU */
}

/* ❌ レイアウト再計算が発生するプロパティ */
.expensive {
  width: 200px;      /* レイアウト → ペイント → 合成 */
  height: 200px;     /* レイアウト → ペイント → 合成 */
  top: 10px;         /* レイアウト → ペイント → 合成 */
  margin-left: 20px; /* レイアウト → ペイント → 合成 */
}
```

### will-change の適切な使用

```css
/* ❌ 常時指定（メモリ浪費） */
.always-ready {
  will-change: transform;
}

/* ✅ アニメーション直前に付与、完了後に除去 */
.card:hover {
  will-change: transform;
}

/* ✅ JavaScript で動的に制御 */
/* element.style.willChange = 'transform'; */
/* → アニメーション実行 */
/* → element.style.willChange = 'auto'; */
```

### @media (prefers-reduced-motion)

```css
/* モーション軽減設定を尊重 */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

### View Transitions API

```css
/* ページ遷移アニメーション（SPA 向け） */
@view-transition {
  navigation: auto;
}

::view-transition-old(root) {
  animation: fade-out 300ms ease;
}

::view-transition-new(root) {
  animation: fade-in 300ms ease;
}

/* 特定要素のトランジション */
.card {
  view-transition-name: card-detail;
}
```

## リソース読み込み戦略

### メディアクエリ付きリンク

```html
<!-- デバイスに応じて条件付きロード -->
<link rel="stylesheet" href="/styles/base.css">
<link rel="stylesheet" href="/styles/desktop.css" media="(min-width: 1024px)">
<link rel="stylesheet" href="/styles/print.css" media="print">
```

### CSS の分割戦略

```
推奨構成:
1. critical.css   → インライン化（ファーストビュー）
2. base.css       → 同期ロード（リセット・変数・基本スタイル）
3. components.css → 非同期ロード（コンポーネント）
4. utilities.css  → 非同期ロード（ユーティリティ）
```

### 未使用 CSS の削除

```
ビルド時:
- PurgeCSS: HTML/JSX から使用クラスを検出し、未使用を削除
- Tailwind CSS v4: JIT で自動的に使用クラスのみ出力

開発時の確認:
- Chrome DevTools Coverage タブで未使用率を確認
- 50% 以上未使用なら分割を検討
```

## フォント最適化

### font-display 戦略

```css
@font-face {
  font-family: "Inter";
  src: url("/fonts/inter-var.woff2") format("woff2");
  font-weight: 100 900;
  font-display: swap; /* テキストを即座に表示、フォント読み込み後に切替 */
}
```

### プリロード

```html
<!-- 最も重要なフォントのみプリロード（1-2 ファイルまで） -->
<link rel="preload" href="/fonts/inter-var.woff2" as="font"
      type="font/woff2" crossorigin>
```

### サブセット化

```
日本語フォント:
- unicode-range で必要な文字範囲のみロード
- Google Fonts は自動でサブセット分割

欧文フォント:
- Variable Font（1ファイルで全ウェイト対応）
- WOFF2 形式を優先（最も高い圧縮率）
```

```css
/* unicode-range でサブセット指定 */
@font-face {
  font-family: "Noto Sans JP";
  src: url("/fonts/noto-sans-jp-latin.woff2") format("woff2");
  unicode-range: U+0000-00FF; /* ラテン文字のみ */
  font-display: swap;
}

@font-face {
  font-family: "Noto Sans JP";
  src: url("/fonts/noto-sans-jp-kana.woff2") format("woff2");
  unicode-range: U+3000-30FF, U+FF00-FFEF; /* かな・カナ */
  font-display: swap;
}
```
