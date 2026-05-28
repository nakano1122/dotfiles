---
name: figma-to-code
description: |
  Figma MCP を使ってデザインを FE コードに変換するスキル。
  Trigger when: Figma URL が共有された時、デザインからコンポーネント実装時、
  UI 実装でデザイン参照が必要な時、"Figma", "デザイン", "UI実装" への言及時、
  「このデザインを実装して」「Figma から」「デザイン通りに」と言われた時。
  Always use with: /web-design-principles
---

# figma-to-code

Figma MCP を使ってデザインを FE コードに変換するスキル。

**重要:** このスキルは `/web-design-principles` スキルと併用してください。

## 前提条件

- Figma MCP サーバーが設定されていること
- Figma API トークンが設定されていること

## ワークフロー

### 1. デザイン情報の取得

```
1. get_metadata でファイル構造・レイアウト情報を取得
2. get_design_context でデザインノードのコンテキスト取得
3. get_screenshot でビジュアル確認
4. get_code_connect_map で Code Connect マッピング確認
```

### 2. コード生成

```
1. /web-design-principles スキルの原則に従う
2. 親→子の順に実装
3. 相対サイズ・相対位置を使用
4. デザイントークン（CSS Custom Properties）で管理
5. 既存コンポーネントを再利用
```

### 3. 検証

```
1. レスポンシブ動作確認
2. アクセシビリティ確認
3. 既存デザインシステムとの整合性確認
```

## MCP ツール活用

| ツール | 用途 |
|-------|------|
| `get_design_context` | デザインノードの詳細情報取得 |
| `get_screenshot` | ノード/ページのスクリーンショット |
| `get_metadata` | ファイル構造・レイアウト情報 |
| `get_variable_defs` | デザイントークン定義取得 |
| `get_code_connect_map` | Code Connect マッピング確認 |
| `search_design_system` | デザインシステム検索 |

## Figma デザインの読み取り方

### Auto Layout → CSS 変換

| Figma | CSS |
|-------|-----|
| Direction: Vertical | flex-direction: column |
| Direction: Horizontal | flex-direction: row |
| Gap: 16 | gap: 1rem |
| Padding: 24 | padding: 1.5rem |
| FILL | flex: 1 |
| HUG | width: fit-content |

### Figma Variables → CSS Custom Properties

```css
/* Figma Variables */
--color-primary-500: #0284C7;
--spacing-md: 16px;

/* 使用例 */
.button {
  background-color: var(--color-primary-500);
  padding: var(--spacing-md);
}
```

## 詳細リファレンス

- [ワークフロー詳細](references/workflow.md)
- [コンポーネント変換パターン](references/component-patterns.md)
- [デザイントークン抽出](references/design-tokens.md)
