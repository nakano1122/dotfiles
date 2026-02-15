# データ前処理・DataLoader設計

検索モデル訓練用のデータ前処理パイプラインとDataLoader設計パターン。

## 目次

1. [データ形式分類](#データ形式分類)
2. [datasets読み込みパターン](#datasets読み込みパターン)
3. [テキスト前処理](#テキスト前処理)
4. [ネガティブサンプリング](#ネガティブサンプリング)
5. [DataLoader設計](#dataloader設計)
6. [GPU VRAM別バッチサイズ目安](#gpu-vram別バッチサイズ目安)
7. [データ品質チェックリスト](#データ品質チェックリスト)

## データ形式分類

### Pair形式

```
用途: Bi-Encoder 基本訓練（正例ペアのみ）
構造: (query, positive_passage)
損失関数: MultipleNegativesRankingLoss（in-batch negatives を自動生成）

例:
  query: "Pythonでリストをソートする方法"
  positive: "sorted()関数またはlist.sort()メソッドを使用します..."
```

### Triplet形式

```
用途: コントラスティブ学習
構造: (anchor, positive, negative)
損失関数: TripletLoss, MultipleNegativesRankingLoss

例:
  anchor:   "Pythonでリストをソートする方法"
  positive: "sorted()関数を使用します..."
  negative: "Pythonのリストは動的配列です..."
```

### Pair + Score形式

```
用途: STS（Semantic Textual Similarity）回帰タスク
構造: (text1, text2, similarity_score)
損失関数: CosineSimilarityLoss
スコア範囲: 通常 0.0〜1.0 に正規化

例:
  text1: "猫が座っている"
  text2: "ネコが腰を下ろしている"
  score: 0.85
```

### Query + Docs + Labels形式

```
用途: ランキング学習、知識蒸留
構造: (query, document, relevance_label) or (query, positive, negative, teacher_scores)
損失関数: MarginMSELoss, CrossEntropyLoss

例:
  query: "Pythonソート"
  doc1: "sorted()関数..." (relevance: 3)
  doc2: "Python概要..."    (relevance: 0)
```

## datasets読み込みパターン

### HuggingFace Datasets からの読み込み

```python
from datasets import load_dataset

# 基本的な読み込み
dataset = load_dataset("dataset_name")
dataset = load_dataset("dataset_name", split="train")

# サブセットの指定
dataset = load_dataset("dataset_name", "subset_name")

# ストリーミング（大規模データセット向け、100万件超で推奨）
# 全件をRAMに展開しないため、メモリ消費を大幅に削減
dataset = load_dataset("dataset_name", split="train", streaming=True)

# フィルタリング
dataset = dataset.filter(lambda x: len(x["query"]) > 10)

# カラム選択
dataset = dataset.select_columns(["query", "positive", "negative"])
```

### ローカルファイルからの読み込み

```python
from datasets import load_dataset

# JSON / JSONL
dataset = load_dataset("json", data_files="data/train.jsonl")

# CSV / TSV
dataset = load_dataset("csv", data_files="data/train.csv")
dataset = load_dataset("csv", data_files="data/train.tsv", delimiter="\t")

# Parquet
dataset = load_dataset("parquet", data_files="data/train.parquet")

# 複数ファイル
dataset = load_dataset("json", data_files={
    "train": "data/train.jsonl",
    "validation": "data/val.jsonl",
    "test": "data/test.jsonl",
})
```

### Train/Validation/Test分割

```python
from datasets import load_dataset

dataset = load_dataset("dataset_name")

# 既にsplitがある場合
train_dataset = dataset["train"]
val_dataset = dataset["validation"]

# splitがない場合は自分で分割
split = dataset["train"].train_test_split(test_size=0.1, seed=42)
train_dataset = split["train"]
val_dataset = split["test"]

# さらにtest分割
split2 = val_dataset.train_test_split(test_size=0.5, seed=42)
val_dataset = split2["train"]
test_dataset = split2["test"]
```

### データセットの前処理・変換

```python
# map で変換（バッチ処理可能）
def preprocess(examples):
    examples["query"] = [q.strip().lower() for q in examples["query"]]
    return examples

dataset = dataset.map(preprocess, batched=True, batch_size=1000)

# カラム名の変更
dataset = dataset.rename_column("question", "query")
dataset = dataset.rename_column("context", "positive")

# カラムの削除
dataset = dataset.remove_columns(["id", "metadata"])
```

## テキスト前処理

### 基本的な前処理

```python
import re
import unicodedata

def clean_text(text: str) -> str:
    """検索モデル訓練用のテキスト前処理"""
    # Unicode正規化
    text = unicodedata.normalize("NFKC", text)
    # 過剰な空白の正規化
    text = re.sub(r"\s+", " ", text).strip()
    # 制御文字の除去
    text = "".join(c for c in text if unicodedata.category(c) != "Cc" or c in "\n\t")
    return text
```

### 前処理の注意点

```
やるべきこと:
  - Unicode正規化（NFKC推奨）
  - 過剰な空白・改行の正規化
  - 制御文字の除去
  - 極端に短い/長いテキストのフィルタリング

やるべきでないこと:
  - ストップワード除去（BERTベースモデルはストップワードも活用する）
  - ステミング/レンマタイゼーション（サブワードトークナイザが処理する）
  - 過度な小文字化（固有名詞の情報が失われる）
  - HTMLタグ除去後の品質チェックなし
```

### 長さのフィルタリング

```python
def filter_by_length(dataset, min_len=10, max_len=512):
    """トークナイザのmax_lengthではなく文字数ベースでフィルタ"""
    return dataset.filter(
        lambda x: min_len <= len(x["query"]) and min_len <= len(x["positive"]),
    )

# 長さの分布を確認（サンプリングで確認し、全件展開を避ける）
import numpy as np

sample_size = min(10000, len(dataset))  # 最大1万件でサンプリング
indices = np.random.choice(len(dataset), sample_size, replace=False)
lengths = [len(dataset[int(i)]["query"]) for i in indices]
print(f"Sample size: {sample_size}")
print(f"Mean: {np.mean(lengths):.0f}, Median: {np.median(lengths):.0f}")
print(f"P95: {np.percentile(lengths, 95):.0f}, Max: {max(lengths)}")
```

## ネガティブサンプリング

### Random Negative

```python
import random

def add_random_negatives(dataset, corpus, n_negatives=1, seed=42):
    """コーパスからランダムにネガティブサンプルを選択

    注意: n_negatives はコーパスサイズ未満であること。
    コーパスが小さい場合は無限ループになるリスクがある。
    """
    assert n_negatives < len(corpus), (
        f"n_negatives ({n_negatives}) must be < corpus size ({len(corpus)})"
    )
    rng = random.Random(seed)
    max_attempts = n_negatives * 10  # 無限ループ防止

    def add_negatives(example):
        positives = {example["positive"]}
        negatives = []
        attempts = 0
        while len(negatives) < n_negatives and attempts < max_attempts:
            neg = rng.choice(corpus)
            attempts += 1
            if neg not in positives:
                negatives.append(neg)
        if len(negatives) < n_negatives:
            print(f"Warning: only {len(negatives)}/{n_negatives} negatives found")
        example["negatives"] = negatives
        return example

    return dataset.map(add_negatives)
```

特性:
```
利点: 実装が簡単、計算コスト低い
欠点: 簡単すぎるネガティブが多く、学習効率が低い
適用場面: 初期実験、ベースライン構築
```

### Hard Negative Mining

```python
def mine_hard_negatives_bm25(queries, corpus, n_negatives=5):
    """BM25でhard negativeを取得

    注意: tokenized_corpus + BM25インデックスでコーパスの2-3倍のRAMを消費する。
    100万文書超のコーパスでは数GBのRAMが必要。事前に見積もること。
    """
    from rank_bm25 import BM25Okapi

    print(f"BM25 index construction: {len(corpus)} docs "
          f"(estimated RAM: ~{len(corpus) * 500 / 1e9:.1f} GB)")

    tokenized_corpus = [doc.split() for doc in corpus]
    bm25 = BM25Okapi(tokenized_corpus)

    hard_negatives = {}
    for query, positive in tqdm(queries, desc="Mining hard negatives (BM25)"):
        scores = bm25.get_scores(query.split())
        # 上位 n_negatives * 2 件のみソート（全件ソート O(n log n) を回避）
        top_k = min(n_negatives * 2 + 10, len(corpus))
        top_indices = np.argpartition(scores, -top_k)[-top_k:]
        top_indices = top_indices[np.argsort(scores[top_indices])[::-1]]
        negatives = []
        for idx in top_indices:
            if corpus[idx] != positive and len(negatives) < n_negatives:
                negatives.append(corpus[idx])
        hard_negatives[query] = negatives

    return hard_negatives


def mine_hard_negatives_model(queries, corpus, model, n_negatives=5, batch_size=256):
    """既存の検索モデルでhard negativeを取得

    重要: コーパスの埋め込みは CPU 上に保持する（GPU VRAM 枯渇防止）。
    100万文書 x 768次元 x fp32 = 約3GB の RAM が必要。
    大規模コーパス（100万件超）では FAISS の使用を推奨。
    """
    import numpy as np

    print(f"Encoding corpus: {len(corpus)} docs "
          f"(estimated RAM for embeddings: ~{len(corpus) * 768 * 4 / 1e9:.1f} GB)")

    # コーパスのエンコード（CPU に保持してVRAM枯渇を防止）
    corpus_embeddings = model.encode(
        corpus,
        show_progress_bar=True,
        batch_size=batch_size,
        convert_to_numpy=True,  # GPU tensor ではなく numpy array を返す
    )

    hard_negatives = {}
    for query, positive in tqdm(queries, desc="Mining hard negatives (model)"):
        query_embedding = model.encode(query, convert_to_numpy=True)
        # numpy でコサイン類似度計算（CPU上）
        scores = np.dot(corpus_embeddings, query_embedding) / (
            np.linalg.norm(corpus_embeddings, axis=1) * np.linalg.norm(query_embedding)
        )
        # 上位候補のみ取得（全件ソートを回避）
        top_k = min(n_negatives * 2 + 10, len(corpus))
        top_indices = np.argpartition(scores, -top_k)[-top_k:]
        top_indices = top_indices[np.argsort(scores[top_indices])[::-1]]
        negatives = []
        for idx in top_indices:
            if corpus[idx] != positive and len(negatives) < n_negatives:
                negatives.append(corpus[idx])
        hard_negatives[query] = negatives

    return hard_negatives
```

> **大規模コーパス（100万件超）**: 上記のナイーブな全件比較は O(queries x corpus) で非効率。FAISS を使えば ANN (Approximate Nearest Neighbor) で O(queries x log(corpus)) に削減できる。`faiss.IndexFlatIP` や `faiss.IndexIVFFlat` の使用を検討すること。

特性:
```
利点: モデルが間違えやすい例を学習でき、学習効率が高い
欠点: 計算コスト高い、false negativeのリスク
適用場面: 本番訓練、精度を追求する場面
注意: 正解文書と非常に類似した文書がnegativeになる「false negative」問題に注意
```

### In-Batch Negative

```python
# In-Batch Negative はバッチ構築方法で実現
# 同じバッチ内の他のクエリの正例をネガティブとして使用

# sentence-transformers の MultipleNegativesRankingLoss が自動的に行う
# → バッチサイズが大きいほどネガティブ数が増え、性能向上

# 実効ネガティブ数 = batch_size - 1
# → バッチサイズ 64 の場合、各クエリに 63 個のネガティブ
```

特性:
```
利点: 追加の計算コストなし、GPU効率良い、大バッチで高性能
欠点: バッチ内にたまたま関連文書があるとfalse negativeになる
適用場面: Bi-Encoder訓練の標準手法
重要: バッチサイズを可能な限り大きくすることが性能に直結
```

### ネガティブサンプリング戦略の選択

```
初期実験（ベースライン構築）
  → In-Batch Negative（MultipleNegativesRankingLoss）

精度改善フェーズ
  → Hard Negative Mining（BM25ベース）+ In-Batch Negative

最終チューニング
  → Hard Negative Mining（既存モデルベース）+ In-Batch Negative

ドメイン特化
  → ドメイン内のhard negativeを重点的に収集
```

## DataLoader設計

### Dynamic Padding（推奨）

```python
from torch.utils.data import DataLoader

def collate_fn(batch):
    """バッチ内の最大長に合わせてパディング"""
    queries = [item["query"] for item in batch]
    positives = [item["positive"] for item in batch]

    # トークナイザでバッチエンコード（dynamic padding）
    query_encodings = tokenizer(
        queries,
        padding=True,       # バッチ内最大長にパディング
        truncation=True,
        max_length=max_length,
        return_tensors="pt",
    )
    positive_encodings = tokenizer(
        positives,
        padding=True,
        truncation=True,
        max_length=max_length,
        return_tensors="pt",
    )

    return {
        "query": query_encodings,
        "positive": positive_encodings,
    }

dataloader = DataLoader(
    dataset,
    batch_size=batch_size,
    shuffle=True,
    collate_fn=collate_fn,
    num_workers=4,
    pin_memory=True,
    drop_last=True,  # 最後の不完全バッチを除外（バッチ正規化の安定性）
)
```

### Triplet DataLoader

```python
def triplet_collate_fn(batch):
    """Triplet形式のバッチ構築"""
    anchors = [item["anchor"] for item in batch]
    positives = [item["positive"] for item in batch]
    negatives = [item["negative"] for item in batch]

    anchor_enc = tokenizer(anchors, padding=True, truncation=True,
                           max_length=max_length, return_tensors="pt")
    positive_enc = tokenizer(positives, padding=True, truncation=True,
                             max_length=max_length, return_tensors="pt")
    negative_enc = tokenizer(negatives, padding=True, truncation=True,
                             max_length=max_length, return_tensors="pt")

    return {
        "anchor": anchor_enc,
        "positive": positive_enc,
        "negative": negative_enc,
    }
```

### DataLoaderパラメータガイド

```python
DataLoader(
    dataset,
    batch_size=64,          # GPU VRAMに応じて調整（後述の目安表参照）
    shuffle=True,           # 訓練時はTrue、評価時はFalse
    num_workers=4,          # CPUコア数の半分が目安（I/Oバウンドの場合増やす）
    pin_memory=True,        # GPU使用時はTrue（CPU→GPU転送を高速化）
    drop_last=True,         # 訓練時: True（不完全バッチ除外）
    prefetch_factor=2,      # 先読みバッチ数（デフォルト2で十分）
    persistent_workers=True, # ワーカープロセスを使い回す（初期化コスト削減）
)
```

### Sampler の活用

```python
from torch.utils.data import RandomSampler, SequentialSampler

# 再現性のためにseed付きSamplerを使用
train_sampler = RandomSampler(dataset, generator=torch.Generator().manual_seed(42))
eval_sampler = SequentialSampler(dataset)

train_loader = DataLoader(dataset, batch_size=64, sampler=train_sampler)
eval_loader = DataLoader(dataset, batch_size=128, sampler=eval_sampler)
```

## GPU VRAM別バッチサイズ目安

### Bi-Encoder（base モデル ~110M params）

| GPU | VRAM | max_length=128 | max_length=256 | max_length=512 |
|-----|------|----------------|----------------|----------------|
| RTX 3060 | 12GB | 32-64 | 16-32 | 8-16 |
| RTX 3090 | 24GB | 64-128 | 32-64 | 16-32 |
| RTX 4090 | 24GB | 64-128 | 32-64 | 16-32 |
| A100 40GB | 40GB | 128-256 | 64-128 | 32-64 |
| A100 80GB | 80GB | 256-512 | 128-256 | 64-128 |
| H100 | 80GB | 256-512+ | 128-256+ | 64-128+ |

### Bi-Encoder（large モデル ~335M params）

| GPU | VRAM | max_length=128 | max_length=256 | max_length=512 |
|-----|------|----------------|----------------|----------------|
| RTX 3090 | 24GB | 32-64 | 16-32 | 8-16 |
| A100 40GB | 40GB | 64-128 | 32-64 | 16-32 |
| A100 80GB | 80GB | 128-256 | 64-128 | 32-64 |

### Cross-Encoder（ペア入力のため2倍のメモリ）

```
Cross-Encoder は query + document を連結して入力するため、
同等のバッチサイズでも Bi-Encoder の約2倍の VRAM を消費する。
上記テーブルのバッチサイズを半分にして見積もること。
```

### 注意事項

```
- fp16/bf16 使用時の目安（fp32の場合は半分に）
- gradient accumulation で実効バッチサイズを拡大可能
- 実際の使用量はモデル構造・入力長の分布で変動
- OOMが発生したらバッチサイズを半分にして再試行
- torch.cuda.empty_cache() は根本解決にならない
```

## データ品質チェックリスト

```
データ読み込み:
  - [ ] データ形式（JSON/CSV/Parquet）が正しく読み込まれている
  - [ ] カラム名が期待通りである
  - [ ] 欠損値・空文字列がない（またはフィルタ済み）
  - [ ] データ件数が想定通りである

テキスト品質:
  - [ ] Unicode正規化が適用されている
  - [ ] HTMLタグ・特殊文字が適切に処理されている
  - [ ] 極端に短い/長いテキストがフィルタされている
  - [ ] 重複データが除去されている

ネガティブサンプリング:
  - [ ] ネガティブが正例と重複していない
  - [ ] hard negative の品質を目視で確認した（10件以上）
  - [ ] false negative（実際には関連するネガティブ）の割合が許容範囲内

DataLoader:
  - [ ] バッチサイズがGPU VRAMに収まる
  - [ ] shuffle が訓練時にTrueになっている
  - [ ] collate_fn でdynamic paddingが行われている
  - [ ] 1バッチの取り出しテストが成功している
```
