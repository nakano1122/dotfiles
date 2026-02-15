# Feature-Based Architecture 詳細

## 目次

1. [ディレクトリ構成の詳細](#ディレクトリ構成の詳細)
2. [Feature 間依存ルール](#feature-間依存ルール)
3. [共有スキーマの使用範囲](#共有スキーマの使用範囲)
4. [型管理](#型管理)
5. [コーディング規約](#コーディング規約)
6. [レビューチェックリスト](#レビューチェックリスト)

---

## ディレクトリ構成の詳細

```
src/
├── app/                 # App Router（ルーティングのみ）
│   ├── layout.tsx       # ルートレイアウト
│   ├── page.tsx         # トップページ
│   ├── items/
│   │   ├── page.tsx     # 一覧ページ
│   │   └── [id]/
│   │       └── page.tsx # 詳細ページ
│   └── api/
│       └── route.ts     # Route Handler
├── components/          # 共有コンポーネント
│   ├── ui/              # 汎用 UI コンポーネント (Button, Input 等)
│   ├── layout/          # レイアウト系 (Header, Footer, Sidebar)
│   └── feedback/        # フィードバック系 (Toast, Modal, Alert)
├── features/            # 機能別モジュール
│   └── item/
│       ├── components/  # Feature 固有コンポーネント
│       │   ├── ItemList.tsx
│       │   └── ItemCard.tsx
│       ├── hooks/       # カスタムフック
│       │   └── useItemFilter.ts
│       ├── services/    # API 呼び出し
│       │   ├── itemApi.ts
│       │   └── itemActions.ts  # Server Actions
│       ├── types/       # フロントエンド独自型
│       │   └── index.ts
│       └── mappers/     # 型変換
│           └── itemMapper.ts
├── lib/                 # 共有ユーティリティ
│   ├── utils.ts         # cn() 等の汎用関数
│   └── api.ts           # API クライアント基盤
├── config/              # 設定
└── styles/              # グローバルスタイル、CSS 変数
```

### app/ ディレクトリの原則

- **ルーティングのみ**に使用。ビジネスロジックを含めない
- page.tsx は Server Component として、features/ の Services → Mappers を呼び出し、Components に渡す
- レイアウト分割が必要な場合は Route Group `(group)` を活用

## Feature 間依存ルール

**Feature 間の直接インポートは禁止**。

```typescript
// ❌ Feature 間依存
import { UserAvatar } from "@/features/user/components/UserAvatar";
// → features/item/components/ItemCard.tsx から

// ✅ 共有コンポーネントに移動して使用
import { UserAvatar } from "@/components/ui/UserAvatar";
```

### 依存発生時の対処フロー

```
Feature A が Feature B のコードを使いたい
  → そのコードは汎用的か？
    Yes → components/ または lib/ に移動
    No  → 2つの Feature は本当に別か？
      Yes → 共通インターフェースを lib/ に定義
      No  → 1つの Feature に統合
```

## 共有スキーマの使用範囲

モノレポで共有スキーマパッケージ（例: `@project/schemas`）を使用する場合、フロントエンドでの使用を Services 層と Mappers 層に限定する。

### なぜ制限するか

- Components/Hooks が API スキーマに直接依存すると、API 変更時の影響範囲が広がる
- Mappers が変換の責務を集中させることで、変更箇所を局所化できる

### 使用例

```typescript
// ✅ Services: API レスポンス型として使用
// features/item/services/itemApi.ts
import type { GetItemsResponse } from "@project/schemas";

export async function fetchItems(): Promise<GetItemsResponse> {
  const res = await fetch("/api/items");
  return res.json();
}

// ✅ Mappers: 型変換で使用
// features/item/mappers/itemMapper.ts
import type { GetItemsResponse } from "@project/schemas";
import type { Item } from "@/features/item/types";

export function toItems(response: GetItemsResponse): Item[] {
  return response.items.map((item) => ({
    id: item.id,
    title: item.title,
    createdAt: new Date(item.created_at),
  }));
}

// ❌ Component で直接使用
import type { GetItemsResponse } from "@project/schemas"; // NG
```

## 型管理

### フロントエンド独自型

- `features/[feature]/types/` に定義
- ビジネス意味を持つプロパティ名を使用
- API スキーマの型をそのまま使わず、Mappers で変換

```typescript
// features/item/types/index.ts
export type Item = {
  id: string;
  title: string;
  createdAt: Date;       // API は created_at (string) → Date に変換
  isPublished: boolean;  // API は status: "published" | "draft" → boolean に変換
};
```

## コーディング規約

### 命名規則

| 対象 | 規則 | 例 |
|------|------|-----|
| ファイル名（コンポーネント） | PascalCase | `ItemCard.tsx` |
| ファイル名（hooks） | camelCase（use prefix） | `useItemFilter.ts` |
| ファイル名（その他） | camelCase | `itemApi.ts` |
| コンポーネント名 | PascalCase | `ItemCard` |
| 関数名 | camelCase | `fetchItems` |
| 型名 | PascalCase | `ItemListProps` |
| 定数 | UPPER_SNAKE_CASE | `API_BASE_URL` |

### インポート規約

**パスエイリアス必須、相対パス禁止**:

```typescript
// ✅ パスエイリアス
import { Button } from "@/components/ui/button";

// ❌ 相対パス
import { Button } from "../../../components/ui/button";
```

**バレルファイル（index.ts）経由のインポート禁止**:

```typescript
// ✅ 直接インポート
import { ItemCard } from "@/features/item/components/ItemCard";

// ❌ バレルファイル経由
import { ItemCard } from "@/features/item";
```

**インポート順序**: 外部ライブラリ → 外部パッケージ → 内部モジュール → 型

### スタイリング

- `style` 属性（インラインスタイル）は使用禁止
- Tailwind CSS を `className` に記述
- クラス結合には `cn()` ユーティリティを使用
- CSS 変数は `styles/variables.css` で定義

## レビューチェックリスト

### アーキテクチャ
- [ ] Feature 間の依存がない
- [ ] 共通コンポーネントは `components/` に配置
- [ ] app/ にビジネスロジックが含まれていない

### データフェッチ
- [ ] Server Component で Services → Mappers を呼び出している
- [ ] Client Component で直接 fetch していない（例外パターン除く）
- [ ] `useEffect` でのデータ取得がない（例外パターン除く）

### スキーマ使用範囲
- [ ] Component と Hooks で共有スキーマを使用していない
- [ ] Services と Mappers のみでスキーマ型を使用

### コンポーネント
- [ ] 1ファイルに複数コンポーネントを定義していない
- [ ] `useState` / `useEffect` がカスタムフックに分離されている
- [ ] インラインスタイル（style 属性）がない
- [ ] Props Drilling がない

### インポート
- [ ] パスエイリアス（`@/`）を使った絶対パスを使用
- [ ] バレルファイル（index.ts）経由のインポートがない
