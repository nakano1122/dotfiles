# Web調査プロトコル

HuggingFace エコシステムの変化に対応するための Web調査手順。

## 目次

1. [調査フロー](#調査フロー)
2. [URL辞書](#url辞書)
3. [WebSearch検索クエリテンプレート](#websearch検索クエリテンプレート)
4. [WebFetch使用手順](#webfetch使用手順)
5. [取得コードの検証手順](#取得コードの検証手順)
6. [フォールバック戦略](#フォールバック戦略)
7. [バージョン互換性マトリクス](#バージョン互換性マトリクス)

## 調査フロー

```
1. 既存コードベースの依存バージョンを確認
   → pip list | grep -E "sentence-transformers|transformers|torch"
2. アーキテクチャに応じたURL辞書からドキュメントを取得
3. WebSearch で最新チュートリアル・ブログを検索
4. WebFetch で公式ドキュメントの具体的コードを取得
5. 取得コードのバージョン互換性を検証
6. 不整合時はフォールバック戦略を実行
```

## URL辞書

### sentence-transformers

| リソース | URL | 用途 |
|---------|-----|------|
| 公式ドキュメント | https://www.sbert.net/ | API全体像 |
| Training Overview | https://www.sbert.net/docs/sentence_transformer/training_overview.html | 訓練ガイド |
| Loss Functions | https://www.sbert.net/docs/sentence_transformer/loss_overview.html | 損失関数一覧 |
| Pre-trained Models | https://www.sbert.net/docs/sentence_transformer/pretrained_models.html | モデル一覧 |
| GitHub | https://github.com/UKPLab/sentence-transformers | ソースコード |
| GitHub Examples | https://github.com/UKPLab/sentence-transformers/tree/master/examples | 公式サンプル |
| PyPI | https://pypi.org/project/sentence-transformers/ | バージョン履歴 |
| Changelog | https://github.com/UKPLab/sentence-transformers/blob/master/CHANGELOG.md | 変更履歴 |

### HuggingFace Transformers

| リソース | URL | 用途 |
|---------|-----|------|
| 公式ドキュメント | https://huggingface.co/docs/transformers/ | API全体像 |
| AutoModel | https://huggingface.co/docs/transformers/model_doc/auto | AutoModel系クラス |
| Trainer | https://huggingface.co/docs/transformers/main_classes/trainer | Trainerクラス |
| PEFT | https://huggingface.co/docs/peft/ | Parameter-Efficient Fine-Tuning |

### HuggingFace Hub

| リソース | URL | 用途 |
|---------|-----|------|
| Model Hub | https://huggingface.co/models | モデル検索 |
| Datasets Hub | https://huggingface.co/datasets | データセット検索 |
| Hub API | https://huggingface.co/docs/huggingface_hub/ | Hub操作API |

### ColBERT / SPLADE

| リソース | URL | 用途 |
|---------|-----|------|
| ColBERT GitHub | https://github.com/stanford-futuredata/ColBERT | ColBERT実装 |
| ColBERTv2 Paper | https://arxiv.org/abs/2112.01488 | ColBERTv2論文 |
| RAGatouille | https://github.com/bclavie/RAGatouille | ColBERT簡易ラッパー |
| SPLADE GitHub | https://github.com/naver/splade | SPLADE実装 |

### PyTorch

| リソース | URL | 用途 |
|---------|-----|------|
| DataLoader | https://pytorch.org/docs/stable/data.html | DataLoader API |
| AMP | https://pytorch.org/docs/stable/amp.html | Mixed Precision |
| DDP | https://pytorch.org/docs/stable/notes/ddp.html | 分散訓練 |

## WebSearch検索クエリテンプレート

### アーキテクチャ別

```
Bi-Encoder:
  "sentence-transformers bi-encoder training example {year}"
  "sentence-transformers SentenceTransformer fine-tune {year}"
  "sentence-transformers MultipleNegativesRankingLoss example {year}"

Cross-Encoder:
  "sentence-transformers CrossEncoder training {year}"
  "cross-encoder reranking huggingface tutorial {year}"
  "sentence-transformers cross-encoder fine-tuning {year}"

ColBERT:
  "ColBERT v2 training tutorial {year}"
  "RAGatouille ColBERT training {year}"
  "ColBERT fine-tuning huggingface {year}"
  "sentence-transformers ColBERT {year}"

SPLADE:
  "SPLADE training huggingface {year}"
  "SPLADE v2 fine-tuning tutorial {year}"
  "sparse retrieval model training {year}"
```

### 損失関数別

```
"sentence-transformers {loss_class_name} example {year}"
"sentence-transformers {loss_class_name} usage guide {year}"
"{loss_class_name} training data format sentence-transformers {year}"
```

### データセット別

```
"huggingface datasets {dataset_name} sentence-transformers {year}"
"information retrieval dataset {domain} huggingface {year}"
"BEIR benchmark {language} dataset {year}"
```

### トラブルシューティング

```
"sentence-transformers {error_message} {year}"
"sentence-transformers {version} breaking changes"
"sentence-transformers migration guide v{old} to v{new}"
```

## WebFetch使用手順

### ステップ 1: ドキュメントページの取得

```
WebFetch で以下を優先的に取得:
1. sentence-transformers Training Overview ページ
   → 訓練パイプラインの全体像を把握
2. 使用する損失関数のドキュメントページ
   → import パス、引数、データ形式を確認
3. GitHub の examples/ 内の該当サンプル
   → 実動するコード例を取得
```

### ステップ 2: コードの抽出

```
WebFetch 結果から抽出すべき情報:
- import 文（正確なモジュールパス）
- クラス/関数のシグネチャ（引数名・型・デフォルト値）
- データ形式の要件（InputExample の構造等）
- 訓練ループの接続方法（model.fit() or カスタムループ）
```

### ステップ 3: バージョン確認

```
取得したコードについて確認:
- 対象の sentence-transformers バージョン
- Python バージョン要件
- PyTorch バージョン要件
- transformers バージョン要件
```

## 取得コードの検証手順

### 互換性チェック

```
1. import文のテスト
   → 取得した import を実際に実行して ImportError がないか確認

2. クラスシグネチャの確認
   → help(ClassName) or ClassName.__init__.__doc__ で引数を確認

3. 小規模テスト実行
   → ダミーデータ（10件程度）で訓練ループが回ることを確認

4. 警告メッセージの確認
   → DeprecationWarning, FutureWarning を見逃さない
```

### チェックポイント

```
□ import が通る
□ モデルのインスタンス化が成功する
□ データローダーがバッチを返す
□ forward pass が通る
□ loss.backward() が通る
□ 10ステップの訓練が完走する
□ 保存/ロードが成功する
```

## フォールバック戦略

### 公式ドキュメントが見つからない場合

```
優先順位:
1. GitHub の examples/ ディレクトリを直接参照
2. HuggingFace のモデルカード内の使用例を参照
3. GitHub Issues/Discussions で類似事例を検索
4. 学術論文の公式リポジトリを参照
5. ブログ記事・チュートリアル（日付が新しいもの優先）
```

### APIが変更されていた場合

```
1. Changelog/Migration Guide を確認
   → 新旧APIの対応表を探す
2. 旧API → 新API への書き換え方法を確認
3. 新APIが不安定な場合:
   → requirements.txt でバージョンを固定
   → 旧APIを使用しつつ TODO コメントで移行予定を記録
```

### Web取得が失敗した場合

```
1. URL変更の可能性 → WebSearch で新URLを検索
2. ネットワーク問題 → リトライ（最大3回）
3. ページ構造変更 → 別のソース（GitHub raw, PyPI）を試行
4. 最終手段 → pip show で installed package のソースを直接読む
```

## バージョン互換性マトリクス

### 確認すべき依存関係

```
sentence-transformers ←→ transformers
sentence-transformers ←→ torch
transformers ←→ torch
torch ←→ CUDA
```

### バージョン確認コマンド

```bash
# 現在のバージョン確認
pip list | grep -E "sentence-transformers|transformers|torch|tokenizers"

# CUDA バージョン確認
python -c "import torch; print(torch.version.cuda)"
python -c "import torch; print(torch.cuda.is_available())"

# GPU確認
nvidia-smi
```

### 互換性問題の兆候

```
- ImportError: cannot import name 'X' from 'Y'
  → バージョン不一致の可能性大
- DeprecationWarning: 'X' is deprecated
  → 次期バージョンで削除予定、移行を検討
- TypeError: __init__() got an unexpected keyword argument
  → API引数が変更された
- AttributeError: 'X' object has no attribute 'Y'
  → クラス構造が変更された
```

### 調査結果の記録テンプレート

```
## Web調査結果 - {日付}

### 環境
- sentence-transformers: {version}
- transformers: {version}
- torch: {version}
- CUDA: {version}

### 確認したリソース
1. {URL} - {取得した情報の要約}
2. {URL} - {取得した情報の要約}

### 使用するAPI
- モデルクラス: {class_name} from {module}
- 損失関数: {loss_name} from {module}
- データ形式: {format_description}

### 注意点
- {互換性に関する注意}
- {非推奨APIに関する注意}
```
