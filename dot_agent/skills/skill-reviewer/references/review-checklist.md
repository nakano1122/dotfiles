# 詳細レビューチェックリスト

スキルレビューの全チェック項目と判定基準。

## 目次

- [フロントマター検証](#フロントマター検証)
- [SKILL.md 本文](#skillmd-本文)
- [references/ 構造](#references-構造)
- [ディレクトリ構造](#ディレクトリ構造)
- [description トリガー品質](#description-トリガー品質)

## フロントマター検証

### name ルール

| # | チェック項目 | 重要度 | 判定方法 |
|---|------------|--------|---------|
| FM-01 | `name` フィールドが存在する | Critical | フロントマター YAML に `name` キーがあること |
| FM-02 | 文字種が `^[a-z0-9-]+$` に合致 | Critical | 小文字英数字とハイフンのみ。大文字・アンダースコア・スペース不可 |
| FM-03 | 先頭/末尾がハイフンでない、連続ハイフンなし | Critical | `-skill`, `skill-`, `my--skill` はすべて不正 |
| FM-04 | 64文字以内 | Critical | `len(name) <= 64` |

### description ルール

| # | チェック項目 | 重要度 | 判定方法 |
|---|------------|--------|---------|
| FM-05 | `description` フィールドが存在する | Critical | フロントマター YAML に `description` キーがあること |
| FM-06 | 1024文字以内 | Critical | `len(description) <= 1024` |
| FM-07 | 山括弧 `<` `>` を含まない | Critical | HTML タグやプレースホルダーが混入していないこと |
| FM-08 | 空文字でない | Warning | description が空白のみ・空文字列でないこと |
| FM-09 | 機能 + トリガー条件の両方を含む | Suggestion | 「〜をカバー。〜時に使用。」のようなパターンが推奨 |

### フィールド制限

| # | チェック項目 | 重要度 | 判定方法 |
|---|------------|--------|---------|
| FM-10 | 許可フィールドのみ使用 | Critical | `name, description, license, allowed-tools, metadata` のみ許可。それ以外のキーがあれば不正 |

## SKILL.md 本文

| # | チェック項目 | 重要度 | 判定方法 |
|---|------------|--------|---------|
| BD-01 | 500行以内 | Warning | `wc -l SKILL.md` で確認（フロントマター含む） |
| BD-02 | 300行以内が理想 | Suggestion | 300行超は references/ への分離を検討 |
| BD-03 | TODO / FIXME / PLACEHOLDER が残存していない | Warning | テンプレートの未編集箇所が残っていないこと |
| BD-04 | body 内に「When to Use」セクションがない | Warning | トリガー情報は description に集約すべき。body は skill 発火後にのみ読まれるため |
| BD-05 | references/ 内ファイルへのリンクが本文に存在 | Warning | references/ にファイルがあるのにリンクがない場合、Claude がファイルの存在を認識できない |
| BD-06 | 見出し構造が論理的 | Suggestion | H1 が1つ、H2 以降で構造化されていること |
| BD-07 | 言語が統一されている | Suggestion | 日本語/英語が混在していないこと（用語を除く） |
| BD-08 | チェックリストセクションがある | Suggestion | レビュー/確認用の `- [ ]` リストがあると実用的 |

## references/ 構造

| # | チェック項目 | 重要度 | 判定方法 |
|---|------------|--------|---------|
| RF-01 | ネストなし（1階層のみ） | Warning | `references/sub/file.md` のようなサブディレクトリがないこと |
| RF-02 | 100行超ファイルに TOC がある | Suggestion | ファイル冒頭に目次（見出しリンク or 見出しリスト）があること |
| RF-03 | SKILL.md と内容が重複していない | Suggestion | 同じ情報が SKILL.md と references/ の両方に存在しないこと |
| RF-04 | ファイル数が適切（2〜5が目安） | Suggestion | 1ファイルなら SKILL.md に統合を検討。6+なら統合・再構成を検討 |
| RF-05 | 各ファイルの目的が明確に異なる | Suggestion | 類似内容のファイルが複数ないこと |

## ディレクトリ構造

| # | チェック項目 | 重要度 | 判定方法 |
|---|------------|--------|---------|
| DR-01 | 不要なドキュメントファイルがない | Warning | README.md, INSTALLATION_GUIDE.md, CHANGELOG.md, QUICK_REFERENCE.md 等が存在しないこと |
| DR-02 | 空ディレクトリがない | Suggestion | scripts/, references/, assets/ が存在するなら中身があること |

## description トリガー品質

description はスキルの発火トリガーとして最も重要。以下の観点で品質を評価する。

| # | チェック項目 | 重要度 | 判定方法 |
|---|------------|--------|---------|
| TR-01 | スキルが何をするかが明確 | Warning | 機能の概要が1文目で伝わること |
| TR-02 | カバー範囲が列挙されている | Suggestion | 「〜、〜、〜をカバー」のように具体的な機能を列挙 |
| TR-03 | トリガー条件が明記されている | Warning | 「〜時に使用」「〜の場合に使用」等の条件が含まれること |
| TR-04 | 50文字以上ある | Suggestion | 短すぎると Claude が適切に判断できない |
| TR-05 | 他スキルとの差別化が明確 | Suggestion | 類似スキルがある場合、使い分けが分かること |
