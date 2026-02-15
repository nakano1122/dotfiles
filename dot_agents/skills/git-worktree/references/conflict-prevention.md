# コンフリクト予防戦略

並列開発でのコンフリクトを最小化するための設計・運用戦略。

## 目次

- [タスク分割時のファイル競合分析](#タスク分割時のファイル競合分析)
  - [分析手順](#分析手順)
  - [競合リスクの判定](#競合リスクの判定)
- [共通コード変更管理](#共通コード変更管理)
  - [先行タスクとして切り出すべきもの](#先行タスクとして切り出すべきもの)
  - [設定ファイルの変更ルール](#設定ファイルの変更ルール)
- [ディレクトリ分離戦略](#ディレクトリ分離戦略)
  - [BE/FE 分離](#befe-分離)
  - [ドメイン別分離](#ドメイン別分離)
  - [モノレポの分離](#モノレポの分離)
- [同期頻度の指針](#同期頻度の指針)
- [ロックファイル競合の解消パターン](#ロックファイル競合の解消パターン)
  - [pnpm-lock.yaml](#pnpm-lockyaml)
  - [package-lock.json (npm)](#package-lockjson-npm)
  - [yarn.lock](#yarnlock)
  - [go.sum](#gosum)
  - [共通の原則](#共通の原則)

## タスク分割時のファイル競合分析

### 分析手順

```
1. タスク一覧を作成
2. 各タスクが変更するファイル/ディレクトリを列挙
3. 重複するファイルがないか確認
4. 重複がある場合は分割戦略を見直す

例:
  タスク A: src/auth/login.ts, src/auth/types.ts
  タスク B: src/auth/register.ts, src/auth/types.ts
  → types.ts が競合リスク
  → 対策: types.ts の変更を先行タスクとして切り出す
```

### 競合リスクの判定

```
高リスク:
  - 同一ファイルを複数タスクが変更する
  - 共通のインターフェース/型定義を変更する
  - 設定ファイル（tsconfig, eslint 等）を変更する
  - ロックファイル（pnpm-lock.yaml 等）に影響する

中リスク:
  - 同一ディレクトリ内の異なるファイルを変更する
  - 共通ユーティリティの新規関数追加（既存関数の変更ではない）

低リスク:
  - 完全に異なるディレクトリで作業する
  - 新規ファイルの追加のみ（既存ファイルの変更なし）
```

## 共通コード変更管理

### 先行タスクとして切り出すべきもの

```
優先度: 高
  - 共有型定義（types.ts, interfaces.ts）
  - API スキーマ定義（OpenAPI, GraphQL schema）
  - データベースマイグレーション
  - 共通設定ファイル（tsconfig, eslint, prettier）

優先度: 中
  - 共通ユーティリティの変更
  - 認証/認可ミドルウェアの変更
  - ルーティング設定の変更

手順:
  1. 共通部分を先行タスクとして独立させる
  2. 先行タスクを完了し、親ブランチにマージ
  3. 他のタスクが先行タスクの成果を rebase で取り込む
  4. 各タスクは自身のスコープ内のみ変更する
```

### 設定ファイルの変更ルール

```
設定ファイル変更が必要なタスクが複数ある場合:
  1. 設定変更だけの先行タスクを作る
  2. 先行タスクで全設定変更をまとめて実施
  3. 先行タスクを親ブランチにマージ
  4. 他タスクが rebase で取り込む

例:
  タスク A: ESLint に新規ルールを追加 + 実装
  タスク B: TypeScript の strict 設定を変更 + 実装
  → タスク 0 (先行): ESLint ルール追加 + tsconfig 変更
  → タスク A: 実装のみ（設定変更済み前提）
  → タスク B: 実装のみ（設定変更済み前提）
```

## ディレクトリ分離戦略

### BE/FE 分離

```
src/
├── backend/     ← BE タスクのスコープ
│   ├── api/
│   ├── services/
│   └── models/
├── frontend/    ← FE タスクのスコープ
│   ├── components/
│   ├── pages/
│   └── hooks/
└── shared/      ← 先行タスクで確定、以降は変更しない
    ├── types/
    └── constants/
```

### ドメイン別分離

```
src/
├── auth/        ← タスク A のスコープ
│   ├── login.ts
│   ├── register.ts
│   └── types.ts
├── users/       ← タスク B のスコープ
│   ├── profile.ts
│   ├── settings.ts
│   └── types.ts
└── shared/      ← 先行タスクで確定
    └── types.ts
```

### モノレポの分離

```
packages/
├── api/         ← BE タスクのスコープ
├── web/         ← FE タスクのスコープ
├── shared/      ← 先行タスクで確定
└── config/      ← 先行タスクで確定
```

## 同期頻度の指針

```
同期タイミング:
  - 半日〜1日ごとの定期同期を基本とする
  - 親ブランチに他タスクがマージされたら即同期
  - 作業開始時に必ず同期

判断フロー:
  親ブランチに新しいコミットがある？
  ├→ Yes → 自分の変更と関連するファイルが含まれる？
  │         ├→ Yes → 即座に rebase（コンフリクト早期発見）
  │         └→ No  → 次の区切りで rebase（急がなくても可）
  └→ No  → 不要

同期しない期間が長いほどリスクが増大:
  1日以内: 低リスク（通常はコンフリクトなし）
  1〜2日: 中リスク（小さなコンフリクトの可能性）
  3日以上: 高リスク（大きなコンフリクトの可能性大）
```

## ロックファイル競合の解消パターン

### pnpm-lock.yaml

```bash
# コンフリクト発生時の解消手順:
# 1. 親ブランチのロックファイルを採用
git checkout --theirs pnpm-lock.yaml

# 2. 自分の package.json の変更を反映して再生成
pnpm install

# 3. ステージングして続行
git add pnpm-lock.yaml
git rebase --continue
```

### package-lock.json (npm)

```bash
git checkout --theirs package-lock.json
npm install
git add package-lock.json
git rebase --continue
```

### yarn.lock

```bash
git checkout --theirs yarn.lock
yarn install
git add yarn.lock
git rebase --continue
```

### go.sum

```bash
# go.sum のコンフリクトは再生成で解消
git checkout --theirs go.sum
go mod tidy
git add go.sum go.mod
git rebase --continue
```

### 共通の原則

```
ロックファイルの競合解消ルール:
  1. 手動でマージしない（手動編集は整合性を壊す）
  2. 親ブランチ側のファイルを採用する（--theirs）
  3. パッケージマネージャのコマンドで再生成する
  4. 再生成後のファイルをステージングする

注意:
  - rebase では --theirs が「親ブランチ側」を指す（merge とは逆）
  - 自分の変更は package.json / go.mod に記録されているため、
    再生成すれば反映される
```
