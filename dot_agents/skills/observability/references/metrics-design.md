# メトリクス設計詳細

## 目次

1. [概要](#概要)
2. [メトリクスタイプ](#メトリクスタイプ)
   - [Counter（カウンター）](#counterカウンター)
   - [Gauge（ゲージ）](#gaugeゲージ)
   - [Histogram（ヒストグラム）](#histogramヒストグラム)
   - [Summary（サマリー）](#summaryサマリー)
3. [RED メソッド詳細実装](#red-メソッド詳細実装)
   - [Rate（レート）](#rateレート)
   - [Errors（エラー）](#errorsエラー)
   - [Duration（期間）](#duration期間)
   - [RED メトリクスの実装例](#red-メトリクスの実装例)
4. [USE メソッド詳細実装](#use-メソッド詳細実装)
   - [Utilization（使用率）](#utilization使用率)
   - [Saturation（飽和度）](#saturation飽和度)
   - [Errors（エラー）](#errorsエラー-1)
   - [USE メトリクスの実装例](#use-メトリクスの実装例)
5. [カスタムビジネスメトリクス設計](#カスタムビジネスメトリクス設計)
   - [ビジネスメトリクスの選定](#ビジネスメトリクスの選定)
   - [設計原則](#設計原則)
   - [実装例](#実装例)
6. [SLI/SLO/SLA 定義と設計](#slislosla-定義と設計)
   - [SLI（Service Level Indicator）](#sliservice-level-indicator)
   - [SLO（Service Level Objective）](#sloservice-level-objective)
   - [SLA（Service Level Agreement）](#slaservice-level-agreement)
   - [エラーバジェット](#エラーバジェット)
7. [パーセンタイル計算（p50/p95/p99）](#パーセンタイル計算p50p95p99)
   - [パーセンタイルの重要性](#パーセンタイルの重要性)
   - [計算方法](#計算方法)
   - [バケット設計](#バケット設計)
   - [実装での注意点](#実装での注意点)
8. [ダッシュボード設計原則](#ダッシュボード設計原則)
   - [階層構造](#階層構造)
   - [レイアウト原則](#レイアウト原則)
   - [グラフの選択](#グラフの選択)
   - [色とアラートの使い方](#色とアラートの使い方)
9. [カーディナリティ管理](#カーディナリティ管理)
   - [カーディナリティとは](#カーディナリティとは)
   - [高カーディナリティの問題](#高カーディナリティの問題)
   - [管理戦略](#管理戦略)
   - [ラベル設計のベストプラクティス](#ラベル設計のベストプラクティス)

---

## 概要

このドキュメントでは、フレームワークに依存しないメトリクス設計のパターンとベストプラクティスを詳述します。メトリクスタイプの選択、RED/USEメソッドの実装、SLI/SLO設計、ダッシュボード構築、カーディナリティ管理を網羅します。

---

## メトリクスタイプ

### Counter（カウンター）

**概要:**
- 単調増加する累積値
- リセットされない（再起動時のみ）
- レート計算に使用

**使用例:**
- HTTPリクエスト総数
- エラー発生総数
- 処理完了件数

**命名規則:**
- サフィックスに `_total` を付ける
- 例: `http_requests_total`, `errors_total`

**実装例:**
```
// 疑似コード
counter = Counter("http_requests_total", {
  labels: ["method", "endpoint", "status_code"]
})

// リクエスト処理時
counter.increment({
  method: "GET",
  endpoint: "/api/users",
  status_code: "200"
})
```

**クエリ例（PromQL風）:**
```
// 過去5分間のリクエストレート（req/s）
rate(http_requests_total[5m])

// ステータスコード別のレート
sum(rate(http_requests_total[5m])) by (status_code)
```

### Gauge（ゲージ）

**概要:**
- 任意に増減する値
- 現在の状態を表す
- 瞬間値を記録

**使用例:**
- 現在のアクティブユーザー数
- メモリ使用量
- キュー内のジョブ数
- 温度、湿度

**命名規則:**
- 現在の状態を表す名前
- 例: `active_connections`, `memory_usage_bytes`

**実装例:**
```
// 疑似コード
gauge = Gauge("active_connections", {
  labels: ["service"]
})

// 接続確立時
gauge.increment({ service: "database" })

// 接続切断時
gauge.decrement({ service: "database" })

// 直接設定
gauge.set(42, { service: "cache" })
```

**クエリ例:**
```
// 現在のアクティブ接続数
active_connections

// 過去1時間の最大値
max_over_time(active_connections[1h])
```

### Histogram（ヒストグラム）

**概要:**
- 値の分布を記録
- 事前定義されたバケットに集計
- パーセンタイル計算に使用
- サーバー側で集計

**使用例:**
- リクエストレイテンシ
- レスポンスサイズ
- データベースクエリ時間

**記録される値:**
- `_bucket`: 各バケットの累積カウント
- `_sum`: 全観測値の合計
- `_count`: 観測回数

**バケット設計:**
```
buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]
// 単位: 秒
```

**実装例:**
```
// 疑似コード
histogram = Histogram("http_request_duration_seconds", {
  labels: ["method", "endpoint"],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]
})

// リクエスト処理
start_time = now()
process_request()
duration = now() - start_time

histogram.observe(duration, {
  method: "GET",
  endpoint: "/api/users"
})
```

**クエリ例:**
```
// P95レイテンシ
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

// 平均レイテンシ
rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])
```

### Summary（サマリー）

**概要:**
- クライアント側でパーセンタイルを計算
- スライディングタイムウィンドウ
- 集計不可（複数インスタンス間）

**使用例:**
- 高精度なパーセンタイルが必要な場合
- 単一インスタンスの監視

**記録される値:**
- `_sum`: 全観測値の合計
- `_count`: 観測回数
- `{quantile="0.5"}`: P50値
- `{quantile="0.95"}`: P95値
- `{quantile="0.99"}`: P99値

**Histogram vs Summary:**

| 特徴 | Histogram | Summary |
|------|-----------|---------|
| パーセンタイル計算 | サーバー側 | クライアント側 |
| 集計可能性 | 可能 | 不可能 |
| メモリ使用量 | バケット数に依存 | より多い |
| 柔軟性 | クエリ時に変更可能 | 事前定義のみ |
| 推奨 | 多くの場合 | 特殊ケースのみ |

---

## RED メソッド詳細実装

REDメソッドは、リクエスト駆動型サービス（API、マイクロサービス）の監視に最適です。

### Rate（レート）

**定義:** リクエストの処理速度（req/s）

**メトリクス:**
```
http_requests_total (Counter)
labels: ["method", "endpoint", "status_code"]
```

**クエリ:**
```
// 全体のリクエストレート
sum(rate(http_requests_total[5m]))

// エンドポイント別
sum(rate(http_requests_total[5m])) by (endpoint)

// メソッド別
sum(rate(http_requests_total[5m])) by (method)
```

**ダッシュボード表示:**
- 折れ線グラフ（時系列）
- 単位: req/s
- 色: 青系（通常の動作）

### Errors（エラー）

**定義:** エラーの発生率（error/s または %）

**メトリクス:**
```
http_requests_total (Counter)
labels: ["method", "endpoint", "status_code"]
```

**クエリ:**
```
// エラー率（%）
sum(rate(http_requests_total{status_code=~"5.."}[5m])) /
sum(rate(http_requests_total[5m])) * 100

// エラーレート（error/s）
sum(rate(http_requests_total{status_code=~"5.."}[5m]))

// エンドポイント別エラー率
sum(rate(http_requests_total{status_code=~"5.."}[5m])) by (endpoint) /
sum(rate(http_requests_total[5m])) by (endpoint) * 100
```

**分類:**
- 4xx: クライアントエラー（通常はエラー率に含めない）
- 5xx: サーバーエラー（エラー率の対象）

**アラート:**
```
// エラー率が1%を超えた場合
(sum(rate(http_requests_total{status_code=~"5.."}[5m])) /
 sum(rate(http_requests_total[5m]))) > 0.01
```

### Duration（期間）

**定義:** リクエスト処理時間の分布

**メトリクス:**
```
http_request_duration_seconds (Histogram)
labels: ["method", "endpoint"]
buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]
```

**クエリ:**
```
// P50レイテンシ
histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[5m]))

// P95レイテンシ
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

// P99レイテンシ
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))

// エンドポイント別P95
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (endpoint, le))
```

**ダッシュボード表示:**
- 折れ線グラフ（P50, P95, P99を同時表示）
- 単位: ms または s
- 色: P50=緑, P95=黄, P99=赤

### RED メトリクスの実装例

**完全な実装:**
```
// 疑似コード
class REDMetrics:
  counter = Counter("http_requests_total", ["method", "endpoint", "status_code"])
  histogram = Histogram("http_request_duration_seconds", ["method", "endpoint"])

  function recordRequest(method, endpoint, status_code, duration_seconds):
    counter.increment({
      method: method,
      endpoint: endpoint,
      status_code: status_code
    })

    histogram.observe(duration_seconds, {
      method: method,
      endpoint: endpoint
    })

// ミドルウェアでの使用
function requestMiddleware(request, response):
  start_time = now()

  try:
    processRequest(request, response)
  finally:
    duration = now() - start_time
    REDMetrics.recordRequest(
      request.method,
      request.endpoint,
      response.status_code,
      duration
    )
```

---

## USE メソッド詳細実装

USEメソッドは、リソース（CPU、メモリ、ディスク、ネットワーク）の監視に最適です。

### Utilization（使用率）

**定義:** リソースがビジー状態である時間の割合（%）

**メトリクス例:**

**CPU使用率:**
```
cpu_usage_percent (Gauge)
labels: ["core", "mode"]  // mode: user, system, idle, iowait
```

**メモリ使用率:**
```
memory_usage_bytes (Gauge)
memory_total_bytes (Gauge)
```

**クエリ:**
```
// CPU使用率
100 - (avg(cpu_usage_percent{mode="idle"}) * 100)

// メモリ使用率
(memory_usage_bytes / memory_total_bytes) * 100
```

### Saturation（飽和度）

**定義:** リソースが処理しきれない作業量（キューの深さ）

**メトリクス例:**

**CPU飽和（ロードアベレージ）:**
```
system_load_average_1m (Gauge)
system_load_average_5m (Gauge)
system_load_average_15m (Gauge)
cpu_count (Gauge)
```

**ディスクI/O飽和:**
```
disk_io_queue_depth (Gauge)
labels: ["device"]
```

**クエリ:**
```
// CPUあたりのロードアベレージ
system_load_average_5m / cpu_count

// ディスクキューの深さ
disk_io_queue_depth
```

**飽和のサイン:**
- ロードアベレージ / CPUコア数 > 1.0
- ディスクI/Oキュー > 0（常時）
- ネットワークバッファドロップ > 0

### Errors（エラー）

**定義:** リソース関連のエラー

**メトリクス例:**
```
disk_read_errors_total (Counter)
disk_write_errors_total (Counter)
network_receive_errors_total (Counter)
network_transmit_errors_total (Counter)
```

**クエリ:**
```
// ディスクエラー率
rate(disk_read_errors_total[5m]) + rate(disk_write_errors_total[5m])

// ネットワークエラー率
rate(network_receive_errors_total[5m]) + rate(network_transmit_errors_total[5m])
```

### USE メトリクスの実装例

**リソース別のチェックリスト:**

| リソース | Utilization | Saturation | Errors |
|---------|-------------|------------|--------|
| CPU | 使用率 (%) | ロードアベレージ | - |
| メモリ | 使用率 (%) | スワップ使用量 | OOM kills |
| ディスク | 使用率 (%), I/O使用率 | I/Oキュー深さ | 読み書きエラー |
| ネットワーク | 帯域幅使用率 (%) | 送受信キュー | パケットドロップ、エラー |

---

## カスタムビジネスメトリクス設計

### ビジネスメトリクスの選定

**原則:**
- ビジネス価値と直結
- アクショナブル（アクションにつながる）
- ステークホルダーが理解できる

**カテゴリ:**

**1. ユーザーエンゲージメント:**
- アクティブユーザー数（DAU, MAU）
- セッション時間
- ページビュー
- 機能利用率

**2. ビジネストランザクション:**
- 注文数、売上
- 登録数、解約数
- コンバージョン率

**3. プロダクト健全性:**
- データ処理件数
- バッチジョブ成功率
- データ品質メトリクス

### 設計原則

**1. シンプルに保つ:**
- 複雑な計算はダッシュボード側で
- メトリクス自体は生データに近い形

**2. 粒度を考慮:**
- 時系列で追跡できる
- 適切な集計レベル（ユーザー別、テナント別など）

**3. ラベルの選択:**
- ビジネスディメンション（地域、プラン、ユーザーセグメント）
- 技術ディメンションと混在させない

### 実装例

**アクティブユーザー数:**
```
active_users_total (Gauge)
labels: ["time_window"]  // 1h, 24h, 7d, 30d

// 定期的に更新
gauge.set(count_active_users_last_24h(), { time_window: "24h" })
```

**コンバージョンファネル:**
```
funnel_step_completed_total (Counter)
labels: ["step"]  // signup, email_verify, profile_complete, first_purchase

// 各ステップ完了時
counter.increment({ step: "signup" })
counter.increment({ step: "email_verify" })
```

**クエリ:**
```
// ステップ間のコンバージョン率
funnel_step_completed_total{step="email_verify"} /
funnel_step_completed_total{step="signup"} * 100
```

**収益メトリクス:**
```
revenue_total (Counter)
labels: ["currency", "plan"]

transaction_amount (Histogram)
labels: ["currency", "plan"]
buckets: [1, 5, 10, 50, 100, 500, 1000, 5000]

// 購入時
revenue_total.increment(amount, { currency: "USD", plan: "pro" })
transaction_amount.observe(amount, { currency: "USD", plan: "pro" })
```

---

## SLI/SLO/SLA 定義と設計

### SLI（Service Level Indicator）

**定義:** サービスレベルを定量的に測定する指標

**代表的なSLI:**

**1. 可用性（Availability）:**
```
SLI = (成功リクエスト数 / 全リクエスト数) × 100
```

**2. レイテンシ（Latency）:**
```
SLI = リクエストのP95レイテンシ
```

**3. エラー率（Error Rate）:**
```
SLI = (エラーリクエスト数 / 全リクエスト数) × 100
```

**4. スループット（Throughput）:**
```
SLI = 単位時間あたりの処理数
```

**SLI選択の基準:**
- ユーザー体験と直結
- 測定可能
- コントロール可能

### SLO（Service Level Objective）

**定義:** SLIの目標値

**SLO設定例:**

```
SLO: 可用性 99.9% （月次）
SLO: P95レイテンシ < 200ms （週次）
SLO: エラー率 < 0.1% （月次）
```

**設定手順:**
1. 現状のパフォーマンスを測定（ベースライン）
2. ユーザー期待値を調査
3. ビジネス影響を評価
4. 実現可能性を検討
5. 段階的に目標を設定

**例: 可用性SLO計算**
```
月次SLO: 99.9%
月の総時間: 30日 × 24時間 = 720時間
許容ダウンタイム: 720時間 × 0.1% = 43.2分/月
```

### SLA（Service Level Agreement）

**定義:** SLOを含む顧客との契約

**SLAの構成要素:**
1. **スコープ:** 対象サービス・機能
2. **SLO:** 具体的な目標値
3. **測定方法:** 何をどう測定するか
4. **補償:** SLO未達時のペナルティ

**SLA例:**
```
サービス: API
SLO: 月次可用性 99.9%
測定: 5分間隔のヘルスチェック（外部監視）
補償: 99.9%未達時、月額料金の10%返金
      99.0%未達時、月額料金の25%返金
```

### エラーバジェット

**定義:** SLOを満たすための許容エラー量

**計算:**
```
エラーバジェット = 1 - SLO

例: SLO 99.9%の場合
エラーバジェット = 1 - 0.999 = 0.001 = 0.1%

月間100万リクエストの場合:
許容エラー数 = 1,000,000 × 0.001 = 1,000リクエスト
```

**エラーバジェットの活用:**
- **バジェット残あり:** 新機能開発、リスクある変更可能
- **バジェット消費中:** 安定性重視、変更を慎重に
- **バジェット超過:** 新機能停止、安定化に集中

**追跡メトリクス:**
```
error_budget_remaining (Gauge)
labels: ["slo"]

// 計算例（疑似コード）
target_availability = 0.999
actual_availability = calculate_availability_last_30d()
error_budget_remaining = (actual_availability - target_availability) / (1 - target_availability) * 100
```

---

## パーセンタイル計算（p50/p95/p99）

### パーセンタイルの重要性

**平均値の問題:**
- 外れ値に引っ張られる
- ユーザー体験を正確に反映しない

**例:**
```
レイテンシ: [10ms, 10ms, 10ms, 10ms, 10ms, 10ms, 10ms, 10ms, 10ms, 5000ms]
平均: 509ms
P50: 10ms
P95: 10ms
P99: 5000ms

→ 平均値では"遅い"と見えるが、90%のユーザーは10msで快適
```

**パーセンタイルの意味:**
- **P50（中央値）:** 半数のユーザーが体験する値
- **P95:** 95%のユーザーが体験する値（5%は除外）
- **P99:** 99%のユーザーが体験する値（1%は除外）
- **P99.9:** 99.9%のユーザーが体験する値

### 計算方法

**Histogram使用時:**
```
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

**仕組み:**
1. 各バケットのレートを計算
2. 累積分布を作成
3. 線形補間でパーセンタイル値を推定

### バケット設計

**原則:**
- 興味のある範囲を細かく分割
- 指数的に増加させる

**レイテンシの例:**
```
buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]
// 5ms, 10ms, 25ms, 50ms, 100ms, 250ms, 500ms, 1s, 2.5s, 5s, 10s
```

**理由:**
- 低レイテンシ（5-100ms）: 細かく分割（ユーザー体験に大きく影響）
- 高レイテンシ（1s以上）: 粗く分割（すでに遅いので細かい差は重要でない）

**カスタムバケット:**
```
// リクエストサイズ（バイト）
buckets: [100, 1000, 10000, 100000, 1000000, 10000000]

// データベースクエリ時間
buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 5]
```

### 実装での注意点

**1. 集計の正しさ:**
```
// 正しい: レートを計算してから集計
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

// 誤り: 各インスタンスのP95を平均（意味がない）
avg(histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])))
```

**2. 複数のパーセンタイルを同時に追跡:**
```
// ダッシュボードで同時表示
- P50（青）: 通常の体験
- P95（黄）: 多くのユーザーの上限
- P99（赤）: 悪いケース
```

**3. 外れ値の扱い:**
- 最大バケットを超える値は最大バケットにカウント
- `+Inf` バケットで捕捉

---

## ダッシュボード設計原則

### 階層構造

**レベル1: サービス全体の健全性（Overview）**
- 対象: 経営層、マネージャー
- 内容: 主要KPI、SLI、エラーバジェット
- 更新頻度: リアルタイム

**レベル2: サービス詳細（Detailed）**
- 対象: SRE、開発者
- 内容: RED/USEメトリクス詳細、サービス別
- 更新頻度: リアルタイム

**レベル3: 深堀り・デバッグ（Drill-down）**
- 対象: SRE、開発者（インシデント対応中）
- 内容: 特定コンポーネント、エラー詳細、ログとの連携
- 更新頻度: リアルタイム

### レイアウト原則

**上から下への重要度:**
1. **最上部:** 最重要メトリクス（SLI、エラー率、レイテンシ）
2. **中央:** 詳細メトリクス（RED/USE分解）
3. **下部:** 補助メトリクス（詳細ログへのリンク）

**左から右への時系列:**
- 左: 短期（直近1時間）
- 右: 長期（過去24時間、7日間）

**グリッドレイアウト:**
- 一貫した幅と高さ
- 関連メトリクスをグループ化

### グラフの選択

| メトリクスタイプ | 推奨グラフ | 理由 |
|----------------|-----------|------|
| レート、レイテンシ | 折れ線グラフ | 時系列の変化を追跡 |
| 使用率、割合 | 折れ線 + 閾値線 | 上限との比較 |
| 分布 | ヒートマップ | 複数パーセンタイルを同時表示 |
| 現在値 | ゲージ、単一数値 | 瞬間値の強調 |
| 比較 | 棒グラフ | サービス間、エンドポイント間の比較 |

### 色とアラートの使い方

**色の使い方:**
- **緑:** 正常、目標内
- **黄:** 注意、閾値接近
- **赤:** 異常、閾値超過
- **青/グレー:** ニュートラル、通常メトリクス

**アラートの視覚化:**
- 背景色変更
- 点滅（控えめに）
- アノテーション（イベントマーカー）

**ダッシュボード例構成:**
```
[タイトル: API Service Overview]

[Row 1: Key Metrics]
  [SLI: Availability 99.95%] [Error Budget: 45% remaining] [P95 Latency: 156ms]

[Row 2: Request Rate]
  [折れ線グラフ: Total req/s (1h)] [折れ線グラフ: Total req/s (24h)]

[Row 3: Error Rate]
  [折れ線グラフ: Error % (1h)] [折れ線グラフ: Error % by endpoint (1h)]

[Row 4: Latency]
  [折れ線グラフ: P50/P95/P99 (1h)] [ヒートマップ: Latency distribution (24h)]

[Row 5: Resource Utilization]
  [折れ線グラフ: CPU %] [折れ線グラフ: Memory %] [折れ線グラフ: Disk I/O]
```

---

## カーディナリティ管理

### カーディナリティとは

**定義:** メトリクスの一意な時系列の数

**計算:**
```
時系列数 = ラベルの組み合わせ数

例:
http_requests_total {method, endpoint, status_code}

method: 5種類（GET, POST, PUT, DELETE, PATCH）
endpoint: 100種類
status_code: 10種類（200, 201, 400, 401, 403, 404, 500, 502, 503, 504）

時系列数 = 5 × 100 × 10 = 5,000
```

### 高カーディナリティの問題

**影響:**
1. **メモリ使用量増加:** 各時系列がメモリを消費
2. **クエリ性能低下:** 集計時に多くの時系列を処理
3. **ストレージコスト増加:** より多くのデータ保存
4. **スケーラビリティ限界:** 監視システムの性能限界

**高カーディナリティの原因:**
- ユーザーIDをラベルに使用
- リクエストIDをラベルに使用
- タイムスタンプをラベルに使用
- IPアドレスをラベルに使用

### 管理戦略

**1. ラベルの選択を厳密に:**
- **Good:** 有限で予測可能（method, status_code, service）
- **Bad:** 無限または予測不可（user_id, request_id, ip_address）

**2. ラベル値を制限:**
```
// Bad: 100種類のエンドポイント
endpoint: "/api/users/123", "/api/users/456", ...

// Good: エンドポイントをパラメータ化
endpoint: "/api/users/:id"
```

**3. 高カーディナリティデータは別手段で:**
- ユーザー別メトリクス → ログベースの集計
- リクエストIDでのトレース → 分散トレーシングシステム

**4. サンプリング:**
- すべてのリクエストを記録する必要はない
- 統計的に有意なサンプルサイズで十分

**5. 集約とロールアップ:**
```
// 詳細（1分保持）
http_requests_total {method, endpoint, status_code}

// 集約（長期保持）
http_requests_total {method}
```

### ラベル設計のベストプラクティス

**推奨ラベル:**
| ラベル | カーディナリティ | 例 |
|--------|------------------|-----|
| service | 低（10-100） | "api", "web", "worker" |
| environment | 低（3-5） | "prod", "staging", "dev" |
| region | 低（5-20） | "us-east-1", "eu-west-1" |
| method | 低（5-10） | "GET", "POST", "PUT" |
| status_code | 低（10-20） | "200", "404", "500" |
| endpoint | 中（10-100） | "/api/users", "/api/orders" |

**避けるべきラベル:**
- user_id, customer_id
- request_id, trace_id（分散トレーシングで管理）
- ip_address
- email
- タイムスタンプ

**カーディナリティの監視:**
```
// メトリクスの時系列数を監視
count({__name__=~"http_.*"})

// ラベル別の時系列数
count by (__name__)({__name__=~"http_.*"})
```

**アラート:**
```
// 時系列数が100万を超えた場合
count({__name__=~".*"}) > 1000000
```

---

## まとめ

効果的なメトリクス設計は、システムの可観測性を確保し、問題の早期検出と迅速な対応を可能にします。このリファレンスで示したパターンを参考に、プロジェクトのニーズに合わせてカスタマイズしてください。

**重要ポイント:**
- 適切なメトリクスタイプを選択（Counter, Gauge, Histogram）
- RED/USEメソッドでカバレッジを確保
- SLI/SLOで目標を明確化
- パーセンタイルでユーザー体験を正確に把握
- カーディナリティを管理してスケーラビリティを確保
- ダッシュボードで視覚化し、アクションにつなげる
