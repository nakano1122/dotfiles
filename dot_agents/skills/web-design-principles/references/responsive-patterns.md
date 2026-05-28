# レスポンシブパターン

## Mobile-First アプローチ

```css
/* モバイルをベース */
.container {
  width: 100%;
  padding: 1rem;
}

/* タブレット以上 */
@media (min-width: 768px) {
  .container {
    padding: 1.5rem;
  }
}

/* デスクトップ以上 */
@media (min-width: 1280px) {
  .container {
    max-width: 80rem;
    margin: 0 auto;
  }
}
```

## ブレークポイント

| 名前 | 幅 | 用途 |
|------|---|------|
| sm | 640px | 大きめのモバイル |
| md | 768px | タブレット |
| lg | 1024px | 小さめのデスクトップ |
| xl | 1280px | デスクトップ |
| 2xl | 1536px | 大型ディスプレイ |

## グリッドの切り替え

```css
.grid {
  display: grid;
  gap: 1rem;
  grid-template-columns: 1fr;  /* モバイル: 1列 */
}

@media (min-width: 768px) {
  .grid {
    grid-template-columns: repeat(2, 1fr);  /* タブレット: 2列 */
  }
}

@media (min-width: 1280px) {
  .grid {
    grid-template-columns: repeat(3, 1fr);  /* デスクトップ: 3列 */
  }
}
```

## Container Queries（モダン CSS）

```css
/* 親コンテナを定義 */
.card-container {
  container-type: inline-size;
}

/* コンテナ幅に応じてスタイル変更 */
@container (min-width: 400px) {
  .card {
    display: grid;
    grid-template-columns: 1fr 2fr;
  }
}
```

## Fluid Typography

```css
/* clamp() で可変フォントサイズ */
.title {
  font-size: clamp(1.5rem, 2vw + 1rem, 3rem);
}
```
