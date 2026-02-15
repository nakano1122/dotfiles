---
name: search-model-builder
description: "HuggingFace/sentence-transformers ベースの検索・情報検索モデル（Bi-Encoder, Cross-Encoder, ColBERT, SPLADE 等）構築ガイド。Web調査による最新コード取得、データ前処理、訓練ループ設計、Weights & Biases連携、計算効率最適化をカバー。検索モデルの新規構築・ファインチューニング・評価時に使用。"
---

# 検索モデル構築ガイド

HuggingFace/sentence-transformers ベースの検索・情報検索モデル構築ガイド。

> **重要**: HuggingFace のAPI・コードは頻繁に変更される。モデル実装の具体的なコードは毎回 WebFetch/WebSearch で最新情報を取得すること。本スキルには安定的な知識（訓練ループ、前処理パターン等）のみを記載する。

## ワークフロー

```
1. 要件確認        → タスク種別・データ・制約を整理
2. リソース見積もり → GPU/VRAM/ディスク/訓練時間の概算（下記参照）
3. Web調査         → 最新API・モデルクラス・損失関数を調査
4. データ前処理    → データ読み込み・前処理・DataLoader構築
5. モデル構築      → Web調査結果を基にモデルを構築
6. 訓練設定        → optimizer/scheduler/W&B設定
7. スモークテスト  → 小規模データ（100件）で訓練ループが回ることを確認
8. 訓練実行        → 訓練ループ実行・進捗監視
9. 評価            → 検索指標で性能評価
10. 保存・共有     → モデル保存・HuggingFace Hub公開（任意）
```

### リソース見積もり（必須）

```
訓練開始前に必ず以下を確認:

GPU:
  - torch.cuda.is_available() で GPU が利用可能か確認
  - GPU 無しでの BERT ファインチューニングは非現実的（1エポック数日）
  - VRAM 容量に応じたバッチサイズを選択（後述の目安表参照）

訓練時間の概算:
  total_steps = len(dataset) / batch_size * num_epochs
  → 1ステップあたりの時間をスモークテストで計測
  → total_steps * step_time で総訓練時間を見積もる
  → 24時間を超える場合はデータ量・エポック数・モデルサイズを再検討

ディスク容量:
  - ベースモデル: 0.4〜2GB（ダウンロード時）
  - チェックポイント: モデルサイズ x 3（model + optimizer state）x 保存数
  - 例: 335Mモデル + AdamW = 約4GB/チェックポイント
  - 10エポック保存 = 40GB+（cleanup_checkpoints で古いものを削除）

RAM:
  - データセット全件メモリ展開: 件数 x 平均テキストサイズで概算
  - 100万件超は streaming=True を検討
```

## モデルアーキテクチャ選択ガイド

### 特性比較

| アーキテクチャ | レイテンシ | 精度 | インデックス | 主な用途 |
|---------------|-----------|------|-------------|---------|
| Bi-Encoder | 低（事前計算可） | 中 | ベクトル検索 | 大規模検索、セマンティック検索 |
| Cross-Encoder | 高（ペア推論） | 高 | 不可 | リランキング、小規模分類 |
| ColBERT | 中 | 高 | トークンレベル | 高精度検索、遅延インタラクション |
| SPLADE | 低〜中 | 中〜高 | スパースインデックス | スパース検索、ハイブリッド検索 |

### 判断フロー

```
大規模コーパスから検索したい？
├→ Yes → レイテンシ制約厳しい？
│        ├→ Yes → Bi-Encoder（ANN検索と組み合わせ）
│        └→ No  → ColBERT or Bi-Encoder + Cross-Encoder リランキング
└→ No  → ペア単位の精密判定？
         ├→ Yes → Cross-Encoder
         └→ No  → SPLADE（キーワード＋セマンティック両立）
```

## Web調査プロトコル（概要）

HuggingFace エコシステムは変化が速いため、実装前に必ず最新情報を取得する。

### 調査すべきリソース

```
1. sentence-transformers 公式ドキュメント
   → https://www.sbert.net/
2. HuggingFace Hub - モデルカード
   → https://huggingface.co/models?library=sentence-transformers
3. sentence-transformers GitHub リポジトリ
   → https://github.com/UKPLab/sentence-transformers
4. HuggingFace Transformers ドキュメント
   → https://huggingface.co/docs/transformers/
5. PyPI - sentence-transformers
   → バージョン・変更履歴の確認
```

### WebSearch 検索クエリテンプレート

```
- "sentence-transformers {version} training example {year}"
- "sentence-transformers {loss_function} usage {year}"
- "huggingface {model_type} fine-tuning tutorial {year}"
- "sentence-transformers CrossEncoder training guide {year}"
- "ColBERT v2 training huggingface {year}"
- "SPLADE training sentence-transformers {year}"
```

### 調査手順

```
1. WebSearch で最新のチュートリアル・公式ドキュメントを検索
2. WebFetch で公式ドキュメント・GitHub の具体的コードを取得
3. 取得したコードのバージョン互換性を確認
4. 既存コードベースの依存バージョンと照合
5. 不整合があればフォールバック戦略を実行
```

詳細: [references/web-research-protocol.md](references/web-research-protocol.md)

## 訓練データ準備（概要）

### データ形式分類

| 形式 | 構造 | 主な用途 |
|------|------|---------|
| Pair | (query, positive) | Bi-Encoder基本訓練 |
| Triplet | (anchor, positive, negative) | コントラスティブ学習 |
| Pair + Score | (text1, text2, score) | STS回帰タスク |
| Query + Docs + Labels | (query, doc, relevance) | ランキング学習 |

### ネガティブサンプリング

```
Random Negative   → 簡単、だが非効率
Hard Negative     → BM25/既存モデルで取得、高品質
In-Batch Negative → バッチ内の他ペアを流用、GPU効率良
```

### DataLoader設計の原則

```
- Dynamic Padding: バッチ内の最大長に合わせてパディング
- collate_fn でバッチ構築ロジックをカスタム
- num_workers はCPUコア数の半分を目安
- pin_memory=True（GPU使用時）
```

詳細: [references/data-preprocessing.md](references/data-preprocessing.md)

## 訓練の基本構造（概要）

### 訓練ループスケルトン

```python
# 注意: 具体的なimport・APIは Web調査で最新を確認すること
for epoch in range(num_epochs):
    model.train()
    for batch in tqdm(train_dataloader, desc=f"Epoch {epoch+1}"):
        optimizer.zero_grad()
        loss = compute_loss(model, batch)
        loss.backward()
        optimizer.step()
        scheduler.step()
    # 検証・チェックポイント保存
    evaluate(model, val_dataloader)
    save_checkpoint(model, epoch)
```

### 損失関数選択

| 損失関数 | データ形式 | 用途 |
|---------|-----------|------|
| MultipleNegativesRankingLoss | (anchor, positive) | コントラスティブ学習の定番 |
| CosineSimilarityLoss | (text1, text2, score) | 類似度回帰 |
| TripletLoss | (anchor, pos, neg) | トリプレット学習 |
| ContrastiveLoss | (text1, text2, label) | ペア分類 |
| InfoNCE / NTXentLoss | (anchor, positive) | 対照学習 |
| MarginMSELoss | (query, pos, neg, scores) | 知識蒸留 |

> 損失関数クラスの具体的なimportパスと引数は Web調査で確認すること

詳細: [references/training-loop-patterns.md](references/training-loop-patterns.md)

## W&B連携（概要）

### 基本設定

```python
import wandb

wandb.init(
    project="search-model-training",
    name=f"{model_name}-{dataset_name}",
    config={
        "model_name": model_name,
        "learning_rate": lr,
        "batch_size": batch_size,
        "num_epochs": num_epochs,
        "loss_function": loss_fn_name,
        "max_seq_length": max_seq_length,
    },
)
```

### ログ指標一覧

| カテゴリ | 指標 | 頻度 |
|---------|------|------|
| 訓練 | train/loss, train/lr | ステップ毎 |
| 検証 | val/loss, val/mrr, val/ndcg | エポック毎 |
| システム | gpu/memory, gpu/utilization | 自動 |
| ハイパラ | 全ハイパーパラメータ | 初期化時 |

詳細: [references/wandb-integration.md](references/wandb-integration.md)

## 計算効率の原則

### Mixed Precision

```
- fp16: NVIDIA Volta以降（V100, A100, RTX 30xx+）
- bf16: Ampere以降（A100, RTX 30xx+）、勾配のダイナミックレンジ広い
- 選択: bf16対応GPU → bf16、それ以外 → fp16
```

### Gradient Accumulation

```
実効バッチサイズ = バッチサイズ × accumulation_steps
→ VRAM不足時にバッチサイズを擬似的に拡大
→ accumulation_steps = 目標バッチサイズ / GPUバッチサイズ
```

### Gradient Checkpointing

```
- VRAM使用量を大幅削減（計算時間は10-20%増）
- 大規模モデル（>300Mパラメータ）で特に有効
- model.gradient_checkpointing_enable() で有効化
```

### tqdm 使用指針

```
- エポック進捗: tqdm(range(num_epochs), desc="Training")
- ステップ進捗: tqdm(dataloader, desc=f"Epoch {epoch}")
- postfix で loss/lr をリアルタイム表示
- tqdm.write() でログ出力（進捗バーを崩さない）
```

### GPU VRAM別バッチサイズ目安

| GPU | VRAM | base (128tok) | large (512tok) |
|-----|------|---------------|----------------|
| RTX 3090 | 24GB | 64-128 | 16-32 |
| A100 40GB | 40GB | 128-256 | 32-64 |
| A100 80GB | 80GB | 256-512 | 64-128 |
| H100 | 80GB | 256-512+ | 64-128+ |

※ fp16/bf16使用時。モデルサイズ・系列長で大きく変動する。詳細（モデルサイズ別・Cross-Encoder別）は [references/data-preprocessing.md](references/data-preprocessing.md) を参照

## 評価指標

| 指標 | 説明 | 範囲 | 用途 |
|------|------|------|------|
| MRR@k | 最初の正解文書の逆順位の平均 | [0, 1] | ランキング品質 |
| NDCG@k | 理想順位との比較（段階的関連度対応） | [0, 1] | 多段階関連度評価 |
| Recall@k | 上位kに含まれる正解の割合 | [0, 1] | 網羅性評価 |
| MAP | 各クエリの平均適合率の平均 | [0, 1] | 全体的なランキング品質 |
| Hit@k | 上位kに1つでも正解があるかの割合 | [0, 1] | 検索成功率 |
| P@k | 上位kの適合率 | [0, 1] | 上位精度 |

## レビューチェックリスト

**リソース安全性（最優先）:**
- [ ] GPU が利用可能であることを確認した（CPU訓練は非現実的）
- [ ] バッチサイズが GPU VRAM に収まることを確認した
- [ ] 訓練時間を概算し、現実的な範囲であることを確認した
- [ ] ディスク容量がチェックポイント保存に十分であることを確認した
- [ ] 大規模コーパスのエンコードは CPU に退避しているか FAISS を使用している
- [ ] 古いチェックポイントの自動削除が設定されている

**実装品質:**
- [ ] Web調査で最新のAPIバージョン・importパスを確認した
- [ ] データ形式と損失関数の組み合わせが整合している
- [ ] ネガティブサンプリング戦略が選択・実装されている
- [ ] mixed precision が適切に設定されている
- [ ] gradient accumulation の実効バッチサイズが意図通りである
- [ ] W&B でハイパーパラメータと指標がログされている
- [ ] 評価指標がタスク要件に合致している
- [ ] チェックポイント保存が設定されている
- [ ] 再現性のためシード固定されている
- [ ] tqdm で訓練進捗が可視化されている

## リファレンス

- [sentence-transformers 公式](https://www.sbert.net/)
- [HuggingFace Transformers](https://huggingface.co/docs/transformers/)
- [Weights & Biases](https://docs.wandb.ai/)
- [references/web-research-protocol.md](references/web-research-protocol.md) - Web調査手順・URL辞書
- [references/data-preprocessing.md](references/data-preprocessing.md) - データ前処理・DataLoader設計
- [references/training-loop-patterns.md](references/training-loop-patterns.md) - 訓練ループ・効率化・tqdm
- [references/wandb-integration.md](references/wandb-integration.md) - W&B統合パターン
