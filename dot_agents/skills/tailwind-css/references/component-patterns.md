# Tailwind CSS コンポーネントパターン

SKILL.md の「コンポーネント抽出」セクションの詳細パターン集。ここでは抽出判断基準の深掘り、cva パターン、レイアウトコンポーネントを扱う。

## 目次

- [コンポーネント抽出の判断基準](#コンポーネント抽出の判断基準)
- [cva パターン](#cva-パターン)
- [cn() セットアップ](#cn-セットアップ)
- [レイアウトコンポーネント](#レイアウトコンポーネント)
- [@apply 許容ケース](#apply-許容ケース)

## コンポーネント抽出の判断基準

### 抽出フロー

```
同じクラスの組み合わせが何箇所で使われている？

  1-2 箇所 → 抽出しない（コピーで十分）
  3+ 箇所 → 次の質問へ

    ロジック（状態、イベント）を伴う？
      Yes → フレームワークコンポーネントとして抽出
      No  → 次の質問へ

        バリエーション（サイズ、色、状態）がある？
          Yes → cva でバリアント管理
          No  → シンプルなコンポーネント
```

### 抽出の粒度

```
✅ 適切な粒度:
  Button, Card, Badge, Input, Avatar, Modal
  → 独立して再利用可能な UI 単位

❌ 細かすぎる:
  RedText, LargeFont, FlexCenter
  → ユーティリティクラスで十分

❌ 大きすぎる:
  Header（内部にNav, Logo, SearchBar等を含む）
  → 内部を個別コンポーネントに分割
```

## cva パターン

### class-variance-authority (cva)

```typescript
import { cva, type VariantProps } from "class-variance-authority";

const buttonVariants = cva(
  // ベーススタイル
  "inline-flex items-center justify-center rounded-md font-medium transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 disabled:pointer-events-none disabled:opacity-50",
  {
    variants: {
      variant: {
        primary: "bg-primary text-on-primary hover:bg-primary-hover",
        secondary: "bg-surface-elevated text-on-surface border border-border hover:bg-surface-sunken",
        ghost: "text-on-surface hover:bg-surface-sunken",
        destructive: "bg-error text-on-primary hover:bg-error-hover",
      },
      size: {
        sm: "h-8 px-3 text-sm gap-1.5",
        md: "h-10 px-4 text-sm gap-2",
        lg: "h-12 px-6 text-base gap-2.5",
      },
    },
    defaultVariants: {
      variant: "primary",
      size: "md",
    },
  }
);

type ButtonProps = React.ButtonHTMLAttributes<HTMLButtonElement> &
  VariantProps<typeof buttonVariants>;

function Button({ variant, size, className, ...props }: ButtonProps) {
  return (
    <button className={cn(buttonVariants({ variant, size }), className)} {...props} />
  );
}
```

### バッジの例

```typescript
const badgeVariants = cva(
  "inline-flex items-center rounded-full font-medium",
  {
    variants: {
      variant: {
        default: "bg-surface-sunken text-on-surface",
        primary: "bg-primary/10 text-primary",
        success: "bg-success/10 text-success",
        warning: "bg-warning/10 text-warning",
        error: "bg-error/10 text-error",
      },
      size: {
        sm: "px-2 py-0.5 text-xs",
        md: "px-2.5 py-1 text-sm",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "md",
    },
  }
);
```

### インプットの例

```typescript
const inputVariants = cva(
  "flex w-full rounded-md border bg-surface-sunken text-on-surface transition-colors placeholder:text-on-surface-subtle focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary disabled:cursor-not-allowed disabled:opacity-50",
  {
    variants: {
      size: {
        sm: "h-8 px-3 text-sm",
        md: "h-10 px-3 text-sm",
        lg: "h-12 px-4 text-base",
      },
      state: {
        default: "border-border",
        error: "border-error focus-visible:outline-error",
      },
    },
    defaultVariants: {
      size: "md",
      state: "default",
    },
  }
);
```

## cn() セットアップ

### インストール

```bash
npm install clsx tailwind-merge
```

### 実装

```typescript
// lib/utils.ts
import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

### 使い方

```tsx
// clsx: 条件付きクラス名の結合
cn("base-class", isActive && "active", variant === "primary" && "bg-primary")

// tailwind-merge: 競合するクラスの解決
cn("px-4 py-2", "px-6") // → "py-2 px-6" (px-4 が px-6 で上書き)

// コンポーネントでの活用
function Card({ className, ...props }) {
  return <div className={cn("rounded-lg border p-4", className)} {...props} />;
}

// 使用側でスタイルを上書き可能
<Card className="p-8 border-primary" />
// → "rounded-lg border p-8 border-primary"
```

## レイアウトコンポーネント

### Stack（縦積み）

```tsx
type StackProps = {
  gap?: string;
  children: React.ReactNode;
  className?: string;
};

function Stack({ gap = "gap-4", children, className }: StackProps) {
  return (
    <div className={cn("flex flex-col", gap, className)}>
      {children}
    </div>
  );
}

// 使用例
<Stack gap="gap-6">
  <Heading>タイトル</Heading>
  <Paragraph>本文</Paragraph>
  <Button>アクション</Button>
</Stack>
```

### Cluster（横並び・折り返し）

```tsx
type ClusterProps = {
  gap?: string;
  align?: string;
  justify?: string;
  children: React.ReactNode;
  className?: string;
};

function Cluster({
  gap = "gap-3",
  align = "items-center",
  justify = "justify-start",
  children,
  className,
}: ClusterProps) {
  return (
    <div className={cn("flex flex-wrap", gap, align, justify, className)}>
      {children}
    </div>
  );
}

// 使用例: タグリスト
<Cluster gap="gap-2">
  <Badge>React</Badge>
  <Badge>TypeScript</Badge>
  <Badge>Tailwind</Badge>
</Cluster>
```

### Grid（グリッドレイアウト）

```tsx
type GridProps = {
  cols?: string;
  gap?: string;
  children: React.ReactNode;
  className?: string;
};

function Grid({
  cols = "grid-cols-1 md:grid-cols-2 lg:grid-cols-3",
  gap = "gap-4",
  children,
  className,
}: GridProps) {
  return (
    <div className={cn("grid", cols, gap, className)}>
      {children}
    </div>
  );
}

// 使用例
<Grid cols="grid-cols-1 @md:grid-cols-2 @lg:grid-cols-3">
  <Card>...</Card>
  <Card>...</Card>
  <Card>...</Card>
</Grid>
```

### Container（コンテンツ幅制限）

```tsx
type ContainerProps = {
  size?: "sm" | "md" | "lg" | "xl";
  children: React.ReactNode;
  className?: string;
};

const containerSizes = {
  sm: "max-w-2xl",
  md: "max-w-4xl",
  lg: "max-w-6xl",
  xl: "max-w-7xl",
};

function Container({ size = "lg", children, className }: ContainerProps) {
  return (
    <div className={cn("mx-auto w-full px-4 md:px-6", containerSizes[size], className)}>
      {children}
    </div>
  );
}
```

## @apply 許容ケース

### 許容する場面

```
1. グローバルな基本スタイル（@layer base 内）
   → .prose 内の見出し、リスト等
   → フォームのリセットスタイル

2. サードパーティコンポーネントの上書き
   → CMS からの HTML 出力のスタイリング
   → マークダウンレンダリング結果

3. フレームワーク非依存のスタイルが必要な場面
   → メール HTML テンプレート
   → 静的 HTML 生成
```

### 具体例

```css
/* ✅ 許容: prose 内のリッチテキスト */
@layer base {
  .prose h2 {
    @apply text-xl font-semibold mt-8 mb-4;
  }
  .prose p {
    @apply leading-relaxed mb-4;
  }
  .prose a {
    @apply text-primary underline underline-offset-2 hover:text-primary-hover;
  }
  .prose code {
    @apply bg-surface-sunken px-1.5 py-0.5 rounded text-sm font-mono;
  }
}

/* ✅ 許容: CMS コンテンツの上書き */
@layer components {
  .cms-content img {
    @apply rounded-lg max-w-full h-auto;
  }
  .cms-content blockquote {
    @apply border-l-4 border-primary pl-4 italic;
  }
}
```

### 禁止する場面

```
❌ コンポーネントの作成
  .btn { @apply px-4 py-2 bg-primary ... }
  → フレームワークコンポーネント + cva を使う

❌ ユーティリティの組み合わせ
  .flex-center { @apply flex items-center justify-center }
  → そのままユーティリティクラスを使う

❌ レスポンシブバリエーション
  .responsive-grid { @apply grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 }
  → レイアウトコンポーネントを使う
```
