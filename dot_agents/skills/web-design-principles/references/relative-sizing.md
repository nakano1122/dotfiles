# 相対サイズ単位ガイド

## 単位の選択基準

| 用途 | 推奨単位 | 理由 |
|------|---------|------|
| フォントサイズ | rem | ルートからの相対、ユーザー設定尊重 |
| 幅 | % | 親要素からの相対 |
| 最大幅 | rem | 読みやすさの制限 |
| padding/margin | rem | 一貫したスペーシング |
| gap | rem | 一貫したスペーシング |
| ボーダー | px | 1px の視覚的な一貫性 |
| アイコン | rem または px | 文脈による |

## rem の使い方

```css
/* ルートフォントサイズ（デフォルト: 16px） */
:root {
  font-size: 16px; /* または 100% */
}

/* rem での指定 */
.text-sm { font-size: 0.875rem; }  /* 14px */
.text-base { font-size: 1rem; }    /* 16px */
.text-lg { font-size: 1.125rem; }  /* 18px */
.text-xl { font-size: 1.25rem; }   /* 20px */

.spacing-sm { padding: 0.5rem; }   /* 8px */
.spacing-md { padding: 1rem; }     /* 16px */
.spacing-lg { padding: 1.5rem; }   /* 24px */
```

## % の使い方

```css
/* 親幅に対する割合 */
.container {
  width: 100%;
  max-width: 80rem;  /* 最大幅は rem で制限 */
}

.half-width {
  width: 50%;
}

.sidebar {
  width: 25%;
  min-width: 200px;  /* 最小幅は固定 */
}
```

## px を使う場面

```css
/* ボーダー */
.card {
  border: 1px solid var(--color-border);
}

/* アイコン（固定サイズ） */
.icon {
  width: 24px;
  height: 24px;
}

/* メディアクエリのブレークポイント */
@media (min-width: 768px) { }
```

## アンチパターン

```css
/* NG: フォントサイズを px で指定 */
.text {
  font-size: 16px;  /* ユーザー設定を無視 */
}

/* OK */
.text {
  font-size: 1rem;
}

/* NG: 幅を固定値で指定 */
.container {
  width: 1200px;  /* レスポンシブでない */
}

/* OK */
.container {
  width: 100%;
  max-width: 75rem;
}
```
