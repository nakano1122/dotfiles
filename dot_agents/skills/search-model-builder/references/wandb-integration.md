# W&B統合パターン

検索モデル訓練における Weights & Biases (wandb) の統合パターン。

## 目次

1. [wandb.init設定](#wandbinit設定)
2. [訓練中ロギング](#訓練中ロギング)
3. [Sweep設定](#sweep設定)
4. [Artifact管理](#artifact管理)
5. [wandb.Table検索結果可視化](#wandbtable検索結果可視化)
6. [オフライン実行モード](#オフライン実行モード)

## wandb.init設定

### 基本設定

```python
import wandb

run = wandb.init(
    project="search-model-training",
    name=f"{model_name}-{dataset_name}-{timestamp}",
    tags=["bi-encoder", "fine-tuning", dataset_name],
    notes="Initial fine-tuning experiment with hard negatives",
    config={
        # モデル設定
        "model_name": model_name,
        "model_type": "bi-encoder",  # bi-encoder, cross-encoder, colbert, splade
        "base_model": "intfloat/multilingual-e5-base",
        "max_seq_length": 512,
        "pooling_mode": "mean",

        # 訓練設定
        "learning_rate": 2e-5,
        "batch_size": 64,
        "effective_batch_size": 256,  # batch_size * gradient_accumulation_steps
        "gradient_accumulation_steps": 4,
        "num_epochs": 10,
        "warmup_ratio": 0.1,
        "weight_decay": 0.01,
        "max_grad_norm": 1.0,
        "scheduler": "linear_with_warmup",

        # 損失関数
        "loss_function": "MultipleNegativesRankingLoss",
        "negative_sampling": "in-batch + hard_negatives",
        "num_hard_negatives": 5,

        # 効率化
        "amp_dtype": "bf16",
        "gradient_checkpointing": True,

        # データ
        "dataset_name": dataset_name,
        "train_size": len(train_dataset),
        "val_size": len(val_dataset),

        # 評価
        "eval_metric": "mrr@10",
        "eval_steps": 500,

        # 再現性
        "seed": 42,
    },
)
```

### 環境情報の自動記録

```python
# wandb.init() 時に自動的に記録される情報:
# - GPU 名・VRAM
# - CUDA バージョン
# - Python バージョン
# - OS 情報
# - git commit hash（git リポジトリ内の場合）

# 追加で手動記録する情報
wandb.config.update({
    "torch_version": torch.__version__,
    "transformers_version": transformers.__version__,
    "sentence_transformers_version": sentence_transformers.__version__,
    "cuda_version": torch.version.cuda,
    "gpu_name": torch.cuda.get_device_name(0) if torch.cuda.is_available() else "cpu",
    "gpu_count": torch.cuda.device_count(),
})
```

### プロジェクト命名規則

```
プロジェクト名: search-model-training
Run名: {model_type}-{base_model_short}-{dataset}-{timestamp}

例:
  bi-encoder-e5base-msmarco-20240315-1430
  cross-encoder-deberta-nfcorpus-20240315-1500
  colbert-bert-beir-20240316-0900

タグ例:
  ["bi-encoder", "fine-tuning", "msmarco", "hard-negatives", "bf16"]
```

## 訓練中ロギング

### 指標テーブル

| カテゴリ | 指標 | ログ頻度 | 説明 |
|---------|------|---------|------|
| **訓練** | train/loss | ステップ毎 | 訓練損失 |
| | train/lr | ステップ毎 | 学習率 |
| | train/global_step | ステップ毎 | グローバルステップ数 |
| | train/epoch_loss | エポック毎 | エポック平均損失 |
| | train/grad_norm | ステップ毎（任意） | 勾配ノルム |
| **検証** | val/loss | エポック毎 | 検証損失 |
| | val/mrr@10 | エポック毎 | MRR@10 |
| | val/ndcg@10 | エポック毎 | NDCG@10 |
| | val/recall@100 | エポック毎 | Recall@100 |
| | val/map | エポック毎 | MAP |
| | val/hit@10 | エポック毎 | Hit@10 |
| **システム** | gpu/memory | 自動 | GPU VRAM使用量 |
| | gpu/utilization | 自動 | GPU 使用率 |
| | system/throughput | エポック毎 | サンプル/秒 |

### ステップ単位のロギング

```python
# 訓練ループ内
if global_step % log_steps == 0:
    wandb.log({
        "train/loss": loss.item(),
        "train/lr": scheduler.get_last_lr()[0],
        "train/global_step": global_step,
    })
```

### エポック単位のロギング

```python
# エポック終了時
wandb.log({
    "epoch": epoch + 1,
    "train/epoch_loss": avg_train_loss,
    "val/loss": val_loss,
    "val/mrr@10": metrics["mrr@10"],
    "val/ndcg@10": metrics["ndcg@10"],
    "val/recall@100": metrics.get("recall@100", 0),
    "val/map": metrics.get("map", 0),
    "val/hit@10": metrics.get("hit@10", 0),
    "system/throughput": total_samples / elapsed_time,
})
```

### ログ頻度の設計

```
ステップ毎（高頻度）:
  → loss, lr は毎ステップ or N ステップ毎
  → N = 10〜100 が一般的（データセットサイズに依存）
  → 大きすぎると問題の発見が遅れる
  → 小さすぎると W&B のオーバーヘッドが増加

エポック毎（低頻度）:
  → 検証指標はエポック毎（or eval_steps 毎）
  → エポック平均損失
  → スループット

初期化時（1回のみ）:
  → ハイパーパラメータ（config）
  → 環境情報
```

### 勾配ノルムの監視（任意）

```python
# 勾配爆発/消失の検出に有用
total_norm = torch.nn.utils.clip_grad_norm_(model.parameters(), max_grad_norm)
wandb.log({"train/grad_norm": total_norm.item()})
```

## Sweep設定

### 検索モデル向け探索空間推奨

```yaml
# sweep_config.yaml
program: train.py
method: bayes  # bayes, grid, random
metric:
  name: val/mrr@10
  goal: maximize

parameters:
  learning_rate:
    distribution: log_uniform_values
    min: 1e-6
    max: 5e-5

  batch_size:
    values: [32, 64, 128]

  num_epochs:
    values: [3, 5, 10]

  warmup_ratio:
    values: [0.05, 0.1, 0.2]

  weight_decay:
    values: [0.0, 0.01, 0.1]

  max_seq_length:
    values: [128, 256, 512]

  loss_function:
    values:
      - MultipleNegativesRankingLoss
      - TripletLoss
      - CosineSimilarityLoss

  pooling_mode:
    values: [mean, cls, max]

early_terminate:
  type: hyperband
  min_iter: 3
  eta: 3
```

### Sweep の実行

```python
import wandb

# Sweep の作成
sweep_id = wandb.sweep(sweep_config, project="search-model-training")

# Sweep の実行
def train_sweep():
    with wandb.init() as run:
        config = wandb.config
        # config.learning_rate, config.batch_size 等でアクセス
        train(
            model=create_model(config),
            lr=config.learning_rate,
            batch_size=config.batch_size,
            ...
        )

wandb.agent(sweep_id, function=train_sweep, count=20)  # 最大20回
```

### Sweep 探索戦略

```
grid: 全組み合わせ → パラメータ数が少ない場合（2-3個以下）
random: ランダム → 初期探索、パラメータ空間が広い場合
bayes: ベイズ最適化 → 本番探索、収束が速い

⚠ grid の組み合わせ爆発に注意:
  7パラメータ x 各3値 = 3^7 = 2,187 回の訓練
  1回の訓練が1時間なら 2,187時間（約91日）
  → grid は 2-3パラメータ・各2-3値（合計20回以下）に限定すること
  → 4パラメータ以上は必ず bayes または random を使用

推奨戦略:
  1. random で広範囲を探索（10-20回）
  2. 有望な範囲を特定
  3. bayes で狭い範囲を集中探索（20-50回）

必ず count（最大実行回数）を設定し、無制限実行を防ぐ。
```

## Artifact管理

### モデルの保存

```python
# ベストモデルを Artifact として保存
artifact = wandb.Artifact(
    name=f"search-model-{wandb.run.id}",
    type="model",
    description=f"Best model (MRR@10: {best_mrr:.4f})",
    metadata={
        "model_type": "bi-encoder",
        "base_model": base_model_name,
        "best_mrr@10": best_mrr,
        "best_epoch": best_epoch,
    },
)

# ディレクトリごと追加
artifact.add_dir(best_model_dir)

# ログ
wandb.log_artifact(artifact)
```

### データセットの保存

```python
# 訓練データセットを Artifact として保存（再現性のため）
data_artifact = wandb.Artifact(
    name=f"training-data-{dataset_name}",
    type="dataset",
    description="Training dataset with hard negatives",
    metadata={
        "train_size": len(train_dataset),
        "val_size": len(val_dataset),
        "negative_sampling": "bm25_hard",
    },
)

data_artifact.add_file("data/train.jsonl")
data_artifact.add_file("data/val.jsonl")
wandb.log_artifact(data_artifact)
```

### Artifact の利用

```python
# 以前のモデルを取得
artifact = wandb.use_artifact("search-model-abc123:latest")
model_dir = artifact.download()

# 以前のデータセットを取得
data_artifact = wandb.use_artifact("training-data-msmarco:v2")
data_dir = data_artifact.download()
```

## wandb.Table検索結果可視化

### 検索結果サンプルの可視化

```python
def log_retrieval_examples(model, queries, corpus, k=5, num_examples=20):
    """検索結果のサンプルをテーブルとして記録

    注意: コーパスのエンコードはループの外で1回だけ実行する。
    ループ内で毎回エンコードすると O(num_examples x corpus_size) の計算量になり、
    20クエリ x 100万文書 = 2000万回のエンコードで天文学的な時間がかかる。
    """
    columns = ["query", "rank", "document", "score", "relevant"]
    table = wandb.Table(columns=columns)

    # コーパスのエンコードは1回だけ（CPU に保持して VRAM 枯渇防止）
    corpus_embeddings = model.encode(corpus, convert_to_numpy=True, show_progress_bar=True)

    for query, relevant_docs in queries[:num_examples]:
        query_embedding = model.encode(query, convert_to_numpy=True)
        scores = np.dot(corpus_embeddings, query_embedding) / (
            np.linalg.norm(corpus_embeddings, axis=1) * np.linalg.norm(query_embedding)
        )
        top_k_indices = np.argsort(scores)[::-1][:k]

        for rank, idx in enumerate(top_k_indices, 1):
            table.add_data(
                query,
                rank,
                corpus[idx][:200],
                f"{scores[idx]:.4f}",
                corpus[idx] in relevant_docs,
            )

    wandb.log({"retrieval_examples": table})
```

### エラー分析テーブル

```python
def log_error_analysis(model, eval_data, k=10):
    """検索に失敗したクエリの分析"""
    columns = ["query", "expected_doc", "top1_doc", "top1_score", "expected_rank"]
    table = wandb.Table(columns=columns)

    for query, relevant_doc in eval_data:
        results = retrieve(model, query, k=k)

        # 正解が上位kに含まれない場合のみ記録
        top_docs = [r["doc"] for r in results]
        if relevant_doc not in top_docs:
            table.add_data(
                query,
                relevant_doc[:200],
                results[0]["doc"][:200],
                f"{results[0]['score']:.4f}",
                "Not in top-k",
            )

    wandb.log({"error_analysis": table})
```

### スコア分布の可視化

```python
# ヒストグラム
wandb.log({
    "score_distribution": wandb.Histogram(all_scores),
    "positive_scores": wandb.Histogram(positive_scores),
    "negative_scores": wandb.Histogram(negative_scores),
})
```

## オフライン実行モード

### オフラインモード設定

```python
import os

# 環境変数で設定（コード変更不要）
os.environ["WANDB_MODE"] = "offline"

# または init 時に指定
wandb.init(mode="offline", ...)
```

### オフラインログの同期

```bash
# オフラインで記録したログを後で同期
wandb sync ./wandb/offline-run-*

# 特定の run を同期
wandb sync ./wandb/offline-run-20240315_143000-abc123
```

### ドライランモード

```python
# W&B にデータを送信せずにコードの動作確認
os.environ["WANDB_MODE"] = "disabled"
# → wandb.init() やwandb.log() は何もしない（エラーにならない）
```

### モード選択ガイド

```
online（デフォルト）:
  → リアルタイムでダッシュボード確認可能
  → インターネット接続が必要

offline:
  → インターネット接続なしで訓練可能
  → 後で wandb sync で同期
  → クラウドGPU（ネットワーク不安定な環境）に適する

disabled:
  → W&B を完全に無効化
  → デバッグ・テスト実行時に使用
  → wandb の API 呼び出しがスキップされる
```

### W&B 統合チェックリスト

```
初期設定:
  - [ ] wandb.init() で project, name, config が設定されている
  - [ ] 環境情報（GPU, ライブラリバージョン）が記録されている
  - [ ] 適切な tags が設定されている

訓練中:
  - [ ] train/loss が適切な頻度でログされている
  - [ ] train/lr がログされている
  - [ ] val/ 指標がエポック毎にログされている
  - [ ] ログ頻度が過剰でない（パフォーマンスへの影響を確認）

訓練後:
  - [ ] ベストモデルが Artifact として保存されている
  - [ ] 検索結果のサンプルが Table で可視化されている
  - [ ] wandb.finish() が呼ばれている

Sweep:
  - [ ] 探索空間が適切に設定されている
  - [ ] early_terminate が設定されている（非効率な run を早期停止）
  - [ ] 最適化対象の指標が正しい
```
