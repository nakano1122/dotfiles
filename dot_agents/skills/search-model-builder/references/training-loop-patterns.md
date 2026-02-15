# 訓練ループ・効率化・tqdm

検索モデル訓練ループの設計パターンと計算効率化テクニック。

## 目次

1. [完全な訓練ループテンプレート](#完全な訓練ループテンプレート)
2. [Optimizer・Scheduler設定](#optimizerscheduler設定)
3. [Mixed Precision（fp16/bf16）](#mixed-precisionfp16bf16)
4. [Gradient Accumulation](#gradient-accumulation)
5. [Gradient Checkpointing](#gradient-checkpointing)
6. [tqdm統合パターン](#tqdm統合パターン)
7. [チェックポイント保存](#チェックポイント保存)
8. [早期停止](#早期停止)
9. [再現性確保](#再現性確保)
10. [マルチGPU概要](#マルチgpu概要)

## 完全な訓練ループテンプレート

> **注意**: モデルクラス・損失関数の具体的なimportパスは Web調査で最新を確認すること。
> 以下はPyTorchベースの汎用テンプレート。

```python
import os
import random
import numpy as np
import torch
from torch.utils.data import DataLoader
from torch.cuda.amp import GradScaler, autocast
from tqdm import tqdm
import wandb

# ===== 再現性 =====
def set_seed(seed: int = 42):
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark = False

# ===== 訓練関数 =====
def train(
    model,
    train_dataloader: DataLoader,
    val_dataloader: DataLoader,
    optimizer,
    scheduler,
    num_epochs: int,
    device: torch.device,
    output_dir: str,
    use_amp: bool = True,
    amp_dtype: torch.dtype = torch.float16,
    gradient_accumulation_steps: int = 1,
    max_grad_norm: float = 1.0,
    eval_steps: int | None = None,
    patience: int | None = None,
    log_steps: int = 10,
):
    """汎用的な訓練ループ"""
    model.to(device)
    scaler = GradScaler(enabled=use_amp)
    best_metric = float("-inf")
    patience_counter = 0
    global_step = 0

    for epoch in range(num_epochs):
        model.train()
        epoch_loss = 0.0

        progress_bar = tqdm(
            train_dataloader,
            desc=f"Epoch {epoch + 1}/{num_epochs}",
            leave=True,
        )

        for step, batch in enumerate(progress_bar):
            # Forward pass
            with autocast(device_type="cuda", dtype=amp_dtype, enabled=use_amp):
                loss = compute_loss(model, batch, device)
                loss = loss / gradient_accumulation_steps

            # Backward pass
            scaler.scale(loss).backward()

            # Gradient accumulation
            if (step + 1) % gradient_accumulation_steps == 0:
                scaler.unscale_(optimizer)
                torch.nn.utils.clip_grad_norm_(model.parameters(), max_grad_norm)
                scaler.step(optimizer)
                scaler.update()
                optimizer.zero_grad()
                scheduler.step()
                global_step += 1

                # ログ
                if global_step % log_steps == 0:
                    current_lr = scheduler.get_last_lr()[0]
                    progress_bar.set_postfix({
                        "loss": f"{loss.item() * gradient_accumulation_steps:.4f}",
                        "lr": f"{current_lr:.2e}",
                    })
                    wandb.log({
                        "train/loss": loss.item() * gradient_accumulation_steps,
                        "train/lr": current_lr,
                        "train/global_step": global_step,
                    })

                # ステップ単位の評価
                if eval_steps and global_step % eval_steps == 0:
                    metrics = evaluate(model, val_dataloader, device, use_amp, amp_dtype)
                    tqdm.write(f"Step {global_step}: {metrics}")
                    wandb.log({f"val/{k}": v for k, v in metrics.items()})
                    model.train()

            epoch_loss += loss.item() * gradient_accumulation_steps

        # エポック終了時の評価
        avg_loss = epoch_loss / len(train_dataloader)
        metrics = evaluate(model, val_dataloader, device, use_amp, amp_dtype)
        tqdm.write(f"Epoch {epoch + 1} - Loss: {avg_loss:.4f} - Val: {metrics}")

        wandb.log({
            "epoch": epoch + 1,
            "train/epoch_loss": avg_loss,
            **{f"val/{k}": v for k, v in metrics.items()},
        })

        # チェックポイント保存
        primary_metric = metrics.get("mrr@10", metrics.get("ndcg@10", 0))
        if primary_metric > best_metric:
            best_metric = primary_metric
            save_checkpoint(model, optimizer, scheduler, epoch, output_dir, "best")
            patience_counter = 0
        else:
            patience_counter += 1

        save_checkpoint(model, optimizer, scheduler, epoch, output_dir, f"epoch_{epoch + 1}")
        cleanup_checkpoints(output_dir, keep_last_n=3)  # ディスク枯渇防止

        # 早期停止
        if patience and patience_counter >= patience:
            tqdm.write(f"Early stopping at epoch {epoch + 1}")
            break

    return model


def compute_loss(model, batch, device):
    """損失計算（モデル・損失関数に応じてカスタマイズ）"""
    # ここはモデル・損失関数に応じて実装する
    # Web調査で取得した最新APIに合わせること
    raise NotImplementedError("Implement based on your model and loss function")


def evaluate(model, dataloader, device, use_amp=True, amp_dtype=torch.float16):
    """評価ループ"""
    model.eval()
    all_scores = []

    with torch.no_grad():
        for batch in tqdm(dataloader, desc="Evaluating", leave=False):
            with autocast(device_type="cuda", dtype=amp_dtype, enabled=use_amp):
                # 評価ロジック（モデルに応じてカスタマイズ）
                pass

    # MRR@k, NDCG@k 等を計算して返す
    metrics = compute_metrics(all_scores)
    return metrics
```

## Optimizer・Scheduler設定

### AdamW（推奨デフォルト）

```python
from torch.optim import AdamW

optimizer = AdamW(
    model.parameters(),
    lr=2e-5,              # BERTベースの典型的な学習率
    weight_decay=0.01,    # L2正則化
    betas=(0.9, 0.999),
    eps=1e-8,
)
```

### 層別学習率（Discriminative Learning Rate）

```python
def get_optimizer_grouped_parameters(model, lr=2e-5, weight_decay=0.01):
    """BERTの層ごとに異なる学習率を設定"""
    no_decay = ["bias", "LayerNorm.weight"]

    # エンコーダ層の学習率を下位層ほど小さく
    optimizer_grouped_parameters = []

    # Embedding層（最も低い学習率）
    optimizer_grouped_parameters.append({
        "params": [p for n, p in model.named_parameters()
                   if "embeddings" in n and not any(nd in n for nd in no_decay)],
        "lr": lr * 0.1,
        "weight_decay": weight_decay,
    })

    # エンコーダ層（段階的に学習率を上げる）
    num_layers = 12  # base model
    for i in range(num_layers):
        layer_lr = lr * (0.95 ** (num_layers - i))
        optimizer_grouped_parameters.append({
            "params": [p for n, p in model.named_parameters()
                       if f"layer.{i}." in n and not any(nd in n for nd in no_decay)],
            "lr": layer_lr,
            "weight_decay": weight_decay,
        })

    # Pooler / Head（最も高い学習率）
    optimizer_grouped_parameters.append({
        "params": [p for n, p in model.named_parameters()
                   if "pooler" in n or "classifier" in n],
        "lr": lr,
        "weight_decay": weight_decay,
    })

    return optimizer_grouped_parameters
```

### Scheduler パターン

```python
from torch.optim.lr_scheduler import (
    LinearLR,
    CosineAnnealingLR,
    SequentialLR,
    OneCycleLR,
)
from transformers import get_linear_schedule_with_warmup

# パターン1: Linear warmup + linear decay（最も一般的）
total_steps = len(train_dataloader) * num_epochs // gradient_accumulation_steps
warmup_steps = int(total_steps * 0.1)  # 全体の10%

scheduler = get_linear_schedule_with_warmup(
    optimizer,
    num_warmup_steps=warmup_steps,
    num_training_steps=total_steps,
)

# パターン2: Linear warmup + cosine decay
warmup_scheduler = LinearLR(optimizer, start_factor=0.1, total_iters=warmup_steps)
cosine_scheduler = CosineAnnealingLR(optimizer, T_max=total_steps - warmup_steps)
scheduler = SequentialLR(optimizer, [warmup_scheduler, cosine_scheduler],
                          milestones=[warmup_steps])

# パターン3: OneCycleLR（warmup + annealing を一体化）
scheduler = OneCycleLR(
    optimizer,
    max_lr=2e-5,
    total_steps=total_steps,
    pct_start=0.1,  # warmup割合
    anneal_strategy="cos",
)
```

### Scheduler選択ガイド

```
Linear warmup + linear decay
  → 最も安定、初学者向け、sentence-transformersデフォルト

Linear warmup + cosine decay
  → 終盤の学習率の下がり方が緩やか、長い訓練に向く

OneCycleLR
  → 短い訓練で高速収束、学習率の範囲を事前に把握している場合
```

## Mixed Precision（fp16/bf16）

### fp16 と bf16 の使い分け

```
fp16 (float16):
  - NVIDIA Volta以降（V100, A100, RTX 20xx+）
  - ダイナミックレンジが狭い → loss scaling が必要
  - GradScaler で自動管理

bf16 (bfloat16):
  - NVIDIA Ampere以降（A100, RTX 30xx+）
  - ダイナミックレンジが広い → loss scaling 不要
  - 数値的に安定

選択基準:
  bf16対応GPU → bf16を使用（GradScalerは不要だが使っても害はない）
  bf16非対応GPU → fp16 + GradScaler
```

### 実装パターン

```python
from torch.cuda.amp import GradScaler, autocast

# bf16 の場合
use_amp = True
amp_dtype = torch.bfloat16
scaler = GradScaler(enabled=False)  # bf16ではscaling不要

# fp16 の場合
use_amp = True
amp_dtype = torch.float16
scaler = GradScaler(enabled=True)

# 訓練ループ内
with autocast(device_type="cuda", dtype=amp_dtype, enabled=use_amp):
    loss = compute_loss(model, batch, device)

scaler.scale(loss).backward()
scaler.unscale_(optimizer)
torch.nn.utils.clip_grad_norm_(model.parameters(), max_grad_norm)
scaler.step(optimizer)
scaler.update()
```

### GPU判定

```python
def get_amp_config():
    """GPUに応じたAMP設定を自動判定"""
    if not torch.cuda.is_available():
        return False, torch.float32

    capability = torch.cuda.get_device_capability()
    if capability >= (8, 0):  # Ampere以降
        return True, torch.bfloat16
    elif capability >= (7, 0):  # Volta以降
        return True, torch.float16
    else:
        return False, torch.float32
```

## Gradient Accumulation

### 仕組み

```
実効バッチサイズ = GPU上のバッチサイズ × accumulation_steps × GPU数

例: バッチサイズ16 × accumulation 4 = 実効バッチサイズ64
→ VRAM 不足で大きなバッチサイズが取れない場合に有用
→ 検索モデルでは大きなバッチサイズが性能に重要（in-batch negatives のため）
```

### 実装パターン

```python
gradient_accumulation_steps = 4

for step, batch in enumerate(train_dataloader):
    with autocast(device_type="cuda", dtype=amp_dtype, enabled=use_amp):
        loss = compute_loss(model, batch, device)
        loss = loss / gradient_accumulation_steps  # 勾配のスケーリング

    scaler.scale(loss).backward()

    if (step + 1) % gradient_accumulation_steps == 0:
        scaler.unscale_(optimizer)
        torch.nn.utils.clip_grad_norm_(model.parameters(), max_grad_norm)
        scaler.step(optimizer)
        scaler.update()
        optimizer.zero_grad()
        scheduler.step()
```

### 注意点

```
- loss を accumulation_steps で割る（勾配の平均を取るため）
- scheduler.step() は optimizer.step() と同じ頻度で呼ぶ
- ログの loss は accumulation_steps を掛けて元に戻す
- In-batch negatives は GPU 上のバッチサイズで決まる（accumulation では増えない）
  → in-batch negatives を増やしたい場合は GPU バッチサイズ自体を大きくする必要がある
```

## Gradient Checkpointing

### 概要

```
通常: 全中間活性化をメモリに保持 → 逆伝播で使用
チェックポイント: 一部の活性化のみ保持 → 逆伝播時に再計算

効果:
  - VRAM使用量: ~40-60% 削減
  - 計算時間: ~10-20% 増加
  - トレードオフ: メモリ vs 速度

推奨場面:
  - 大規模モデル（>300M パラメータ）
  - GPU VRAM が不足する場合
  - バッチサイズを大きくしたい場合
```

### 有効化方法

```python
# HuggingFace モデルの場合
model.gradient_checkpointing_enable()

# 訓練後は無効化（推論速度のため）
model.gradient_checkpointing_disable()
```

## tqdm統合パターン

### 基本的なエポック・ステップ進捗

```python
from tqdm import tqdm

# エポックレベルの進捗
for epoch in tqdm(range(num_epochs), desc="Training"):
    # ステップレベルの進捗
    for batch in tqdm(train_dataloader, desc=f"Epoch {epoch + 1}", leave=True):
        ...
```

### postfix でメトリクスをリアルタイム表示

```python
progress_bar = tqdm(train_dataloader, desc=f"Epoch {epoch + 1}")

for step, batch in enumerate(progress_bar):
    loss = train_step(batch)

    # postfix で loss と学習率を表示
    if step % log_steps == 0:
        progress_bar.set_postfix({
            "loss": f"{loss:.4f}",
            "lr": f"{scheduler.get_last_lr()[0]:.2e}",
        })

# 出力例: Epoch 1: 45%|████▌     | 450/1000 [02:15<02:45, 3.33it/s, loss=0.3421, lr=1.80e-05]
```

### ネストされた進捗バー

```python
# 外側: エポック / 内側: ステップ
epoch_bar = tqdm(range(num_epochs), desc="Training", position=0)
for epoch in epoch_bar:
    step_bar = tqdm(train_dataloader, desc=f"Epoch {epoch + 1}", position=1, leave=False)
    for batch in step_bar:
        loss = train_step(batch)
        step_bar.set_postfix(loss=f"{loss:.4f}")
    epoch_bar.set_postfix(val_mrr=f"{val_mrr:.4f}")
```

### tqdm.write でログ出力

```python
# 進捗バーを壊さずにテキストを出力
for epoch in range(num_epochs):
    for batch in tqdm(train_dataloader, desc=f"Epoch {epoch + 1}"):
        loss = train_step(batch)

    # エポック終了時の評価結果を出力
    metrics = evaluate(model, val_dataloader)
    tqdm.write(f"Epoch {epoch + 1} - Val MRR@10: {metrics['mrr@10']:.4f}")
    # ↑ print() ではなく tqdm.write() を使う
```

### 評価時の進捗バー

```python
def evaluate(model, dataloader):
    model.eval()
    all_predictions = []

    with torch.no_grad():
        for batch in tqdm(dataloader, desc="Evaluating", leave=False):
            # leave=False で評価完了後にバーを消す
            predictions = model(batch)
            all_predictions.append(predictions)

    return compute_metrics(all_predictions)
```

### エンコーディングの進捗バー

```python
import numpy as np

def encode_corpus(model, texts, batch_size=64):
    """大規模コーパスのエンコード進捗を表示

    重要: 埋め込みは CPU (numpy) に保持する。GPU tensor で蓄積すると
    大規模コーパスで VRAM が枯渇する。
    100万文書 x 768次元 x fp32 = 約3GB の RAM が必要。
    """
    all_embeddings = []

    for i in tqdm(range(0, len(texts), batch_size), desc="Encoding corpus"):
        batch = texts[i:i + batch_size]
        # convert_to_numpy=True で CPU に保持（VRAM 枯渇防止）
        embeddings = model.encode(batch, convert_to_numpy=True)
        all_embeddings.append(embeddings)

    return np.concatenate(all_embeddings, axis=0)
    # GPU tensor が必要な場合: torch.from_numpy(result).to(device)
    # ただし大規模コーパスでは FAISS 等を使い GPU 全転送を避ける
```

## チェックポイント保存

### 保存パターン

```python
def save_checkpoint(model, optimizer, scheduler, epoch, output_dir, tag):
    """訓練状態の完全な保存"""
    checkpoint_dir = os.path.join(output_dir, f"checkpoint-{tag}")
    os.makedirs(checkpoint_dir, exist_ok=True)

    # モデルの保存
    model.save_pretrained(checkpoint_dir)  # HuggingFaceモデルの場合
    # or torch.save(model.state_dict(), os.path.join(checkpoint_dir, "model.pt"))

    # 訓練状態の保存（訓練再開用）
    torch.save({
        "epoch": epoch,
        "optimizer_state_dict": optimizer.state_dict(),
        "scheduler_state_dict": scheduler.state_dict(),
    }, os.path.join(checkpoint_dir, "training_state.pt"))

    tqdm.write(f"Checkpoint saved: {checkpoint_dir}")
```

### 復元パターン

```python
def load_checkpoint(model, optimizer, scheduler, checkpoint_dir):
    """チェックポイントからの復元"""
    # モデルの復元
    model.load_state_dict(torch.load(os.path.join(checkpoint_dir, "model.pt")))

    # 訓練状態の復元
    state = torch.load(os.path.join(checkpoint_dir, "training_state.pt"))
    optimizer.load_state_dict(state["optimizer_state_dict"])
    scheduler.load_state_dict(state["scheduler_state_dict"])

    return state["epoch"]
```

### チェックポイント管理

```python
def cleanup_checkpoints(output_dir, keep_last_n=3):
    """古いチェックポイントを削除（ディスク節約）"""
    import glob
    import shutil

    checkpoints = sorted(
        glob.glob(os.path.join(output_dir, "checkpoint-epoch_*")),
        key=os.path.getmtime,
    )

    for checkpoint in checkpoints[:-keep_last_n]:
        shutil.rmtree(checkpoint)
        tqdm.write(f"Removed old checkpoint: {checkpoint}")
```

## 早期停止

```python
class EarlyStopping:
    """検証指標が改善しない場合に訓練を停止"""

    def __init__(self, patience: int = 5, min_delta: float = 0.0):
        self.patience = patience
        self.min_delta = min_delta
        self.counter = 0
        self.best_score = None
        self.should_stop = False

    def __call__(self, score: float) -> bool:
        if self.best_score is None:
            self.best_score = score
        elif score < self.best_score + self.min_delta:
            self.counter += 1
            if self.counter >= self.patience:
                self.should_stop = True
        else:
            self.best_score = score
            self.counter = 0

        return self.should_stop

# 使用例
early_stopping = EarlyStopping(patience=5)
for epoch in range(num_epochs):
    metrics = evaluate(model, val_dataloader)
    if early_stopping(metrics["mrr@10"]):
        tqdm.write(f"Early stopping at epoch {epoch + 1}")
        break
```

## 再現性確保

### シード固定

```python
import os
import random
import numpy as np
import torch

def set_seed(seed: int = 42):
    """全ての乱数シードを固定"""
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)
    os.environ["PYTHONHASHSEED"] = str(seed)

    # 決定論的アルゴリズムの使用（速度低下あり）
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark = False

    # PyTorch 2.0+
    # torch.use_deterministic_algorithms(True)

# 訓練開始前に呼び出す
set_seed(42)
```

### DataLoader の再現性

```python
# Worker のシード固定
def worker_init_fn(worker_id):
    np.random.seed(42 + worker_id)

dataloader = DataLoader(
    dataset,
    batch_size=64,
    shuffle=True,
    num_workers=4,
    worker_init_fn=worker_init_fn,
    generator=torch.Generator().manual_seed(42),
)
```

### 再現性チェックリスト

```
- [ ] set_seed() を訓練開始前に呼び出している
- [ ] DataLoader に generator と worker_init_fn を設定している
- [ ] 環境情報を記録している（GPU, CUDA, ライブラリバージョン）
- [ ] ハイパーパラメータを全て wandb.config に記録している
- [ ] requirements.txt / pyproject.toml でバージョンを固定している
```

## マルチGPU概要

### DataParallel（DP）vs DistributedDataParallel（DDP）

```
DataParallel (DP):
  - 1プロセス、複数GPU
  - 実装が簡単: model = nn.DataParallel(model)
  - GPU間通信がボトルネック
  - GPU0にメモリが集中する
  → 非推奨（レガシー）

DistributedDataParallel (DDP):
  - GPUごとに1プロセス
  - 通信効率が良い
  - メモリが均等に分散
  → 推奨

起動方法:
  torchrun --nproc_per_node=4 train.py
```

### DDP の基本設定

```python
import torch.distributed as dist
from torch.nn.parallel import DistributedDataParallel as DDP
from torch.utils.data.distributed import DistributedSampler

def setup_ddp():
    dist.init_process_group("nccl")
    local_rank = int(os.environ["LOCAL_RANK"])
    torch.cuda.set_device(local_rank)
    return local_rank

def cleanup_ddp():
    dist.destroy_process_group()

# 使用例
local_rank = setup_ddp()
device = torch.device(f"cuda:{local_rank}")

model = model.to(device)
model = DDP(model, device_ids=[local_rank])

train_sampler = DistributedSampler(train_dataset, shuffle=True)
train_dataloader = DataLoader(train_dataset, batch_size=64, sampler=train_sampler)

for epoch in range(num_epochs):
    train_sampler.set_epoch(epoch)  # シャッフルの再現性のため
    ...
```

### 注意事項

```
- マルチGPUでは実効バッチサイズ = バッチサイズ × GPU数
- in-batch negatives は各GPUのバッチ内でのみ生成される
  → GPU間の negatives 共有にはカスタム実装が必要
- ログ出力は rank 0 のプロセスのみで行う
  if dist.get_rank() == 0:
      wandb.log(...)
- モデル保存も rank 0 のみ
  if dist.get_rank() == 0:
      model.module.save_pretrained(...)
```
