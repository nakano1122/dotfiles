# アンチパターン集

スキル作成でよくある問題パターンと改善例。

## 目次

- [致命的アンチパターン](#致命的アンチパターン)
- [構造的アンチパターン](#構造的アンチパターン)
- [description アンチパターン](#description-アンチパターン)
- [本文アンチパターン](#本文アンチパターン)
- [references アンチパターン](#references-アンチパターン)

## 致命的アンチパターン

### AP-01: description なし

description がないとスキルが発火しない。

```yaml
# Bad
---
name: my-skill
---

# Good
---
name: my-skill
description: 〜の実装ガイド。〜をカバー。〜時に使用。
---
```

### AP-02: name 形式違反

name に大文字・アンダースコア・スペースを使用。

```yaml
# Bad
name: mySkill
name: my_skill
name: My Skill
name: -my-skill
name: my--skill

# Good
name: my-skill
```

## 構造的アンチパターン

### AP-03: 不要な補助ファイルの作成

スキルに不要なドキュメントを含める。

```
# Bad
my-skill/
├── SKILL.md
├── README.md          ← 不要
├── CHANGELOG.md       ← 不要
├── INSTALLATION_GUIDE.md ← 不要
└── references/

# Good
my-skill/
├── SKILL.md
└── references/
    └── detail.md
```

### AP-04: SKILL.md の肥大化

すべての情報を SKILL.md に詰め込み、500行を超える。

```
# Bad: SKILL.md が 800行
SKILL.md に全パターン・全例・全リファレンスを記載

# Good: SKILL.md ~200行 + references/ で補完
SKILL.md: ワークフロー + 概要 + チェックリスト + リンク
references/patterns.md: 詳細パターン集
references/examples.md: 具体例集
```

## description アンチパターン

### AP-05: トリガー条件なし（WHEN なし）

機能説明のみで、いつ使うかが不明。

```yaml
# Bad
description: APIの設計ガイド。

# Good
description: API の設計・実装ガイド。レイヤー構造、エンドポイント設計、エラーレスポンス設計をカバー。新規 API やドメインモデル設計時に使用。
```

### AP-06: description が長すぎる

1024文字を超える、または冗長な説明。

```yaml
# Bad
description: >
  このスキルは、ユーザーがAPIを設計する際に...（延々と続く説明）...
  さらに、このスキルは...（1024文字超）

# Good
description: API 設計ガイド（フレームワーク非依存）。レイヤー構造、Entity/Repository/UseCase パターン、エラーレスポンス設計をカバー。新規 API 設計時に使用。
```

### AP-07: body と description の重複

description に書いた内容を body の冒頭で繰り返す。

```markdown
<!-- Bad: body 冒頭 -->
# API 設計ガイド

## このスキルについて
DDD + Clean Architecture に基づく API 設計ガイドです。
レイヤー構造、Entity/Repository パターンをカバーします。
← description と同じ内容

## いつ使うか
新規 API 設計時に使用してください。
← description に書くべき内容

<!-- Good: body 冒頭 -->
# API 設計ガイド

DDD + Clean Architecture に基づくフレームワーク非依存の設計ガイド。

## レイヤー構造
← すぐに本題に入る
```

## 本文アンチパターン

### AP-08: TODO / FIXME の残存

テンプレートの未編集箇所が残っている。

```markdown
<!-- Bad -->
## セクション名
TODO: ここに内容を記載

<!-- Good -->
## セクション名
具体的な内容が記載されている
```

### AP-09: body 内の「When to Use」セクション

body にトリガー条件を記載。body はスキル発火後にしか読まれないため無意味。

```markdown
<!-- Bad -->
## When to Use This Skill
- APIを設計するとき
- エンドポイントを追加するとき
← body に書いても発火判定に使われない

<!-- Good -->
description にトリガー条件を集約:
description: ...〜時に使用。
```

### AP-10: references/ へのリンクなし

references/ にファイルがあるのに SKILL.md からリンクがない。

```markdown
<!-- Bad -->
## 詳細
パターンの詳細は references ディレクトリを参照してください。
← どのファイルを読むべきか不明

<!-- Good -->
## リファレンス
- [references/patterns.md](references/patterns.md) - 実装パターン詳細
- [references/examples.md](references/examples.md) - 具体例集
← ファイル名と用途を明記
```

### AP-11: 言語の不統一

日本語と英語が混在している（技術用語を除く）。

```markdown
<!-- Bad -->
## Overview
このスキルはAPI設計のガイドです。
### Best Practices
以下のベストプラクティスに従ってください。

<!-- Good: 日本語で統一 -->
## 概要
このスキルはAPI設計のガイド。
### ベストプラクティス
以下に従う。
```

## references アンチパターン

### AP-12: ネスト構造

references/ 内にサブディレクトリを作成。

```
# Bad
references/
├── patterns/
│   ├── creation.md
│   └── structural.md
└── examples/
    └── api.md

# Good
references/
├── patterns.md
└── examples.md
```

### AP-13: SKILL.md との内容重複

同じ情報が SKILL.md と references/ の両方に存在。

```
# Bad
SKILL.md: エラーコード一覧テーブル（30行）
references/errors.md: 同じエラーコード一覧テーブル + 詳細

# Good
SKILL.md: 主要エラーコード3つのみ概要表示
references/errors.md: 全エラーコード一覧 + 詳細
← 重複なく、粒度で分離
```

### AP-14: 過度なファイル分割

細かすぎる分割で references/ のファイル数が多すぎる。

```
# Bad
references/
├── naming.md        (20行)
├── structure.md     (15行)
├── validation.md    (25行)
├── errors.md        (10行)
├── patterns.md      (30行)
├── examples.md      (20行)
└── tips.md          (15行)

# Good
references/
├── design-guide.md  (100行: naming + structure + validation)
└── patterns.md      (50行: patterns + examples)
← 関連する内容をまとめる
```

### AP-15: TOC なし（長いファイル）

100行超のファイルに目次がなく、内容の全体像が把握しにくい。

```markdown
<!-- Bad: 150行のファイル冒頭 -->
# パターン集

## パターン1
...

<!-- Good: 150行のファイル冒頭 -->
# パターン集

## 目次

- [パターン1](#パターン1)
- [パターン2](#パターン2)
- [パターン3](#パターン3)

## パターン1
...
```
