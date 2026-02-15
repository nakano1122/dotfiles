---
name: skill-reviewer
description: Claude Code スキルのベストプラクティス適合レビューガイド。フロントマター検証（name/description ルール）、SKILL.md 本文品質（行数・構造・Progressive Disclosure）、references/ 構造、description トリガー品質、アンチパターン検出をカバー。スキルの新規作成後のレビュー、既存スキルの品質改善、スキル全体の一括監査時に使用。
---

# スキルレビューガイド

Claude Code スキルをベストプラクティスに照らしてレビューするためのガイド。公式バリデーションルール + SKILL.md ガイドラインに基づく。

## レビューワークフロー

```
1. 対象スキルの特定
   - パス指定: ~/.claude/skills/<skill-name>/
   - 一括: ~/.claude/skills/ 配下全スキル

2. ディレクトリ構造の確認
   - SKILL.md の存在確認
   - scripts/, references/, assets/ の内容確認
   - 不要ファイル（README.md, CHANGELOG.md 等）の検出

3. フロントマター検証
   - YAML パース可否
   - name / description の必須チェック
   - name 形式: ^[a-z0-9-]+$, 64文字以内, 先頭/末尾/連続ハイフン禁止
   - description: 1024文字以内, 山括弧(<>)禁止
   - 許可フィールド: name, description, license, allowed-tools, metadata

4. SKILL.md 本文レビュー
   - 行数チェック（500行以内）
   - Progressive Disclosure パターン確認
   - references/ へのリンク確認
   - 構造・可読性の評価

5. references/ レビュー
   - ネスト構造の検出（1階層のみ許可）
   - 100行超ファイルの TOC 有無
   - SKILL.md との重複チェック

6. レビュー結果の出力
   - 重要度別（Critical / Warning / Suggestion）に整理
   - 良い点も記載

7. 改善提案の提示
   - 具体的な修正案を提示
```

## レビュー判定フロー

```
SKILL.md が存在する？
├→ No  → Critical: SKILL.md 不在
└→ Yes → フロントマターが有効？
          ├→ No  → Critical: フロントマター不正
          └→ Yes → name/description ルール準拠？
                    ├→ No  → Critical: name/description ルール違反
                    └→ Yes → 本文 500行以内？
                              ├→ No  → Warning: 行数超過
                              └→ Yes → 構造・references 品質確認
                                        ├→ 問題あり → Warning/Suggestion
                                        └→ 問題なし → Pass
```

## レビュー基準の概要

3段階の重要度で判定する。

| 重要度 | 意味 | 例 |
|--------|------|-----|
| **Critical** | スキルが正常に動作しない | SKILL.md 不在、フロントマター不正、name/description ルール違反 |
| **Warning** | ベストプラクティス違反 | 500行超、body 内の When to Use、TODO 残存、references/ ネスト、不要ファイル |
| **Suggestion** | 品質向上の推奨事項 | 300行超、TOC なし、SKILL.md と references/ の重複、description 短すぎ |

詳細な判定基準: [references/review-checklist.md](references/review-checklist.md)

## レビュー結果の出力形式

```markdown
# スキルレビュー: <skill-name>

## 概要

| 項目 | 結果 |
|------|------|
| スキル名 | <skill-name> |
| 総合判定 | Pass / Warning / Critical |
| Critical | N 件 |
| Warning | N 件 |
| Suggestion | N 件 |

## Critical

- [C-01] <指摘内容>
  - 現状: ...
  - 修正案: ...

## Warning

- [W-01] <指摘内容>
  - 現状: ...
  - 推奨: ...

## Suggestion

- [S-01] <指摘内容>
  - 推奨: ...

## 良い点

- <良い点>
```

## 一括レビュー

`~/.claude/skills/` 配下の全スキルを対象にレビューする場合:

```
1. ls ~/.claude/skills/ でスキル一覧を取得
2. 各スキルに対してレビューワークフローを実行
3. サマリーテーブルを出力:

| スキル名 | 判定 | Critical | Warning | Suggestion |
|---------|------|----------|---------|------------|
| skill-a | Pass | 0 | 1 | 2 |
| skill-b | Critical | 1 | 0 | 0 |
```

## レビューチェックリスト

### フロントマター

- [ ] YAML フロントマターが存在し、パース可能
- [ ] `name` が `^[a-z0-9-]+$` に合致、64文字以内
- [ ] `description` が 1024文字以内、山括弧なし
- [ ] 許可フィールドのみ使用（name, description, license, allowed-tools, metadata）

### description 品質

- [ ] スキルの機能と用途の両方を記述
- [ ] 「〜時に使用」等のトリガー条件を含む
- [ ] body 内に「When to Use」セクションがない（description に集約）

### SKILL.md 本文

- [ ] 500行以内
- [ ] TODO / FIXME / PLACEHOLDER が残存していない
- [ ] references/ 内のファイルへのリンクが記載されている
- [ ] 不要な補助ファイル（README.md 等）が存在しない

### references/ 構造

- [ ] ネストなし（1階層のみ）
- [ ] 100行超のファイルに TOC あり
- [ ] SKILL.md との内容重複なし

## リファレンス

- [references/review-checklist.md](references/review-checklist.md) - 詳細チェックリスト（全項目・判定基準付き）
- [references/anti-patterns.md](references/anti-patterns.md) - アンチパターン集（悪い例/良い例付き）
