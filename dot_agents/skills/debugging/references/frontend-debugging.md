# フロントエンドデバッグガイド

## 目次

- [ブラウザ開発者ツールの活用](#ブラウザ開発者ツールの活用)
  - [Elements パネル](#elements-パネル)
  - [Console パネル](#console-パネル)
  - [Network パネル](#network-パネル)
  - [Performance パネル](#performance-パネル)
  - [Application パネル](#application-パネル)
- [レンダリングデバッグ詳細](#レンダリングデバッグ詳細)
  - [仮想 DOM 差分の調査](#仮想-dom-差分の調査)
  - [リコンシリエーション問題](#リコンシリエーション問題)
  - [レイアウトスラッシング](#レイアウトスラッシング)
- [状態管理デバッグ詳細](#状態管理デバッグ詳細)
  - [状態の不変性違反](#状態の不変性違反)
  - [クロージャの罠](#クロージャの罠)
  - [非同期状態更新](#非同期状態更新)
- [ネットワークデバッグ詳細](#ネットワークデバッグ詳細)
  - [CORS 問題の切り分け](#cors-問題の切り分け)
  - [認証トークンフロー](#認証トークンフロー)
  - [WebSocket デバッグ](#websocket-デバッグ)
- [CSS デバッグ](#css-デバッグ)
  - [Specificity（詳細度）問題](#specificity詳細度問題)
  - [z-index 管理](#z-index-管理)
  - [レスポンシブデバッグ](#レスポンシブデバッグ)
  - [ダークモードデバッグ](#ダークモードデバッグ)
- [メモリリーク検出](#メモリリーク検出)
  - [検出手順](#検出手順)
  - [イベントリスナー解放忘れ](#イベントリスナー解放忘れ)
  - [タイマー解放忘れ](#タイマー解放忘れ)
  - [DOM 参照によるリーク](#dom-参照によるリーク)
- [パフォーマンスデバッグ](#パフォーマンスデバッグ)
  - [Core Web Vitals の計測と改善](#core-web-vitals-の計測と改善)
  - [不要な再レンダリング検出](#不要な再レンダリング検出)

## ブラウザ開発者ツールの活用

### Elements パネル

- DOM ツリーの構造を確認し、意図しない要素の挿入・消失を検出する
- 要素を右クリック → "Break on..." で DOM 変更時にブレークポイントを設定する
  - **subtree modifications**: 子要素の追加・削除・変更時に停止
  - **attribute modifications**: 属性の変更時に停止
  - **node removal**: 要素自体が削除される時に停止
- Computed タブでスタイルの最終的な計算結果を確認する
- Accessibility タブでアクセシビリティツリーを確認する
- Event Listeners タブで要素にバインドされたイベントリスナーを一覧する

### Console パネル

- `console.table()` でオブジェクト配列を表形式で表示する
- `console.group()` / `console.groupEnd()` でログをグループ化する
- `console.time()` / `console.timeEnd()` で処理時間を計測する
- `console.trace()` でコールスタックを出力する
- `console.assert(condition, message)` で条件が偽の場合のみエラーを出力する
- `$0` で Elements パネルで選択中の要素を参照する
- `$_` で直前の評価結果を参照する
- `copy()` でコンソール上の値をクリップボードにコピーする
- `monitor(fn)` で関数呼び出しを監視する
- `monitorEvents(element, eventType)` でイベント発火を監視する
- Live Expression 機能で式をリアルタイム監視する

### Network パネル

- **Preserve log** を有効にしてページ遷移をまたいだ通信ログを保持する
- **Disable cache** を有効にしてキャッシュの影響を排除する
- **Throttling** でネットワーク速度を制限し、低速環境を再現する
- フィルタ機能で通信種別を絞り込む（XHR, Fetch, WS, Doc, CSS, JS, Img）
- リクエストの Timing タブで各フェーズの時間内訳を確認する
  - DNS Lookup, Initial Connection, SSL, TTFB, Content Download
- **Initiator** カラムでリクエストの発生元のコードを特定する
- **Block request URL** / **Block request domain** で特定リクエストをブロックして影響を確認する
- HAR ファイルとしてエクスポートし、チーム間で通信ログを共有する

### Performance パネル

- **Record** ボタンで操作を記録し、フレームドロップを検出する
- Main スレッドのフレームチャートで長時間タスク（Long Task）を特定する
- ボトルネックの種類を色で判別する
  - 黄色: スクリプト実行
  - 紫色: レイアウト計算
  - 緑色: ペイント処理
- **Screenshots** を有効にして視覚的な変化のタイムラインを確認する
- **Web Vitals** レーンで LCP, FID, CLS の発生タイミングを確認する
- **CPU throttling** で低スペック端末の動作を再現する

### Application パネル

- **Storage** セクションで LocalStorage, SessionStorage, IndexedDB, Cookies の内容を確認・編集する
- **Service Workers** の登録状態・キャッシュ戦略を確認する
- **Cache Storage** でキャッシュされたリソースを確認する
- **Clear storage** で各種ストレージを一括クリアする
- **Manifest** で PWA のマニフェスト設定を検証する

---

## レンダリングデバッグ詳細

### 仮想 DOM 差分の調査

- React DevTools の **Highlight updates** を有効にして、再レンダリングされるコンポーネントを視覚的に確認する
- React DevTools の Profiler タブで各コンポーネントのレンダリング回数と所要時間を記録する
- `React.StrictMode` が意図的に二重レンダリングを引き起こしていることを認識する（開発環境のみ）
- Vue DevTools のタイムラインでリアクティブな変更とレンダリングの関係を追跡する

### リコンシリエーション問題

- **key プロパティの不適切な使用**: リスト要素で配列のインデックスを key に使うと、要素の追加・削除・並べ替え時に意図しない再利用が発生する

```jsx
// 問題: インデックスを key に使用
{items.map((item, index) => <Item key={index} data={item} />)}

// 解決: 一意な識別子を key に使用
{items.map((item) => <Item key={item.id} data={item} />)}
```

- **条件付きレンダリングの位置ずれ**: 条件分岐で要素の出現位置が変わると、React がコンポーネントツリーの対応を誤認する

```jsx
// 問題: 条件によってコンポーネントの位置が変わる
{isAdmin && <AdminPanel />}
<UserPanel />

// 解決: key を付けて明示的に区別するか、位置を固定する
{isAdmin ? <AdminPanel key="admin" /> : null}
<UserPanel key="user" />
```

### レイアウトスラッシング

- レイアウト情報の読み取り（`offsetHeight`, `getBoundingClientRect()` 等）と DOM の変更を交互に行うと、ブラウザが毎回レイアウトを再計算する
- Performance パネルで紫色の **Layout** イベントが連続して発生していないか確認する

```javascript
// 問題: 読み取りと書き込みを交互に実行
elements.forEach(el => {
  const height = el.offsetHeight; // レイアウト読み取り（強制リフロー発生）
  el.style.height = height * 2 + 'px'; // DOM 変更
});

// 解決: 読み取りをまとめてから書き込む
const heights = elements.map(el => el.offsetHeight); // 一括読み取り
elements.forEach((el, i) => {
  el.style.height = heights[i] * 2 + 'px'; // 一括書き込み
});
```

- `requestAnimationFrame()` を利用して DOM 変更を次のフレームにまとめる
- `will-change` CSS プロパティで変更予定のプロパティをブラウザに通知し、最適化を促す

---

## 状態管理デバッグ詳細

### 状態の不変性違反

- オブジェクトや配列を直接変更すると、React の再レンダリングが発火しない

```javascript
// 問題: 直接変更（ミューテーション）
const handleAdd = () => {
  items.push(newItem); // 配列の参照が変わらないため再レンダリングされない
  setItems(items);
};

// 解決: 新しい参照を作成する
const handleAdd = () => {
  setItems([...items, newItem]); // 新しい配列を作成
};

// 解決: Immer を使用する
const handleAdd = () => {
  setItems(produce(items, draft => {
    draft.push(newItem);
  }));
};
```

- `Object.freeze()` を開発環境で使用して、不変性違反を早期に検出する

### クロージャの罠

- `useEffect` や `useCallback` 内で参照する変数が古い値のまま固定される問題

```javascript
// 問題: count が常に初期値 0 を参照する
useEffect(() => {
  const id = setInterval(() => {
    console.log(count); // 常に 0
    setCount(count + 1); // 常に 1 になる
  }, 1000);
  return () => clearInterval(id);
}, []); // 依存配列が空

// 解決1: 依存配列に count を追加する
useEffect(() => {
  const id = setInterval(() => {
    setCount(count + 1);
  }, 1000);
  return () => clearInterval(id);
}, [count]);

// 解決2: 関数型更新を使用する
useEffect(() => {
  const id = setInterval(() => {
    setCount(prev => prev + 1); // 常に最新値を参照
  }, 1000);
  return () => clearInterval(id);
}, []);

// 解決3: useRef で最新値を保持する
const countRef = useRef(count);
countRef.current = count;
useEffect(() => {
  const id = setInterval(() => {
    console.log(countRef.current); // 常に最新値
  }, 1000);
  return () => clearInterval(id);
}, []);
```

- ESLint の `react-hooks/exhaustive-deps` ルールで依存配列の漏れを検出する

### 非同期状態更新

- コンポーネントがアンマウントされた後に状態を更新しようとするとメモリリークの原因となる

```javascript
// 問題: アンマウント後の setState
useEffect(() => {
  fetchData().then(data => {
    setData(data); // コンポーネントがアンマウント済みの場合に警告
  });
}, []);

// 解決: AbortController でキャンセルする
useEffect(() => {
  const controller = new AbortController();
  fetchData({ signal: controller.signal })
    .then(data => setData(data))
    .catch(err => {
      if (err.name !== 'AbortError') throw err;
    });
  return () => controller.abort();
}, []);
```

- 複数の非同期処理が競合する場合（レースコンディション）、最後のリクエストの結果のみを採用する

```javascript
useEffect(() => {
  let cancelled = false;
  fetchData(query).then(data => {
    if (!cancelled) setData(data);
  });
  return () => { cancelled = true; };
}, [query]);
```

---

## ネットワークデバッグ詳細

### CORS 問題の切り分け

- CORS エラーはブラウザ側で発生するため、サーバーのレスポンスヘッダーを確認する必要がある
- **切り分け手順**:
  1. Network パネルでリクエストとレスポンスのヘッダーを確認する
  2. プリフライトリクエスト（OPTIONS メソッド）が送信されているか確認する
  3. `curl` でサーバーに直接リクエストして、CORS ヘッダーの有無を確認する

```bash
# プリフライトリクエストのシミュレーション
curl -X OPTIONS https://api.example.com/endpoint \
  -H "Origin: https://app.example.com" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type, Authorization" \
  -v
```

- **よくある原因と対処**:
  - `Access-Control-Allow-Origin` にリクエスト元のオリジンが含まれていない
  - `Access-Control-Allow-Methods` に使用するメソッドが含まれていない
  - `Access-Control-Allow-Headers` にカスタムヘッダーが含まれていない
  - `Access-Control-Allow-Credentials: true` が設定されていない（認証情報付きリクエスト）
  - ワイルドカード `*` と `credentials: 'include'` は併用できない

### 認証トークンフロー

- **デバッグ手順**:
  1. Network パネルでログインリクエストのレスポンスからトークンが返却されているか確認する
  2. Application パネルでトークンの保存先（Cookie / LocalStorage / SessionStorage）を確認する
  3. 後続リクエストの `Authorization` ヘッダーにトークンが付与されているか確認する
  4. トークンの有効期限を確認する（JWT の場合は [jwt.io](https://jwt.io) でデコード）
- **よくある問題**:
  - リフレッシュトークンの更新タイミングが競合し、複数のリフレッシュリクエストが同時発生する
  - SameSite Cookie 属性の設定ミスでクロスサイトリクエストに Cookie が付与されない
  - Secure 属性が設定された Cookie が HTTP 環境で送信されない

### WebSocket デバッグ

- Network パネルで WS フィルタを使い、WebSocket フレームの送受信を確認する
- **接続ライフサイクルの確認**:
  - 接続の確立（101 Switching Protocols）
  - メッセージの送受信（テキスト / バイナリ）
  - 接続の切断（Close フレームのステータスコード）
- **よくある問題**:
  - プロキシやロードバランサーが WebSocket 接続をタイムアウトで切断する
  - 再接続ロジックの不備で接続が復帰しない
  - メッセージの順序保証が必要な場合にシーケンス番号が実装されていない

---

## CSS デバッグ

### Specificity（詳細度）問題

- 意図したスタイルが適用されない場合、Elements パネルの Styles タブで打ち消し線のスタイルを確認する
- **詳細度の計算方法**:
  - インラインスタイル: 1,0,0,0
  - ID セレクタ: 0,1,0,0
  - クラス / 属性 / 擬似クラス: 0,0,1,0
  - 要素 / 擬似要素: 0,0,0,1
- `!important` の乱用は詳細度の管理を破綻させるため、使用を最小限に留める
- CSS Modules や CSS-in-JS を使用してスコープを制限し、セレクタの衝突を防ぐ
- `:where()` セレクタを使うと詳細度を 0 に保てるため、リセット CSS やユーティリティに有用

### z-index 管理

- `z-index` が効かない場合、要素が新しいスタッキングコンテキストを形成しているか確認する
- スタッキングコンテキストを形成する主な条件:
  - `position` が `relative` / `absolute` / `fixed` / `sticky` かつ `z-index` が `auto` 以外
  - `opacity` が 1 未満
  - `transform`, `filter`, `perspective` が `none` 以外
  - `isolation: isolate`
- **管理手法**: z-index をトークンとして定義し、階層を一元管理する

```css
:root {
  --z-dropdown: 100;
  --z-sticky: 200;
  --z-modal-backdrop: 300;
  --z-modal: 400;
  --z-toast: 500;
  --z-tooltip: 600;
}
```

### レスポンシブデバッグ

- DevTools の Device Mode でビューポートサイズを変更してレイアウト崩れを確認する
- **よくある問題**:
  - `viewport` メタタグの不備（`width=device-width, initial-scale=1` が未設定）
  - メディアクエリの範囲が重複または欠落している
  - `overflow: hidden` でコンテンツがはみ出ている箇所を発見する
  - 固定幅の要素が画面幅を超えて横スクロールが発生する
- コンテナクエリ（`@container`）を使用する場合、コンテナとして定義された要素のサイズを確認する

### ダークモードデバッグ

- `prefers-color-scheme` メディアクエリの動作を DevTools の Rendering パネルで切り替える
- **よくある問題**:
  - カスタムプロパティ（CSS 変数）の切り替え忘れ
  - 画像やアイコンのコントラスト不足
  - `color-scheme: light dark` メタタグの未設定
  - フォームコントロールのデフォルトスタイルがテーマと不一致

---

## メモリリーク検出

### 検出手順

1. DevTools の Memory パネルで **Heap Snapshot** を取得する
2. 操作（ページ遷移やダイアログ開閉など）を行う
3. 再度 Heap Snapshot を取得する
4. **Comparison** ビューで増加したオブジェクトを確認する
5. **Allocation instrumentation on timeline** でメモリ割り当てのタイムラインを記録する

### イベントリスナー解放忘れ

```javascript
// 問題: クリーンアップが未実装
useEffect(() => {
  window.addEventListener('resize', handleResize);
  // return 文がないためリスナーが蓄積する
}, []);

// 解決: クリーンアップ関数でリスナーを解除する
useEffect(() => {
  window.addEventListener('resize', handleResize);
  return () => window.removeEventListener('resize', handleResize);
}, []);
```

- `getEventListeners(element)` を Console で実行し、要素にバインドされたリスナーを確認する

### タイマー解放忘れ

```javascript
// 問題: clearInterval が呼ばれない
useEffect(() => {
  const id = setInterval(poll, 5000);
  // クリーンアップが未実装
}, []);

// 解決: クリーンアップ関数でタイマーを解除する
useEffect(() => {
  const id = setInterval(poll, 5000);
  return () => clearInterval(id);
}, []);
```

- `setTimeout` の再帰呼び出しパターンでも同様にクリーンアップが必要

### DOM 参照によるリーク

- 削除済み DOM 要素への JavaScript からの参照が残ると、ガベージコレクションの対象にならない

```javascript
// 問題: 削除された要素への参照が残る
let cachedElement = document.getElementById('target');
document.getElementById('target').remove();
// cachedElement がまだ参照を保持しているためメモリが解放されない

// 解決: 参照を null に設定するか WeakRef を使用する
let cachedElement = new WeakRef(document.getElementById('target'));
// cachedElement.deref() で参照を取得（GC 済みの場合は undefined）
```

- `MutationObserver` や `ResizeObserver` の `disconnect()` 呼び出し忘れも原因となる

---

## パフォーマンスデバッグ

### Core Web Vitals の計測と改善

#### LCP（Largest Contentful Paint）

- 目標: 2.5 秒以内
- **計測**: Performance パネルの Web Vitals レーンで LCP マーカーを確認する
- **よくある原因と対策**:
  - ヒーロー画像の遅延読み込み → `loading="eager"` と `fetchpriority="high"` を設定する
  - Web フォントの読み込み遅延 → `font-display: swap` と `<link rel="preload">` を設定する
  - サーバーレスポンス遅延 → TTFB を改善する（キャッシュ、CDN、サーバー最適化）

#### INP（Interaction to Next Paint）

- 目標: 200 ミリ秒以内
- **計測**: `PerformanceObserver` で `event` タイプを監視する
- **よくある原因と対策**:
  - メインスレッドの長時間タスク → `requestIdleCallback` やWeb Worker でオフロードする
  - 重いイベントハンドラ → デバウンスやスロットリングを適用する
  - 大量の DOM 変更 → `requestAnimationFrame` でバッチ処理する

#### CLS（Cumulative Layout Shift）

- 目標: 0.1 以下
- **計測**: `PerformanceObserver` で `layout-shift` タイプを監視する
- **よくある原因と対策**:
  - 画像やiframeのサイズ未指定 → `width` / `height` 属性または `aspect-ratio` を指定する
  - 動的コンテンツの挿入 → 挿入先のスペースを事前に確保する
  - Web フォントの切り替え → `font-display: optional` または `size-adjust` を使用する

### 不要な再レンダリング検出

- React DevTools の Profiler で「Why did this render?」を有効にする
- **一般的な原因と対策**:

| 原因 | 対策 |
|------|------|
| 親コンポーネントの再レンダリング | `React.memo()` でメモ化 |
| インラインオブジェクト/関数の生成 | `useMemo()` / `useCallback()` で参照を安定化 |
| コンテキストの値変更 | コンテキストを分割し、変更範囲を局所化 |
| 状態の配置が不適切 | 状態を使用するコンポーネントに近づける |

```javascript
// 問題: 毎回新しいオブジェクトが生成される
<Component style={{ color: 'red' }} onClick={() => handleClick(id)} />

// 解決: メモ化して参照を安定させる
const style = useMemo(() => ({ color: 'red' }), []);
const handleItemClick = useCallback(() => handleClick(id), [id]);
<Component style={style} onClick={handleItemClick} />
```

- `React.Profiler` コンポーネントをコードに埋め込み、レンダリング時間をプログラム的に計測する

```jsx
<React.Profiler id="component" onRender={(id, phase, actualDuration) => {
  console.log(`${id} ${phase}: ${actualDuration}ms`);
}}>
  <Component />
</React.Profiler>
```
