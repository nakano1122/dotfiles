# アクセシビリティチェックリスト

## WCAG 2.2 準拠（AA レベル）

### 1. 知覚可能（Perceivable）

- [ ] **色コントラスト**: テキストと背景のコントラスト比 4.5:1 以上
- [ ] **大型テキスト**: 18px 以上は 3:1 以上でOK
- [ ] **画像の代替テキスト**: `<img alt="説明">` を設定
- [ ] **動画・音声**: キャプション/字幕を提供
- [ ] **色だけに依存しない**: 色以外でも情報を伝える

### 2. 操作可能（Operable）

- [ ] **キーボード操作**: すべての機能がキーボードで操作可能
- [ ] **フォーカス表示**: フォーカス状態が視覚的に明確
- [ ] **フォーカス順序**: 論理的な Tab 順序
- [ ] **スキップリンク**: メインコンテンツへのスキップリンク
- [ ] **十分な時間**: 時間制限のあるコンテンツは調整可能

### 3. 理解可能（Understandable）

- [ ] **言語設定**: `<html lang="ja">`
- [ ] **一貫したナビゲーション**: サイト全体で一貫した配置
- [ ] **エラー識別**: フォームエラーは明確に表示
- [ ] **ラベル**: フォーム要素には必ずラベルを紐付け

### 4. 堅牢（Robust）

- [ ] **セマンティック HTML**: 適切な HTML 要素を使用
- [ ] **ARIA**: 必要に応じて ARIA 属性を追加
- [ ] **有効なマークアップ**: HTML バリデーションエラーなし

## 実装パターン

### フォーカススタイル

```css
:focus-visible {
  outline: 3px solid var(--color-primary);
  outline-offset: 2px;
}
```

### ボタン

```html
<button type="button" aria-label="メニューを開く">
  <svg aria-hidden="true">...</svg>
</button>
```

### フォーム

```html
<label for="email">メールアドレス</label>
<input
  id="email"
  type="email"
  aria-required="true"
  aria-describedby="email-hint"
/>
<p id="email-hint">例: user@example.com</p>
```

### 相対フォント

```css
/* ユーザーのブラウザ設定を尊重 */
html {
  font-size: 100%; /* 16px がデフォルト */
}

body {
  font-size: 1rem;
  line-height: 1.5;
}
```
