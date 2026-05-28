# デザイントークン抽出

## Figma Variables → CSS Custom Properties

### カラートークン

**Figma Variables:**
```
color/primitive/blue/50: #F0F9FF
color/primitive/blue/500: #0284C7
color/primitive/blue/900: #0C2D4B

color/semantic/text/primary: color/primitive/blue/900
color/semantic/bg/base: white
```

**CSS:**
```css
:root {
  /* Primitive */
  --color-blue-50: #F0F9FF;
  --color-blue-500: #0284C7;
  --color-blue-900: #0C2D4B;

  /* Semantic */
  --color-text-primary: var(--color-blue-900);
  --color-bg-base: white;
}
```

### スペーシングトークン

**Figma Variables:**
```
spacing/xs: 4px
spacing/sm: 8px
spacing/md: 16px
spacing/lg: 24px
spacing/xl: 32px
```

**CSS:**
```css
:root {
  --spacing-xs: 0.25rem;
  --spacing-sm: 0.5rem;
  --spacing-md: 1rem;
  --spacing-lg: 1.5rem;
  --spacing-xl: 2rem;
}
```

### タイポグラフィトークン

**Figma Variables:**
```
font/family/base: Inter
font/size/sm: 14px
font/size/base: 16px
font/size/lg: 18px
font/weight/normal: 400
font/weight/medium: 500
font/weight/bold: 700
```

**CSS:**
```css
:root {
  --font-family-base: Inter, -apple-system, sans-serif;
  --font-size-sm: 0.875rem;
  --font-size-base: 1rem;
  --font-size-lg: 1.125rem;
  --font-weight-normal: 400;
  --font-weight-medium: 500;
  --font-weight-bold: 700;
}
```

## ダークモード対応

**Figma:**
```
Mode: Light
  color/semantic/text/primary: color/primitive/blue/900
  color/semantic/bg/base: white

Mode: Dark
  color/semantic/text/primary: color/primitive/blue/50
  color/semantic/bg/base: color/primitive/blue/900
```

**CSS:**
```css
:root {
  --color-text-primary: var(--color-blue-900);
  --color-bg-base: white;
}

@media (prefers-color-scheme: dark) {
  :root {
    --color-text-primary: var(--color-blue-50);
    --color-bg-base: var(--color-blue-900);
  }
}
```

## 抽出ツール

### get_variable_defs の使用

```
MCP ツール: get_variable_defs
- Figma ファイルからすべての Variables を取得
- Collection ごとに整理
- Mode 情報も含む
```

### 変換手順

1. `get_variable_defs` で Variables 取得
2. Primitive → Semantic の階層を維持
3. CSS Custom Properties として出力
4. ダークモード用の値を `@media` で定義
