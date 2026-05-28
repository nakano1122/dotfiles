# コンポーネント変換パターン

## 基本パターン

### Button

**Figma:**
```
Frame: Button
├── Auto Layout: Horizontal
├── Padding: 12, 24
├── Corner Radius: 8
├── Fill: Primary/500
└── Text: "Click me"
```

**React + CSS:**
```tsx
function Button({ children, variant = 'primary' }) {
  return (
    <button className={`btn btn-${variant}`}>
      {children}
    </button>
  );
}
```

```css
.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 0.75rem 1.5rem;
  border-radius: 0.5rem;
  font-weight: 500;
}

.btn-primary {
  background-color: var(--color-primary-500);
  color: white;
}
```

### Card

**Figma:**
```
Frame: Card
├── Auto Layout: Vertical
├── Gap: 16
├── Padding: 24
├── Corner Radius: 12
├── Fill: Surface
├── Effect: Shadow
└── Children:
    ├── Image
    ├── Title
    └── Description
```

**React + CSS:**
```tsx
function Card({ image, title, description }) {
  return (
    <div className="card">
      {image && <img src={image} alt="" className="card-image" />}
      <h3 className="card-title">{title}</h3>
      <p className="card-description">{description}</p>
    </div>
  );
}
```

```css
.card {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  padding: 1.5rem;
  border-radius: 0.75rem;
  background-color: var(--color-surface);
  box-shadow: var(--shadow-md);
}
```

## レイアウトパターン

### Header

**Figma:**
```
Frame: Header
├── Auto Layout: Horizontal
├── Justify: Space Between
├── Align: Center
├── Padding: 16, 24
└── Children:
    ├── Logo
    ├── Navigation
    └── UserMenu
```

**React:**
```tsx
function Header() {
  return (
    <header className="header">
      <Logo />
      <Navigation />
      <UserMenu />
    </header>
  );
}
```

```css
.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 1.5rem;
}
```

### Grid Layout

**Figma:**
```
Frame: Grid
├── Auto Layout: Wrap (3 columns)
├── Gap: 24
└── Children: Card × N
```

**CSS:**
```css
.grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1.5rem;
}

@media (max-width: 1024px) {
  .grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

@media (max-width: 640px) {
  .grid {
    grid-template-columns: 1fr;
  }
}
```

## フォームパターン

### Input Field

**Figma:**
```
Frame: Input
├── Auto Layout: Vertical
├── Gap: 4
└── Children:
    ├── Label
    └── Input Box
        ├── Border: 1px solid Border
        ├── Padding: 12, 16
        └── Corner Radius: 8
```

**React:**
```tsx
function Input({ label, id, ...props }) {
  return (
    <div className="input-field">
      <label htmlFor={id} className="input-label">{label}</label>
      <input id={id} className="input" {...props} />
    </div>
  );
}
```
