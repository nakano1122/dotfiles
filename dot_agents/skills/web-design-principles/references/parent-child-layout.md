# 親→子レイアウト詳細

## 基本原則

**親要素が子要素を制御する。子要素は自身の内部コンテンツのみ担当する。**

## Flexbox パターン

### 水平配置（Row）

```css
.parent {
  display: flex;
  flex-direction: row;
  gap: 1rem;
  align-items: center;      /* 垂直方向の配置 */
  justify-content: flex-start; /* 水平方向の配置 */
}

.child {
  /* サイズは親が制御、子は指定しない */
}
```

### 垂直配置（Column）

```css
.parent {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  align-items: stretch;     /* 幅を親に合わせる */
}
```

### 子のサイズ制御

```css
.parent {
  display: flex;
  gap: 1rem;
}

.child-fixed {
  flex: 0 0 200px;  /* 固定幅 */
}

.child-grow {
  flex: 1;          /* 残りを埋める */
}

.child-auto {
  flex: 0 0 auto;   /* コンテンツに合わせる */
}
```

## Grid パターン

### 等幅グリッド

```css
.parent {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1.5rem;
}
```

### 可変幅グリッド

```css
.parent {
  display: grid;
  grid-template-columns: 200px 1fr 200px; /* サイドバー + メイン + サイドバー */
  gap: 1rem;
}
```

### 自動フィットグリッド

```css
.parent {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 1rem;
}
```

## 禁止パターン

### NG: 子が親をはみ出す

```css
/* NG */
.child {
  width: 120%;        /* 親をはみ出す */
  margin-left: -20px; /* 親をはみ出す */
}
```

### NG: 子が固定サイズで親を無視

```css
/* NG */
.child {
  width: 500px;  /* 親の幅を考慮していない */
}

/* OK */
.child {
  max-width: 500px;
  width: 100%;
}
```

### NG: 子がレイアウトを制御

```css
/* NG */
.child {
  position: absolute;  /* 親のフローから外れる */
  top: 0;
  left: 0;
}

/* 例外: モーダル、ドロップダウン等 */
```

## 例外ケース

### モーダル・オーバーレイ

```css
.modal-overlay {
  position: fixed;
  inset: 0;
  z-index: 50;
}

.modal-content {
  position: relative;
  /* モーダル内は通常のフロー */
}
```

### ツールチップ・ドロップダウン

```css
.dropdown-trigger {
  position: relative;
}

.dropdown-content {
  position: absolute;
  top: 100%;
  left: 0;
}
```
