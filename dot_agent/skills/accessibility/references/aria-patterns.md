# ARIA パターン詳細

## 目次

1. [はじめに](#はじめに)
2. [モーダルダイアログ (Modal Dialog)](#モーダルダイアログ-modal-dialog)
3. [アコーディオン (Accordion)](#アコーディオン-accordion)
4. [タブ (Tabs)](#タブ-tabs)
5. [ドロップダウンメニュー (Dropdown Menu)](#ドロップダウンメニュー-dropdown-menu)
6. [ツールチップ (Tooltip)](#ツールチップ-tooltip)
7. [パンくずリスト (Breadcrumb)](#パンくずリスト-breadcrumb)
8. [ページネーション (Pagination)](#ページネーション-pagination)
9. [アラート (Alert)](#アラート-alert)
10. [プログレスバー (Progress Bar)](#プログレスバー-progress-bar)
11. [スイッチ/トグル (Switch/Toggle)](#スイッチトグル-switchtoggle)
12. [追加パターン](#追加パターン)
    - [コンボボックス (Combobox)](#コンボボックス-combobox)
    - [スライダー (Slider)](#スライダー-slider)
    - [ツリービュー (Tree View)](#ツリービュー-tree-view)

---

## はじめに

このドキュメントは、一般的なUIコンポーネントのARIAパターンを詳細に解説します。各パターンには以下の情報が含まれます:

- **必須のRole/属性:** コンポーネントに必要なARIA role、state、property
- **キーボード操作:** 期待されるキーボードインタラクション
- **フォーカス管理:** フォーカスの初期位置、移動、トラップの処理

これらのパターンは、[WAI-ARIA Authoring Practices Guide (APG)](https://www.w3.org/WAI/ARIA/apg/)に基づいています。

**重要な原則:**
- 標準のHTML要素が存在する場合は、それを使用する(例: `<button>`, `<a>`)
- ARIAは意味を追加するが、動作は実装する必要がある
- キーボード操作とスクリーンリーダーの両方でテストする

---

## モーダルダイアログ (Modal Dialog)

モーダルダイアログは、ユーザーが現在のタスクを中断し、ダイアログ内のコンテンツに集中する必要があるコンポーネントです。

### 必須のRole/属性

```html
<div role="dialog" aria-labelledby="dialog-title" aria-modal="true">
  <h2 id="dialog-title">ダイアログのタイトル</h2>
  <div aria-describedby="dialog-desc">
    <p id="dialog-desc">ダイアログの説明</p>
    <!-- コンテンツ -->
  </div>
  <button type="button">キャンセル</button>
  <button type="button">確認</button>
</div>
```

**必須:**
- `role="dialog"` または `role="alertdialog"`(緊急性の高いメッセージの場合)
- `aria-labelledby`: ダイアログのタイトル要素のIDを参照
- `aria-modal="true"`: モーダルであることを示す
- `aria-describedby`(推奨): ダイアログの説明要素のIDを参照

### キーボード操作

| キー | 動作 |
|------|------|
| `Tab` | ダイアログ内の次のフォーカス可能要素に移動 |
| `Shift + Tab` | ダイアログ内の前のフォーカス可能要素に移動 |
| `Esc` | ダイアログを閉じる(閉じるボタンと同等) |

### フォーカス管理

1. **ダイアログを開く時:**
   - ダイアログを開いたトリガー要素の参照を保存
   - フォーカスをダイアログ内の最初のフォーカス可能要素に移動(通常は閉じるボタンか最初の入力フィールド)
   - 背景コンテンツをinertにするか、フォーカストラップを実装

2. **ダイアログ内:**
   - `Tab`でダイアログ内のみを循環する(フォーカストラップ)
   - 最後の要素から`Tab`すると最初の要素に戻る
   - 最初の要素から`Shift + Tab`すると最後の要素に移動

3. **ダイアログを閉じる時:**
   - フォーカスを開いたトリガー要素に戻す
   - 背景コンテンツのinertを解除

### 実装のポイント

```javascript
// フォーカストラップの例
const dialog = document.querySelector('[role="dialog"]');
const focusableElements = dialog.querySelectorAll(
  'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
);
const firstElement = focusableElements[0];
const lastElement = focusableElements[focusableElements.length - 1];

dialog.addEventListener('keydown', (e) => {
  if (e.key === 'Tab') {
    if (e.shiftKey && document.activeElement === firstElement) {
      e.preventDefault();
      lastElement.focus();
    } else if (!e.shiftKey && document.activeElement === lastElement) {
      e.preventDefault();
      firstElement.focus();
    }
  } else if (e.key === 'Escape') {
    closeDialog();
  }
});
```

- 背景をクリックしてもダイアログが閉じる場合が多いが、誤操作を防ぐため閉じないパターンも検討
- `aria-modal="true"`を使用する場合でも、フォーカストラップを実装することを推奨
- 背景に`inert`属性を追加することで、スクリーンリーダーがダイアログ外のコンテンツを読み上げないようにする

---

## アコーディオン (Accordion)

アコーディオンは、縦に積み重ねられたヘッダーのリストで、各ヘッダーをクリックすると関連するコンテンツパネルが表示/非表示になります。

### 必須のRole/属性

```html
<div class="accordion">
  <h3>
    <button
      type="button"
      aria-expanded="false"
      aria-controls="panel1"
      id="accordion1"
    >
      アコーディオンのタイトル1
    </button>
  </h3>
  <div id="panel1" role="region" aria-labelledby="accordion1" hidden>
    <p>アコーディオンのコンテンツ1</p>
  </div>

  <h3>
    <button
      type="button"
      aria-expanded="true"
      aria-controls="panel2"
      id="accordion2"
    >
      アコーディオンのタイトル2
    </button>
  </h3>
  <div id="panel2" role="region" aria-labelledby="accordion2">
    <p>アコーディオンのコンテンツ2</p>
  </div>
</div>
```

**必須:**
- ボタン要素に`aria-expanded="true/false"`: パネルの開閉状態を示す
- ボタン要素に`aria-controls`: 制御するパネルのIDを参照
- パネル要素に`role="region"`: コンテンツ領域であることを示す
- パネル要素に`aria-labelledby`: ボタンのIDを参照してラベル付け
- パネル要素に`hidden`属性(閉じている場合)

### キーボード操作

| キー | 動作 |
|------|------|
| `Enter` / `Space` | フォーカスされているヘッダーのパネルを開閉 |
| `Tab` | 次のフォーカス可能要素(次のヘッダーまたはパネル内の要素)に移動 |
| `Shift + Tab` | 前のフォーカス可能要素に移動 |
| `↓` (オプション) | 次のアコーディオンヘッダーに移動 |
| `↑` (オプション) | 前のアコーディオンヘッダーに移動 |
| `Home` (オプション) | 最初のアコーディオンヘッダーに移動 |
| `End` (オプション) | 最後のアコーディオンヘッダーに移動 |

**注意:** 矢印キーのナビゲーションはオプションです。実装する場合、ユーザーがボタン間を素早く移動できる利点がありますが、標準的なTabナビゲーションも必ず動作するようにしてください。

### フォーカス管理

1. **パネルを開く時:**
   - フォーカスはボタンに留まる(パネルには移動しない)
   - `aria-expanded`を`true`に変更
   - パネルの`hidden`属性を削除

2. **パネルを閉じる時:**
   - フォーカスはボタンに留まる
   - `aria-expanded`を`false`に変更
   - パネルに`hidden`属性を追加

3. **複数パネルの動作:**
   - 同時に複数のパネルを開けるか、1つだけかを決定
   - 1つだけの場合、新しいパネルを開く時に他のパネルを閉じる

### 実装のポイント

```javascript
const accordionButtons = document.querySelectorAll('[aria-expanded]');

accordionButtons.forEach(button => {
  button.addEventListener('click', () => {
    const expanded = button.getAttribute('aria-expanded') === 'true';
    const panelId = button.getAttribute('aria-controls');
    const panel = document.getElementById(panelId);

    // トグル
    button.setAttribute('aria-expanded', !expanded);
    panel.hidden = expanded;

    // 1つだけ開く場合: 他のパネルを閉じる
    // accordionButtons.forEach(otherButton => {
    //   if (otherButton !== button) {
    //     otherButton.setAttribute('aria-expanded', 'false');
    //     const otherPanel = document.getElementById(otherButton.getAttribute('aria-controls'));
    //     otherPanel.hidden = true;
    //   }
    // });
  });
});
```

- アニメーションを使用する場合、`hidden`の代わりにCSSでアニメーション後に`display: none`を適用
- `role="region"`は、パネルのコンテンツが十分に長い場合に使用(短い場合は省略可能)

---

## タブ (Tabs)

タブは、複数のパネルを切り替えて表示するコンポーネントです。一度に1つのパネルのみが表示されます。

### 必須のRole/属性

```html
<div class="tabs">
  <div role="tablist" aria-label="サンプルタブ">
    <button
      role="tab"
      aria-selected="true"
      aria-controls="panel1"
      id="tab1"
      tabindex="0"
    >
      タブ1
    </button>
    <button
      role="tab"
      aria-selected="false"
      aria-controls="panel2"
      id="tab2"
      tabindex="-1"
    >
      タブ2
    </button>
    <button
      role="tab"
      aria-selected="false"
      aria-controls="panel3"
      id="tab3"
      tabindex="-1"
    >
      タブ3
    </button>
  </div>

  <div role="tabpanel" id="panel1" aria-labelledby="tab1" tabindex="0">
    <p>タブ1のコンテンツ</p>
  </div>
  <div role="tabpanel" id="panel2" aria-labelledby="tab2" tabindex="0" hidden>
    <p>タブ2のコンテンツ</p>
  </div>
  <div role="tabpanel" id="panel3" aria-labelledby="tab3" tabindex="0" hidden>
    <p>タブ3のコンテンツ</p>
  </div>
</div>
```

**必須:**
- タブのコンテナに`role="tablist"`
- `role="tablist"`に`aria-label`または`aria-labelledby`(タブリストにラベルを付ける)
- 各タブボタンに`role="tab"`
- 各タブに`aria-selected="true/false"`: 選択状態を示す
- 各タブに`aria-controls`: 対応するパネルのIDを参照
- 選択されているタブに`tabindex="0"`、他のタブに`tabindex="-1"`
- 各パネルに`role="tabpanel"`
- 各パネルに`aria-labelledby`: 対応するタブのIDを参照
- パネルに`tabindex="0"`(パネル内にフォーカス可能な要素がない場合)
- 非表示のパネルに`hidden`属性

### キーボード操作

| キー | 動作 |
|------|------|
| `Tab` | タブリストにフォーカスが入る(最初またはアクティブなタブ)、またはタブリストからパネルに移動 |
| `→` | 次のタブに移動(最後のタブから最初のタブに循環) |
| `←` | 前のタブに移動(最初のタブから最後のタブに循環) |
| `Home` | 最初のタブに移動 |
| `End` | 最後のタブに移動 |
| `Space` / `Enter` | フォーカスされているタブをアクティブ化(自動アクティブ化でない場合) |

**自動アクティブ化 vs 手動アクティブ化:**
- **自動:** 矢印キーでタブを移動すると同時にパネルが切り替わる
- **手動:** 矢印キーでタブを移動し、`Enter`/`Space`でアクティブ化する

自動アクティブ化はシンプルですが、パネルの読み込みが重い場合は手動アクティブ化を検討してください。

### フォーカス管理

1. **タブリストに入る時:**
   - フォーカスは現在選択されているタブ(`aria-selected="true"`)に移動
   - 選択されているタブのみ`tabindex="0"`で、他は`tabindex="-1"`

2. **タブを切り替える時:**
   - 前のタブの`aria-selected`を`false`に、`tabindex`を`-1`に変更
   - 新しいタブの`aria-selected`を`true`に、`tabindex`を`0`に変更
   - フォーカスを新しいタブに移動
   - 対応するパネルを表示し、他のパネルを非表示にする

3. **パネルにフォーカスする時:**
   - `Tab`キーでタブリストからパネルに移動
   - パネル内の最初のフォーカス可能要素にフォーカス(なければパネル自体)

### 実装のポイント

```javascript
const tablist = document.querySelector('[role="tablist"]');
const tabs = tablist.querySelectorAll('[role="tab"]');
const panels = document.querySelectorAll('[role="tabpanel"]');

tabs.forEach((tab, index) => {
  tab.addEventListener('click', () => activateTab(tab));

  tab.addEventListener('keydown', (e) => {
    let newIndex;
    if (e.key === 'ArrowRight') {
      newIndex = (index + 1) % tabs.length;
    } else if (e.key === 'ArrowLeft') {
      newIndex = (index - 1 + tabs.length) % tabs.length;
    } else if (e.key === 'Home') {
      newIndex = 0;
    } else if (e.key === 'End') {
      newIndex = tabs.length - 1;
    }

    if (newIndex !== undefined) {
      e.preventDefault();
      tabs[newIndex].focus();
      // 自動アクティブ化の場合
      activateTab(tabs[newIndex]);
    }
  });
});

function activateTab(newTab) {
  tabs.forEach(tab => {
    tab.setAttribute('aria-selected', 'false');
    tab.setAttribute('tabindex', '-1');
  });

  panels.forEach(panel => {
    panel.hidden = true;
  });

  newTab.setAttribute('aria-selected', 'true');
  newTab.setAttribute('tabindex', '0');

  const panelId = newTab.getAttribute('aria-controls');
  document.getElementById(panelId).hidden = false;
}
```

- タブが削除可能な場合、削除ボタンを各タブに追加し、削除後のフォーカス管理を実装
- タブが多い場合、スクロール可能なタブリストを検討

---

## ドロップダウンメニュー (Dropdown Menu)

ドロップダウンメニューは、ボタンやリンクをクリックすると表示されるメニューで、複数の選択肢やアクションを提供します。

### 必須のRole/属性

```html
<div class="dropdown">
  <button
    type="button"
    aria-haspopup="true"
    aria-expanded="false"
    aria-controls="menu1"
    id="menubutton1"
  >
    メニュー
  </button>

  <ul role="menu" id="menu1" aria-labelledby="menubutton1" hidden>
    <li role="none">
      <a role="menuitem" href="#action1">アクション1</a>
    </li>
    <li role="none">
      <a role="menuitem" href="#action2">アクション2</a>
    </li>
    <li role="separator"></li>
    <li role="none">
      <button role="menuitem">アクション3</button>
    </li>
  </ul>
</div>
```

**必須:**
- トリガーボタンに`aria-haspopup="true"`(または`"menu"`)
- トリガーボタンに`aria-expanded="true/false"`: メニューの開閉状態を示す
- トリガーボタンに`aria-controls`: メニューのIDを参照
- メニューコンテナに`role="menu"`
- メニューに`aria-labelledby`: トリガーボタンのIDを参照
- 各メニューアイテムに`role="menuitem"`, `role="menuitemcheckbox"`, `role="menuitemradio"`
- リストアイテム(`<li>`)に`role="none"`または`role="presentation"`(リストのセマンティクスを削除)
- 区切り線に`role="separator"`
- 非表示のメニューに`hidden`属性

### キーボード操作

| キー | 動作 |
|------|------|
| `Enter` / `Space` (ボタン上) | メニューを開く/閉じる |
| `↓` (ボタン上) | メニューを開き、最初のアイテムにフォーカス |
| `↑` (ボタン上) | メニューを開き、最後のアイテムにフォーカス |
| `↓` (メニュー内) | 次のメニューアイテムに移動(最後から最初に循環) |
| `↑` (メニュー内) | 前のメニューアイテムに移動(最初から最後に循環) |
| `Home` (メニュー内) | 最初のメニューアイテムに移動 |
| `End` (メニュー内) | 最後のメニューアイテムに移動 |
| `Enter` (メニュー内) | メニューアイテムを選択し、メニューを閉じる |
| `Esc` (メニュー内) | メニューを閉じ、トリガーボタンにフォーカスを戻す |
| `Tab` (メニュー内) | メニューを閉じ、次のフォーカス可能要素に移動 |
| `Shift + Tab` (メニュー内) | メニューを閉じ、前のフォーカス可能要素に移動 |
| 文字キー (メニュー内) | その文字で始まる次のメニューアイテムに移動(type-ahead) |

### フォーカス管理

1. **メニューを開く時:**
   - トリガーボタンの`aria-expanded`を`true`に変更
   - メニューの`hidden`属性を削除
   - フォーカスをメニューの最初のアイテムに移動(または矢印キーに応じて)

2. **メニュー内:**
   - 矢印キーでアイテム間を移動
   - `Tab`キーはメニューを閉じる(メニュー内で循環しない)

3. **メニューを閉じる時:**
   - トリガーボタンの`aria-expanded`を`false`に変更
   - メニューに`hidden`属性を追加
   - フォーカスをトリガーボタンに戻す

4. **メニュー外をクリック:**
   - メニューを閉じ、フォーカスをトリガーボタンに戻す

### 実装のポイント

```javascript
const menuButton = document.getElementById('menubutton1');
const menu = document.getElementById('menu1');
const menuItems = menu.querySelectorAll('[role="menuitem"]');

menuButton.addEventListener('click', () => {
  const isOpen = menuButton.getAttribute('aria-expanded') === 'true';
  toggleMenu(!isOpen);
});

menuButton.addEventListener('keydown', (e) => {
  if (e.key === 'ArrowDown') {
    e.preventDefault();
    openMenu();
    menuItems[0].focus();
  } else if (e.key === 'ArrowUp') {
    e.preventDefault();
    openMenu();
    menuItems[menuItems.length - 1].focus();
  }
});

menu.addEventListener('keydown', (e) => {
  const currentIndex = Array.from(menuItems).indexOf(document.activeElement);

  if (e.key === 'ArrowDown') {
    e.preventDefault();
    const nextIndex = (currentIndex + 1) % menuItems.length;
    menuItems[nextIndex].focus();
  } else if (e.key === 'ArrowUp') {
    e.preventDefault();
    const prevIndex = (currentIndex - 1 + menuItems.length) % menuItems.length;
    menuItems[prevIndex].focus();
  } else if (e.key === 'Escape') {
    e.preventDefault();
    closeMenu();
    menuButton.focus();
  } else if (e.key === 'Tab') {
    closeMenu();
  }
});

menuItems.forEach(item => {
  item.addEventListener('click', () => {
    closeMenu();
    menuButton.focus();
  });
});

function toggleMenu(open) {
  menuButton.setAttribute('aria-expanded', open);
  menu.hidden = !open;
}

function openMenu() {
  toggleMenu(true);
}

function closeMenu() {
  toggleMenu(false);
}

// メニュー外をクリックしたら閉じる
document.addEventListener('click', (e) => {
  if (!menu.contains(e.target) && e.target !== menuButton) {
    closeMenu();
  }
});
```

- チェックボックス/ラジオボタンのメニューアイテムには、`aria-checked="true/false"`を使用
- サブメニューがある場合、`aria-haspopup="true"`を親アイテムに追加し、右矢印キーでサブメニューを開く

---

## ツールチップ (Tooltip)

ツールチップは、要素にホバーまたはフォーカスしたときに表示される補足情報です。

### 必須のRole/属性

```html
<button type="button" aria-describedby="tooltip1">
  ヘルプ
</button>

<div role="tooltip" id="tooltip1" hidden>
  これはツールチップの説明文です。
</div>
```

**必須:**
- ツールチップコンテナに`role="tooltip"`
- トリガー要素に`aria-describedby`: ツールチップのIDを参照
- 非表示のツールチップに`hidden`属性

**`aria-describedby` vs `aria-labelledby`:**
- `aria-describedby`: 補足説明(ツールチップの一般的な用途)
- `aria-labelledby`: ラベル(要素のメインラベルを提供)

### キーボード操作

| キー | 動作 |
|------|------|
| `Esc` | ツールチップを閉じる |

**注意:**
- ツールチップは通常、ホバー/フォーカスで自動的に表示され、ホバー/フォーカスが外れると非表示になります
- キーボードユーザーのために、フォーカス時にも表示される必要があります
- ツールチップ自体はフォーカスを受け取らない(インタラクティブな要素を含む場合は、ツールチップではなくポップオーバーを検討)

### フォーカス管理

1. **ツールチップを表示:**
   - トリガー要素にホバーまたはフォーカスしたときに表示
   - フォーカスはトリガー要素に留まる

2. **ツールチップを非表示:**
   - ホバー/フォーカスが外れたとき、または`Esc`キーで非表示
   - フォーカスはトリガー要素に留まる

### 実装のポイント

```javascript
const trigger = document.querySelector('[aria-describedby="tooltip1"]');
const tooltip = document.getElementById('tooltip1');

function showTooltip() {
  tooltip.hidden = false;
}

function hideTooltip() {
  tooltip.hidden = true;
}

trigger.addEventListener('mouseenter', showTooltip);
trigger.addEventListener('mouseleave', hideTooltip);
trigger.addEventListener('focus', showTooltip);
trigger.addEventListener('blur', hideTooltip);

trigger.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    hideTooltip();
  }
});
```

- ツールチップ内のテキストは簡潔にする(長い説明はポップオーバーやモーダルを使用)
- ツールチップがトリガー要素に重ならないように配置
- ツールチップにインタラクティブな要素(リンク、ボタンなど)がある場合は、`role="tooltip"`ではなくポップオーバーパターンを使用
- ポインターをツールチップ上に移動できる必要がある場合(WCAG 1.4.13)、マウスリーブイベントのタイミングを調整

---

## パンくずリスト (Breadcrumb)

パンくずリストは、現在のページの階層的な位置を示すナビゲーション要素です。

### 必須のRole/属性

```html
<nav aria-label="パンくずリスト">
  <ol>
    <li><a href="/">ホーム</a></li>
    <li><a href="/products">商品</a></li>
    <li><a href="/products/electronics">電子機器</a></li>
    <li aria-current="page">ノートパソコン</li>
  </ol>
</nav>
```

**必須:**
- `<nav>`要素で囲む
- `<nav>`に`aria-label="パンくずリスト"`(または類似のラベル)
- 順序付きリスト(`<ol>`)を使用
- 現在のページに`aria-current="page"`

**代替パターン:**
```html
<nav aria-label="パンくずリスト">
  <ol>
    <li><a href="/">ホーム</a> <span aria-hidden="true">/</span></li>
    <li><a href="/products">商品</a> <span aria-hidden="true">/</span></li>
    <li><a href="/products/electronics">電子機器</a> <span aria-hidden="true">/</span></li>
    <li aria-current="page">ノートパソコン</li>
  </ol>
</nav>
```

区切り文字に`aria-hidden="true"`を使用して、スクリーンリーダーが読み上げないようにします。

### キーボード操作

パンくずリストは標準のリンクナビゲーションを使用します:

| キー | 動作 |
|------|------|
| `Tab` | 次のリンクに移動 |
| `Shift + Tab` | 前のリンクに移動 |
| `Enter` | リンクをアクティブ化 |

### フォーカス管理

- 標準のリンクと同じフォーカス動作
- 現在のページ(最後のアイテム)はリンクではないため、フォーカスを受け取らない

### 実装のポイント

- 現在のページはリンクにしない(テキストのみ)
- `aria-current="page"`で現在のページを明示
- 区切り文字は視覚的なもので、スクリーンリーダーには不要(`aria-hidden="true"`)
- モバイルでは、省略表記を検討(例: ホーム > ... > 現在のページ)

---

## ページネーション (Pagination)

ページネーションは、複数のページに分割されたコンテンツをナビゲートするための要素です。

### 必須のRole/属性

```html
<nav aria-label="ページネーション">
  <ul>
    <li>
      <a href="?page=1" aria-label="前のページ">
        <span aria-hidden="true">&laquo;</span>
      </a>
    </li>
    <li><a href="?page=1">1</a></li>
    <li><a href="?page=2">2</a></li>
    <li><a href="?page=3" aria-current="page">3</a></li>
    <li><a href="?page=4">4</a></li>
    <li><a href="?page=5">5</a></li>
    <li>
      <a href="?page=4" aria-label="次のページ">
        <span aria-hidden="true">&raquo;</span>
      </a>
    </li>
  </ul>
</nav>
```

**必須:**
- `<nav>`要素で囲む
- `<nav>`に`aria-label="ページネーション"`(または類似のラベル)
- 現在のページに`aria-current="page"`
- アイコンのみのリンク(前/次)に`aria-label`を付ける
- アイコン自体に`aria-hidden="true"`(視覚的なもの)

### キーボード操作

ページネーションは標準のリンクナビゲーションを使用します:

| キー | 動作 |
|------|------|
| `Tab` | 次のリンクに移動 |
| `Shift + Tab` | 前のリンクに移動 |
| `Enter` | リンクをアクティブ化 |

### フォーカス管理

- 標準のリンクと同じフォーカス動作
- 現在のページはリンクではない場合、フォーカスを受け取らない(または無効化されたリンクとして表示)

### 実装のポイント

**現在のページの処理:**

オプション1: リンクなし
```html
<li><span aria-current="page">3</span></li>
```

オプション2: 無効化されたリンク
```html
<li>
  <a href="?page=3" aria-current="page" aria-disabled="true">3</a>
</li>
```

**省略記号:**
```html
<li><span aria-hidden="true">...</span></li>
```

省略記号はスクリーンリーダーに読み上げられないように`aria-hidden="true"`を使用します。

**前/次のリンクが無効な場合:**
```html
<li>
  <span aria-label="前のページ(利用不可)">
    <span aria-hidden="true">&laquo;</span>
  </span>
</li>
```

または完全に削除します。

---

## アラート (Alert)

アラートは、ユーザーに重要な情報を通知するメッセージです。スクリーンリーダーにリアルタイムで通知されます。

### 必須のRole/属性

```html
<!-- 静的なアラート(ページ読み込み時に存在) -->
<div role="alert">
  <p>フォームの送信に成功しました。</p>
</div>

<!-- 動的なアラート(JavaScriptで挿入) -->
<div id="alert-container"></div>

<script>
  // アラートを表示
  const alertContainer = document.getElementById('alert-container');
  alertContainer.innerHTML = '<div role="alert">エラーが発生しました。</div>';
</script>
```

**必須:**
- `role="alert"`: 緊急性の高いメッセージ(暗黙的に`aria-live="assertive"`, `aria-atomic="true"`)
- または`role="status"`: 緊急性の低いメッセージ(暗黙的に`aria-live="polite"`, `aria-atomic="true"`)

**`role="alert"` vs `role="status"`:**
- `role="alert"`: エラー、警告など、すぐに通知すべきメッセージ
- `role="status"`: 成功メッセージ、情報など、ユーザーの操作を中断しないメッセージ

### キーボード操作

アラート自体にキーボード操作はありません。閉じるボタンがある場合:

| キー | 動作 |
|------|------|
| `Tab` | 閉じるボタンにフォーカス |
| `Enter` / `Space` | アラートを閉じる |

### フォーカス管理

- アラートが表示されてもフォーカスは移動しない(ユーザーの現在の操作を中断しない)
- スクリーンリーダーがアラートの内容を読み上げる
- アラート内にインタラクティブな要素(リンク、ボタンなど)がある場合、ユーザーは手動でフォーカスを移動する必要がある

### 実装のポイント

```javascript
// アラートを表示する関数
function showAlert(message, type = 'alert') {
  const alertContainer = document.getElementById('alert-container');
  const alertDiv = document.createElement('div');
  alertDiv.setAttribute('role', type); // 'alert' または 'status'
  alertDiv.textContent = message;

  alertContainer.appendChild(alertDiv);

  // 一定時間後に自動的に削除(オプション)
  setTimeout(() => {
    alertDiv.remove();
  }, 5000);
}

// 使用例
showAlert('保存しました', 'status');
showAlert('エラーが発生しました', 'alert');
```

**重要な注意点:**
- `role="alert"`を持つ要素がすでにDOMに存在し、その内容を変更する場合、スクリーンリーダーが通知します
- 新しい`role="alert"`要素をDOMに挿入する場合も、スクリーンリーダーが通知します
- 要素が既に存在し、`role="alert"`を後から追加しても通知されない場合があります(ブラウザによる)
- 複数のアラートを連続して表示する場合、それぞれが読み上げられるように短い遅延を入れる

**閉じるボタン付きのアラート:**
```html
<div role="alert">
  <p>これは重要なメッセージです。</p>
  <button type="button" aria-label="アラートを閉じる">
    <span aria-hidden="true">&times;</span>
  </button>
</div>
```

---

## プログレスバー (Progress Bar)

プログレスバーは、タスクの進行状況を視覚的に表示する要素です。

### 必須のRole/属性

**確定的なプログレスバー(進行状況が分かる):**
```html
<div
  role="progressbar"
  aria-valuenow="50"
  aria-valuemin="0"
  aria-valuemax="100"
  aria-label="ファイルのアップロード"
>
  <div class="progress-bar-fill" style="width: 50%;"></div>
</div>
```

**不確定的なプログレスバー(進行状況が不明):**
```html
<div
  role="progressbar"
  aria-label="読み込み中"
  aria-valuetext="読み込み中..."
>
  <div class="spinner"></div>
</div>
```

**必須:**
- `role="progressbar"`
- `aria-label`または`aria-labelledby`: プログレスバーのラベル
- **確定的な場合:**
  - `aria-valuenow`: 現在の値(0〜100など)
  - `aria-valuemin`: 最小値(通常0)
  - `aria-valuemax`: 最大値(通常100)
- **不確定的な場合:**
  - `aria-valuenow`, `aria-valuemin`, `aria-valuemax`は省略
  - `aria-valuetext`(オプション): 状態を説明するテキスト

### キーボード操作

プログレスバーは情報を表示するのみで、キーボード操作はありません。

### フォーカス管理

- プログレスバー自体はフォーカスを受け取らない
- プログレスバーが完了したときにフォーカスを適切な場所に移動する場合がある(例: 「完了」ボタン)

### 実装のポイント

```javascript
const progressBar = document.querySelector('[role="progressbar"]');
const fill = progressBar.querySelector('.progress-bar-fill');

function updateProgress(value) {
  progressBar.setAttribute('aria-valuenow', value);
  fill.style.width = `${value}%`;

  // 完了時
  if (value >= 100) {
    // 完了メッセージを表示
    showAlert('アップロードが完了しました', 'status');
  }
}

// 進行状況を更新
updateProgress(25);
updateProgress(50);
updateProgress(75);
updateProgress(100);
```

**不確定的なプログレスバー(スピナー):**
```javascript
const progressBar = document.querySelector('[role="progressbar"]');

// 読み込み開始
progressBar.setAttribute('aria-valuetext', '読み込み中...');

// 読み込み完了
progressBar.remove(); // または非表示にする
```

**`<progress>`要素の使用:**
HTML5の`<progress>`要素を使用することもできます。この場合、ARIAは自動的に適用されます:
```html
<label for="file-progress">ファイルのアップロード:</label>
<progress id="file-progress" max="100" value="50">50%</progress>
```

---

## スイッチ/トグル (Switch/Toggle)

スイッチは、オン/オフの2つの状態を切り替えるコントロールです。チェックボックスに似ていますが、視覚的にトグルスイッチとして表現されます。

### 必須のRole/属性

```html
<button
  type="button"
  role="switch"
  aria-checked="false"
  aria-labelledby="switch-label"
  id="switch1"
>
  <span class="switch-slider"></span>
</button>
<span id="switch-label">通知を有効にする</span>
```

または:

```html
<label>
  <span class="switch-container">
    <button
      type="button"
      role="switch"
      aria-checked="false"
    >
      <span class="switch-slider"></span>
    </button>
  </span>
  通知を有効にする
</label>
```

**必須:**
- `role="switch"`
- `aria-checked="true/false"`: スイッチの状態を示す(`"mixed"`は使用しない)
- ラベルとの関連付け(`aria-labelledby`, `aria-label`, または`<label>`で囲む)

**`role="switch"` vs チェックボックス:**
- スイッチ: 即座に効果が適用される(例: 設定の有効/無効)
- チェックボックス: フォーム送信時に効果が適用される(例: 利用規約への同意)

### キーボード操作

| キー | 動作 |
|------|------|
| `Space` | スイッチをオン/オフに切り替える |
| `Enter` | スイッチをオン/オフに切り替える(オプション) |

**注意:** `Enter`キーのサポートはオプションですが、ボタン要素を使用する場合は自動的にサポートされます。

### フォーカス管理

- スイッチはフォーカス可能な要素(`<button>`を推奨)
- 標準のフォーカス動作(Tab/Shift+Tab)
- フォーカス時にスイッチがボタンであることとその状態がスクリーンリーダーで読み上げられる

### 実装のポイント

```javascript
const switchButton = document.getElementById('switch1');

switchButton.addEventListener('click', () => {
  const isChecked = switchButton.getAttribute('aria-checked') === 'true';
  switchButton.setAttribute('aria-checked', !isChecked);

  // 状態に応じた処理
  if (!isChecked) {
    console.log('スイッチがオンになりました');
    // 通知を有効にする処理など
  } else {
    console.log('スイッチがオフになりました');
    // 通知を無効にする処理など
  }
});
```

**CSSでの視覚的な表現:**
```css
[role="switch"] {
  position: relative;
  display: inline-block;
  width: 50px;
  height: 24px;
  background-color: #ccc;
  border-radius: 12px;
  transition: background-color 0.3s;
}

[role="switch"][aria-checked="true"] {
  background-color: #4caf50;
}

.switch-slider {
  position: absolute;
  top: 2px;
  left: 2px;
  width: 20px;
  height: 20px;
  background-color: white;
  border-radius: 50%;
  transition: transform 0.3s;
}

[role="switch"][aria-checked="true"] .switch-slider {
  transform: translateX(26px);
}
```

**重要な注意点:**
- スイッチは即座に効果が適用される設定に使用(フォーム送信不要)
- フォーム内で使用する場合、隠しフィールドで値を管理
- 複数のスイッチをグループ化する場合、`<fieldset>`と`<legend>`を使用

---

## 追加パターン

以下は、よく使用される追加のUIパターンです。

### コンボボックス (Combobox)

コンボボックスは、入力フィールドとリストボックスを組み合わせたウィジェットで、入力またはリストから選択できます。

#### 必須のRole/属性

```html
<div class="combobox">
  <label for="combo1">国を選択:</label>
  <input
    type="text"
    id="combo1"
    role="combobox"
    aria-autocomplete="list"
    aria-expanded="false"
    aria-controls="listbox1"
    aria-activedescendant=""
  />
  <ul role="listbox" id="listbox1" hidden>
    <li role="option" id="option1">日本</li>
    <li role="option" id="option2">アメリカ</li>
    <li role="option" id="option3">イギリス</li>
  </ul>
</div>
```

**必須:**
- 入力フィールドに`role="combobox"`
- `aria-autocomplete="list"`, `"inline"`, `"both"`, または`"none"`
- `aria-expanded="true/false"`: リストボックスの開閉状態
- `aria-controls`: リストボックスのIDを参照
- `aria-activedescendant`: 現在フォーカスされているオプションのID
- リストボックスに`role="listbox"`
- 各オプションに`role="option"`

#### キーボード操作

| キー | 動作 |
|------|------|
| `↓` | リストボックスを開き、次のオプションに移動 |
| `↑` | リストボックスを開き、前のオプションに移動 |
| `Enter` | 選択されているオプションを確定し、リストボックスを閉じる |
| `Esc` | リストボックスを閉じる |
| `Home` | 最初のオプションに移動 |
| `End` | 最後のオプションに移動 |

---

### スライダー (Slider)

スライダーは、数値の範囲から値を選択するコントロールです。

#### 必須のRole/属性

```html
<label id="slider-label">音量:</label>
<div
  role="slider"
  tabindex="0"
  aria-labelledby="slider-label"
  aria-valuenow="50"
  aria-valuemin="0"
  aria-valuemax="100"
>
  <div class="slider-thumb" style="left: 50%;"></div>
</div>
```

**必須:**
- `role="slider"`
- `tabindex="0"`: キーボードでフォーカス可能
- `aria-valuenow`: 現在の値
- `aria-valuemin`: 最小値
- `aria-valuemax`: 最大値
- `aria-label`または`aria-labelledby`: ラベル

#### キーボード操作

| キー | 動作 |
|------|------|
| `→` / `↑` | 値を増やす |
| `←` / `↓` | 値を減らす |
| `Home` | 最小値に設定 |
| `End` | 最大値に設定 |
| `PageUp` | 大幅に増やす |
| `PageDown` | 大幅に減らす |

---

### ツリービュー (Tree View)

ツリービューは、階層構造のデータを表示するコンポーネントです。

#### 必須のRole/属性

```html
<ul role="tree" aria-label="ファイルツリー">
  <li role="treeitem" aria-expanded="true">
    <span>フォルダ1</span>
    <ul role="group">
      <li role="treeitem">ファイル1.txt</li>
      <li role="treeitem">ファイル2.txt</li>
    </ul>
  </li>
  <li role="treeitem" aria-expanded="false">
    <span>フォルダ2</span>
    <ul role="group">
      <li role="treeitem">ファイル3.txt</li>
    </ul>
  </li>
</ul>
```

**必須:**
- ツリーのコンテナに`role="tree"`
- 各ノードに`role="treeitem"`
- 子ノードのグループに`role="group"`
- 親ノードに`aria-expanded="true/false"`

#### キーボード操作

| キー | 動作 |
|------|------|
| `↓` | 次のノードに移動 |
| `↑` | 前のノードに移動 |
| `→` | 閉じているノードを開く、または最初の子ノードに移動 |
| `←` | 開いているノードを閉じる、または親ノードに移動 |
| `Enter` / `Space` | ノードを選択 |
| `Home` | 最初のノードに移動 |
| `End` | 最後の表示されているノードに移動 |

---

## まとめ

アクセシブルなUIコンポーネントを構築するためのベストプラクティス:

1. **セマンティックHTMLを優先:** 可能な限り標準のHTML要素を使用
2. **ARIAは最後の手段:** セマンティックHTMLで表現できない場合のみARIAを使用
3. **キーボードサポートは必須:** すべてのインタラクティブ要素がキーボードで操作可能であることを確認
4. **フォーカス管理に注意:** フォーカスが論理的に移動し、ユーザーが迷わないようにする
5. **実際にテストする:** スクリーンリーダー(NVDA, JAWSなど)とキーボードで動作を確認
6. **APGを参照:** [WAI-ARIA Authoring Practices Guide](https://www.w3.org/WAI/ARIA/apg/)で詳細なパターンを確認

これらのパターンは出発点であり、実際のユースケースに応じてカスタマイズが必要です。ユーザーテストとフィードバックを通じて、継続的に改善していきましょう。
