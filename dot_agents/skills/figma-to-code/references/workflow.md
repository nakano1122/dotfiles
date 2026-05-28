# Figma → Code ワークフロー詳細

## Step 1: デザイン情報の収集

### 1.1 ファイル構造の把握

```
get_metadata を使用:
- ページ一覧
- フレーム構造
- コンポーネント一覧
```

### 1.2 ターゲットノードの特定

```
- Figma URL からノード ID を抽出
- 大規模デザインは小分割でノード単位に処理
```

### 1.3 デザインコンテキストの取得

```
get_design_context を使用:
- レイアウト情報
- スタイル情報
- Code Connect マッピング
```

## Step 2: 構造の分析

### 2.1 レイアウト階層の把握

```
Container (親)
├── Header (子)
│   ├── Logo
│   └── Navigation
├── Main (子)
│   └── Content
└── Footer (子)
```

### 2.2 共通パターンの特定

```
- 繰り返し要素 → コンポーネント化
- 類似スタイル → デザイントークン化
```

## Step 3: コード生成

### 3.1 親から子の順に実装

```tsx
// 1. Container（親）
function Layout({ children }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column' }}>
      {children}
    </div>
  );
}

// 2. Header（子）
function Header() {
  return (
    <header style={{ display: 'flex', justifyContent: 'space-between' }}>
      <Logo />
      <Navigation />
    </header>
  );
}
```

### 3.2 スタイルの適用

```tsx
// デザイントークンを使用
const styles = {
  container: {
    padding: 'var(--spacing-lg)',
    gap: 'var(--spacing-md)',
  },
};
```

## Step 4: 検証

### 4.1 ビジュアル比較

```
- get_screenshot でオリジナルを取得
- 実装結果と比較
```

### 4.2 レスポンシブ確認

```
- モバイル幅 (375px)
- タブレット幅 (768px)
- デスクトップ幅 (1280px)
```

### 4.3 インタラクション確認

```
- ホバー状態
- フォーカス状態
- アクティブ状態
```
