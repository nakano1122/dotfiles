---
name: web-design-principles
description: |
  Webデザイン実装の鉄則ガイド。CSS/レイアウト設計の原則を提供。
  Trigger when: UI/UX実装時、CSS設計時、レイアウト実装時、レスポンシブ対応時、
  アクセシビリティ確認時、"レイアウト", "CSS", "スタイル" への言及時。
  /figma-to-code スキルと併用する場合に自動で参照される。
---

# web-design-principles

Webデザイン実装の鉄則ガイド。

## 5つの鉄則

### 1. 親→子の設計原則（最重要）

```
- 親要素が子要素の配置・整列・間隔を管理
- 子要素は親要素の相対位置・相対サイズで設定
- 子要素が親要素の領域をはみ出すことはあり得ない（モーダル等一部例外）
- Flexbox/Grid で親が制御、子は内部コンテンツのみ担当
```

**親の責務:**
- 子の配置・整列・間隔管理（`display`, `gap`, `align-items`, `justify-content`）
- 子のサイズ制約（`max-width`, `flex-basis`）
- レスポンシブ breakpoint 管理

**子の責務:**
- 内部コンテンツのサイズ・レイアウト
- 自身の最小/最大サイズ要件定義

### 2. 相対位置・相対サイズの設計

| 用途 | 単位 | 理由 |
|------|------|------|
| フォント | rem | ルート基準、スケーラブル |
| 幅・高さ | % | 親幅基準、レスポンシブ対応 |
| margin/padding | rem/% | 継承対応、スケーラブル |
| 固定値（px） | 最小限に | ボーダー、アイコンサイズ等のみ |

### 3. 共通化原則

```
- 同じものは共通化すべき
- 1コンポーネント = 1機能（単一責任）
- 合成優先（継承より組み合わせ）
- デザイントークン（CSS Custom Properties）で一元管理
```

### 4. レスポンシブデザイン

```
- Mobile-First アプローチ
- Breakpoint: sm(640px), md(768px), lg(1024px), xl(1280px)
- Container Queries 活用（親コンテナで制御）
```

### 5. アクセシビリティ（WCAG 2.2 準拠）

```
- 色コントラスト: AA 4.5:1以上
- キーボード操作対応
- セマンティックHTML
- 相対フォント（rem）でユーザー設定尊重
```

## クイックリファレンス

### Flexbox 親テンプレート

```css
.parent {
  display: flex;
  flex-direction: column; /* or row */
  gap: 1rem;
  align-items: center;
  justify-content: space-between;
}
```

### Grid 親テンプレート

```css
.parent {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1.5rem;
}
```

### レスポンシブテンプレート

```css
/* Mobile First */
.container { width: 100%; padding: 1rem; }

@media (min-width: 768px) {
  .container { max-width: 48rem; }
}

@media (min-width: 1280px) {
  .container { max-width: 80rem; }
}
```

## 詳細リファレンス

- [親→子レイアウト詳細](references/parent-child-layout.md)
- [相対サイズ単位ガイド](references/relative-sizing.md)
- [コンポーネント共通化](references/component-composition.md)
- [レスポンシブパターン](references/responsive-patterns.md)
- [アクセシビリティチェックリスト](references/accessibility-checklist.md)
