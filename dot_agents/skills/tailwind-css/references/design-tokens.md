# Tailwind CSS デザイントークン設計

SKILL.md の「v4 設定 (@theme)」セクションの詳細設計パターン集。ここではトークンの 3 層構造と完全な @theme 設定例を扱う。

## 目次

- [トークンの 3 層構造](#トークンの-3-層構造)
- [カラートークン](#カラートークン)
- [スペーシングトークン](#スペーシングトークン)
- [タイポグラフィトークン](#タイポグラフィトークン)
- [その他のトークン](#その他のトークン)
- [@theme スターター設定](#theme-スターター設定)

## トークンの 3 層構造

```
Primitive（原始値）
  → 生の値を定義。直接使用しない
  例: --color-blue-500, --space-4, --font-size-16

Semantic（意味トークン）
  → 用途に基づく名前。コンポーネントで使用する
  例: --color-primary, --spacing-md, --text-body

Component（コンポーネントトークン）
  → 特定コンポーネントに限定されたトークン
  例: --button-padding, --card-radius, --nav-height
```

### Tailwind CSS v4 での実装

```css
/* Primitive: @theme 外で CSS 変数として定義 */
:root {
  --primitive-blue-50: oklch(0.97 0.02 250);
  --primitive-blue-100: oklch(0.93 0.05 250);
  --primitive-blue-500: oklch(0.55 0.2 250);
  --primitive-blue-600: oklch(0.48 0.2 250);
  --primitive-blue-900: oklch(0.25 0.1 250);

  --primitive-neutral-50: oklch(0.98 0 0);
  --primitive-neutral-100: oklch(0.95 0 0);
  --primitive-neutral-800: oklch(0.25 0 0);
  --primitive-neutral-900: oklch(0.15 0 0);
}

/* Semantic: @theme で Tailwind ユーティリティとして登録 */
@theme {
  --color-primary: var(--primitive-blue-500);
  --color-primary-hover: var(--primitive-blue-600);
  --color-surface: var(--primitive-neutral-50);
  --color-on-surface: var(--primitive-neutral-900);
}
```

## カラートークン

### 命名体系

```
Surface 系（背景）:
  --color-surface           → メインの背景色
  --color-surface-elevated  → カード、モーダル等の浮いた背景
  --color-surface-sunken    → インプット等の凹んだ背景

On-Surface 系（テキスト・アイコン）:
  --color-on-surface        → メインのテキスト色
  --color-on-surface-muted  → 補助テキスト
  --color-on-surface-subtle → プレースホルダー等

Role 系（意味色）:
  --color-primary           → メインアクション
  --color-primary-hover     → ホバー状態
  --color-secondary         → サブアクション
  --color-error             → エラー
  --color-warning           → 警告
  --color-success           → 成功
  --color-info              → 情報

Border 系:
  --color-border            → デフォルトのボーダー
  --color-border-strong     → 強調ボーダー
  --color-border-subtle     → 薄いボーダー
```

### oklch カラースペース

```
oklch(L C H) の構成:
  L: Lightness（明度） 0〜1
  C: Chroma（彩度）   0〜0.4+
  H: Hue（色相）      0〜360

利点:
- 知覚的に均一な明るさ調整
- ダークモードで L 値を反転するだけで自然な配色
- 色相を変えても同じ明るさに見える

例:
  oklch(0.55 0.2 250) → 中明度の青
  oklch(0.55 0.2 25)  → 同じ明るさの赤
  oklch(0.85 0.1 250) → 明るい青（ダークモードの背景向き）
```

## スペーシングトークン

### スケール設計

```css
@theme {
  /* 4px ベースのスケール */
  --spacing-px: 1px;
  --spacing-0: 0;
  --spacing-0.5: 0.125rem;  /* 2px */
  --spacing-1: 0.25rem;     /* 4px */
  --spacing-1.5: 0.375rem;  /* 6px */
  --spacing-2: 0.5rem;      /* 8px */
  --spacing-3: 0.75rem;     /* 12px */
  --spacing-4: 1rem;        /* 16px */
  --spacing-5: 1.25rem;     /* 20px */
  --spacing-6: 1.5rem;      /* 24px */
  --spacing-8: 2rem;        /* 32px */
  --spacing-10: 2.5rem;     /* 40px */
  --spacing-12: 3rem;       /* 48px */
  --spacing-16: 4rem;       /* 64px */
  --spacing-20: 5rem;       /* 80px */
  --spacing-24: 6rem;       /* 96px */
}
```

### セマンティックスペーシング（オプション）

```css
/* 用途ベースのエイリアス */
:root {
  --space-xs: var(--spacing-1);    /* 4px:  密なインライン要素間 */
  --space-sm: var(--spacing-2);    /* 8px:  関連要素間 */
  --space-md: var(--spacing-4);    /* 16px: セクション内要素間 */
  --space-lg: var(--spacing-8);    /* 32px: セクション間 */
  --space-xl: var(--spacing-16);   /* 64px: 大きなセクション間 */
}
```

## タイポグラフィトークン

### フォントサイズスケール

```css
@theme {
  --text-xs: 0.75rem;     /* 12px */
  --text-sm: 0.875rem;    /* 14px */
  --text-base: 1rem;      /* 16px */
  --text-lg: 1.125rem;    /* 18px */
  --text-xl: 1.25rem;     /* 20px */
  --text-2xl: 1.5rem;     /* 24px */
  --text-3xl: 1.875rem;   /* 30px */
  --text-4xl: 2.25rem;    /* 36px */
}
```

### フォントファミリー

```css
@theme {
  /* Variable Font 推奨 */
  --font-sans: "Inter Variable", "Noto Sans JP Variable", system-ui, sans-serif;
  --font-mono: "JetBrains Mono Variable", ui-monospace, monospace;

  /* ウェイト */
  --font-weight-normal: 400;
  --font-weight-medium: 500;
  --font-weight-semibold: 600;
  --font-weight-bold: 700;

  /* 行間 */
  --leading-tight: 1.25;
  --leading-normal: 1.5;
  --leading-relaxed: 1.75;
}
```

## その他のトークン

### ボーダー・シャドウ

```css
@theme {
  /* ボーダー半径 */
  --radius-none: 0;
  --radius-sm: 0.25rem;
  --radius-md: 0.5rem;
  --radius-lg: 0.75rem;
  --radius-xl: 1rem;
  --radius-full: 9999px;

  /* シャドウ */
  --shadow-sm: 0 1px 2px oklch(0 0 0 / 0.05);
  --shadow-md: 0 4px 6px oklch(0 0 0 / 0.07), 0 2px 4px oklch(0 0 0 / 0.05);
  --shadow-lg: 0 10px 15px oklch(0 0 0 / 0.1), 0 4px 6px oklch(0 0 0 / 0.05);
  --shadow-xl: 0 20px 25px oklch(0 0 0 / 0.1), 0 8px 10px oklch(0 0 0 / 0.04);
}
```

### トランジション

```css
@theme {
  --ease-default: cubic-bezier(0.4, 0, 0.2, 1);
  --ease-in: cubic-bezier(0.4, 0, 1, 1);
  --ease-out: cubic-bezier(0, 0, 0.2, 1);
  --ease-in-out: cubic-bezier(0.4, 0, 0.2, 1);

  --duration-fast: 150ms;
  --duration-normal: 300ms;
  --duration-slow: 500ms;
}
```

## @theme スターター設定

```css
@import "tailwindcss";

/* ========================================
   Primitive Tokens（直接使用しない）
   ======================================== */
:root {
  /* Blue */
  --primitive-blue-50: oklch(0.97 0.02 250);
  --primitive-blue-500: oklch(0.55 0.2 250);
  --primitive-blue-600: oklch(0.48 0.2 250);

  /* Red */
  --primitive-red-500: oklch(0.55 0.2 25);
  --primitive-red-600: oklch(0.48 0.2 25);

  /* Green */
  --primitive-green-500: oklch(0.55 0.17 150);

  /* Amber */
  --primitive-amber-500: oklch(0.75 0.15 75);

  /* Neutral */
  --primitive-neutral-50: oklch(0.98 0 0);
  --primitive-neutral-100: oklch(0.95 0 0);
  --primitive-neutral-200: oklch(0.9 0 0);
  --primitive-neutral-400: oklch(0.65 0 0);
  --primitive-neutral-500: oklch(0.55 0 0);
  --primitive-neutral-800: oklch(0.25 0 0);
  --primitive-neutral-900: oklch(0.15 0 0);
  --primitive-neutral-950: oklch(0.1 0 0);
}

/* ========================================
   Semantic Tokens（@theme で登録）
   ======================================== */
@theme {
  /* Color: Role */
  --color-primary: var(--primitive-blue-500);
  --color-primary-hover: var(--primitive-blue-600);
  --color-error: var(--primitive-red-500);
  --color-error-hover: var(--primitive-red-600);
  --color-warning: var(--primitive-amber-500);
  --color-success: var(--primitive-green-500);

  /* Color: Surface */
  --color-surface: var(--primitive-neutral-50);
  --color-surface-elevated: white;
  --color-surface-sunken: var(--primitive-neutral-100);

  /* Color: On-Surface */
  --color-on-surface: var(--primitive-neutral-900);
  --color-on-surface-muted: var(--primitive-neutral-500);
  --color-on-primary: white;

  /* Color: Border */
  --color-border: var(--primitive-neutral-200);
  --color-border-strong: var(--primitive-neutral-400);

  /* Typography */
  --font-sans: "Inter Variable", system-ui, sans-serif;
  --font-mono: "JetBrains Mono Variable", ui-monospace, monospace;

  /* Spacing */
  --spacing-xs: 0.25rem;
  --spacing-sm: 0.5rem;
  --spacing-md: 1rem;
  --spacing-lg: 1.5rem;
  --spacing-xl: 2rem;
  --spacing-2xl: 3rem;

  /* Border Radius */
  --radius-sm: 0.25rem;
  --radius-md: 0.5rem;
  --radius-lg: 0.75rem;
  --radius-xl: 1rem;
  --radius-full: 9999px;

  /* Shadow */
  --shadow-sm: 0 1px 2px oklch(0 0 0 / 0.05);
  --shadow-md: 0 4px 6px oklch(0 0 0 / 0.07), 0 2px 4px oklch(0 0 0 / 0.05);
  --shadow-lg: 0 10px 15px oklch(0 0 0 / 0.1), 0 4px 6px oklch(0 0 0 / 0.05);
}

/* ========================================
   Dark Mode Override
   ======================================== */
.dark {
  --color-primary: oklch(0.7 0.15 250);
  --color-primary-hover: oklch(0.75 0.15 250);
  --color-error: oklch(0.7 0.15 25);
  --color-warning: oklch(0.8 0.12 75);
  --color-success: oklch(0.7 0.13 150);

  --color-surface: var(--primitive-neutral-950);
  --color-surface-elevated: var(--primitive-neutral-800);
  --color-surface-sunken: oklch(0.08 0 0);

  --color-on-surface: oklch(0.95 0 0);
  --color-on-surface-muted: var(--primitive-neutral-400);

  --color-border: oklch(0.3 0 0);
  --color-border-strong: var(--primitive-neutral-500);

  --shadow-sm: 0 1px 2px oklch(0 0 0 / 0.2);
  --shadow-md: 0 4px 6px oklch(0 0 0 / 0.3), 0 2px 4px oklch(0 0 0 / 0.2);
  --shadow-lg: 0 10px 15px oklch(0 0 0 / 0.4), 0 4px 6px oklch(0 0 0 / 0.2);
}
```
