# コンポーネント共通化

## 原則

1. **同じものは共通化すべき** — DRY 原則
2. **1コンポーネント = 1機能** — 単一責任
3. **合成優先** — 継承より組み合わせ
4. **デザイントークンで一元管理** — CSS Custom Properties

## 共通化の判断基準

### 共通化すべき

- 3回以上同じパターンが出現
- ボタン、入力フィールド、カードなどの基本要素
- 色、スペーシング、タイポグラフィなどのスタイル値

### 共通化しない

- 2回以下の出現（YAGNI）
- 微妙に異なる要素を無理に抽象化
- 過度に柔軟な「万能コンポーネント」

## デザイントークン

```css
:root {
  /* カラー */
  --color-primary: #0284C7;
  --color-text: #1F2937;
  --color-border: #E5E7EB;

  /* スペーシング */
  --spacing-xs: 0.25rem;
  --spacing-sm: 0.5rem;
  --spacing-md: 1rem;
  --spacing-lg: 1.5rem;

  /* タイポグラフィ */
  --font-size-sm: 0.875rem;
  --font-size-base: 1rem;
  --font-size-lg: 1.125rem;

  /* ボーダー半径 */
  --radius-sm: 0.25rem;
  --radius-md: 0.5rem;
  --radius-lg: 0.75rem;
}
```

## コンポーネント設計パターン

### Base + Variant

```tsx
// Base component
function Button({ variant = 'primary', size = 'md', children }) {
  return (
    <button className={`btn btn-${variant} btn-${size}`}>
      {children}
    </button>
  );
}

// Usage
<Button variant="primary" size="lg">Submit</Button>
<Button variant="secondary">Cancel</Button>
```

### Composition

```tsx
// 小さなパーツを組み合わせ
function Card({ children }) {
  return <div className="card">{children}</div>;
}

function CardHeader({ children }) {
  return <div className="card-header">{children}</div>;
}

function CardBody({ children }) {
  return <div className="card-body">{children}</div>;
}

// Usage
<Card>
  <CardHeader>Title</CardHeader>
  <CardBody>Content</CardBody>
</Card>
```
