---
name: git-worktree
description: git worktreeを活用した並列開発ガイド。worktreeライフサイクル（作成→環境構築→作業→同期→クリーンアップ）、ブランチ命名戦略、rebaseワークフロー、こまめなコミット戦略、コンフリクト予防策、環境セットアップ、トラブルシューティングをカバー。並列開発、マルチエージェント開発、ブランチ分離が必要な場面で使用。
---

# git worktree 並列開発ガイド

## 概要

git worktree を活用した並列開発の技術ガイド。worktree の操作・運用に特化し、すべてのエージェントおよび開発者が参照できる独立したリファレンスとして機能する。

```
/project-orchestrator との役割分担:
  project-orchestrator → 並列開発ワークフロー全体のオーケストレーション
  /git-worktree (本スキル) → git worktree の操作・運用の技術ガイド

project-orchestrator から参照されるが、単独でも利用可能。
```

## 基本原則

```
1. 共有 .git ディレクトリ
   → すべての worktree は同一リポジトリの .git を共有する
   → コミット・ブランチ・リモート情報は全 worktree で共通

2. 独立した HEAD
   → 各 worktree は独自の HEAD を持ち、異なるブランチをチェックアウトできる
   → 作業ディレクトリ・インデックスも独立

3. 同一ブランチの二重チェックアウト禁止
   → 同じブランチを複数の worktree で同時にチェックアウトできない
   → 違反すると fatal: '{branch}' is already checked out at '{path}'

4. Hooks の共有
   → .git/hooks は共有されるため、pre-commit 等は全 worktree で動作する
   → worktree 固有の hook は設定できない

5. gitignore 対象ファイルは自動コピーされない
   → .claude/、node_modules/、.env 等は worktree 作成後に別途セットアップが必要
```

## worktree ライフサイクル

### 全体フロー

```
1. 作成     → git worktree add でブランチと作業ディレクトリを作成
2. 環境構築 → 依存インストール、設定ファイルコピー、MCP 登録
3. 作業     → 実装、こまめなコミット、push
4. 同期     → rebase で親ブランチの最新を取り込み
5. PR 作成  → gh pr create で PR を作成
6. クリーンアップ → worktree 削除、ブランチ削除
```

### Phase 1: 作成

```bash
# 親ブランチから新しいタスクブランチ + worktree を作成
mkdir -p .worktrees
git worktree add .worktrees/{dir-name} -b {branch-name} {base-branch}

# 例: feature/auth から task/auth-login ブランチを作成
git worktree add .worktrees/task-auth-login -b task/auth-login feature/auth
```

```bash
# 既存ブランチから worktree を作成（-b 不要）
git worktree add .worktrees/{dir-name} {existing-branch}
```

### Phase 2: 環境構築

worktree 作成直後に**必ず**セットアップを実行する。

```bash
cd .worktrees/{dir-name}

# 1. .claude/ ディレクトリをコピー（CLAUDE.md, rules/, settings 等）
if [ -d "../../.claude" ]; then
    cp -r "../../.claude" ".claude"
fi

# 2. 依存関係のインストール
pnpm install  # or npm install / go mod download / pip install -r requirements.txt

# 3. Serena MCP の登録（worktree パスに紐づけ）
claude mcp add serena -- uvx --from git+https://github.com/oraios/serena \
  serena-mcp-server --context ide-assistant --project $(pwd)
```

詳細なセットアップ手順は [references/worktree-setup-checklist.md](references/worktree-setup-checklist.md) を参照。

### Phase 3: 作業

```bash
# 作業開始時の確認
pwd                        # worktree 内であること
git branch --show-current  # 正しいブランチであること

# 実装 → こまめにコミット（後述のコミット戦略を参照）
git add {files}
git commit -m "{type}: {概要}"

# 定期的に push
git push -u origin {branch-name}
```

### Phase 4: 同期（rebase）

```bash
git fetch origin
git rebase {base-branch}
# コンフリクト発生時は解消 → git add → git rebase --continue
git push --force-with-lease origin {branch-name}
```

詳細は [references/rebase-workflow.md](references/rebase-workflow.md) を参照。

### Phase 5: PR 作成

作業完了後のフロー:

```bash
# 1. 最終コミット + push
git add {files} && git commit -m "{type}: {概要}"
git push origin {branch-name}

# 2. rebase で親ブランチの最新を取り込み
git fetch origin
git rebase {base-branch}

# 3. テスト・lint が通ることを確認
pnpm test && pnpm lint  # プロジェクトに応じたコマンド

# 4. force-with-lease で push
git push --force-with-lease origin {branch-name}

# 5. PR 作成
gh pr create --base {base-branch} --title "{タイトル}" --body "{本文}"
```

#### gh が利用できない場合のフォールバック

以下の情報をユーザーに提示して手動 PR 作成をガイドする:

```
PR 作成 URL:
  https://github.com/{owner}/{repo}/compare/{base}...{head}

推奨内容:
  タイトル: {type}: {概要}
  本文: 変更の要約、テスト結果、関連 Issue

差分サマリーの取得:
  git diff --stat {base-branch}...HEAD
  git log --oneline {base-branch}..HEAD
```

### Phase 6: クリーンアップ

```bash
# worktree 削除
git worktree remove .worktrees/{dir-name}

# リモートブランチ削除（PR マージ後）
git branch -d {branch-name}
git push origin --delete {branch-name}

# 不整合メタデータの掃除
git worktree prune
```

## ブランチ命名戦略

### パターン: `{prefix}/{description}`

| prefix | 用途 | 例 |
|--------|------|-----|
| `feature/` | 機能開発（親ブランチ） | `feature/user-auth` |
| `task/` | 個別タスク（worktree 用） | `task/auth-login-api` |
| `fix/` | バグ修正 | `fix/token-refresh` |
| `hotfix/` | 緊急修正 | `hotfix/security-patch` |
| `refactor/` | リファクタリング | `refactor/db-layer` |

### worktree ディレクトリ命名

```
ブランチ名のスラッシュをハイフンに置換:
  task/auth-login → .worktrees/task-auth-login
  fix/token-refresh → .worktrees/fix-token-refresh
```

### 命名のベストプラクティス

```
Good:
  task/auth-login-api      → 何をするか明確
  task/user-profile-fe     → 領域（FE）が明確
  fix/jwt-expiry-handling  → 修正対象が明確

Bad:
  task/work1               → 内容が不明
  task/update              → 曖昧すぎる
  feature/big-feature      → 粒度が大きすぎる
```

## コミット戦略

### 頻度と粒度

```
基本ルール:
  - 15〜30 分ごと、または意味のある変更単位ごとにコミット
  - テストが通る状態でコミットすることを優先
  - 完璧を待たず、動く状態でコミットする

コミットタイミングの判断:
  新しいファイルを作成した？ → コミット
  関数/メソッドを1つ実装した？ → コミット
  テストを追加して通った？ → コミット
  設定ファイルを変更した？ → コミット
  30分以上コミットしていない？ → 現状をコミット（WIP 可）
```

### Conventional Commits

```
{type}: {概要}

type:
  feat     → 新機能
  fix      → バグ修正
  refactor → リファクタリング
  test     → テスト追加・修正
  docs     → ドキュメント
  chore    → その他（設定変更、依存更新等）
  style    → フォーマット修正（動作に影響なし）

例:
  feat: ログインAPIエンドポイントを追加
  fix: トークンリフレッシュの期限判定を修正
  test: ユーザー認証のユニットテストを追加
  chore: ESLint設定を更新
```

### WIP コミットの扱い

```
作業中に中間状態をコミットする場合:
  git commit -m "wip: ログイン画面のバリデーション実装中"

PR 前に整理する場合（インタラクティブ rebase）:
  git rebase -i {base-branch}
  → WIP コミットを squash/fixup で統合

注意:
  - WIP コミットは push 前に整理することを推奨
  - ただし、並列開発では push 済みの WIP があっても問題ない
  - 最終的に PR マージ時に squash merge すれば履歴はクリーンになる
```

## rebase ワークフロー概要

### 基本フロー

```
1. git fetch origin          → リモートの最新を取得
2. git rebase {base-branch}  → 親ブランチの上にコミットを載せ直す
3. コンフリクト解消（発生時） → 解消 → add → continue
4. git push --force-with-lease → 安全に force push
```

### タイミング指針

```
必須:
  - PR 作成前（親ブランチの最新を取り込む）
  - レビュー指摘の修正後

推奨:
  - 半日〜1日ごとの定期同期
  - 親ブランチに大きな変更がマージされた直後
```

詳細な手順とコンフリクト解消方法は [references/rebase-workflow.md](references/rebase-workflow.md) を参照。

## コンフリクト予防策概要

### 5 原則

```
1. タスク分割時にファイル競合を分析する
   → 同じファイルを複数タスクが変更しないようにタスクを設計する

2. 共通コードの変更は先行タスクとして切り出す
   → 設定ファイル、型定義、インターフェースは先に確定させる

3. ディレクトリで責任範囲を分離する
   → BE/FE、ドメイン別にディレクトリを分ける

4. 定期的に親ブランチを同期する
   → 半日〜1日ごとに rebase して差分を小さく保つ

5. ロックファイルの競合に備える
   → pnpm-lock.yaml, go.sum 等は再生成で解消するパターンを把握する
```

詳細は [references/conflict-prevention.md](references/conflict-prevention.md) を参照。

## コマンドクイックリファレンス

| 操作 | コマンド |
|------|---------|
| worktree 作成（新規ブランチ） | `git worktree add .worktrees/{dir} -b {branch} {base}` |
| worktree 作成（既存ブランチ） | `git worktree add .worktrees/{dir} {branch}` |
| worktree 一覧 | `git worktree list` |
| worktree 削除 | `git worktree remove .worktrees/{dir}` |
| worktree 強制削除 | `git worktree remove --force .worktrees/{dir}` |
| メタデータ掃除 | `git worktree prune` |
| 現在のブランチ確認 | `git branch --show-current` |
| rebase | `git fetch origin && git rebase {base}` |
| rebase 中断 | `git rebase --abort` |
| 安全な force push | `git push --force-with-lease origin {branch}` |
| 親ブランチとの差分 | `git diff {base}...HEAD` |
| コミットログ | `git log --oneline {base}..HEAD` |
| PR 作成 | `gh pr create --base {base} --title "{title}" --body "{body}"` |

## レビューチェックリスト

### worktree 作業開始時

```
[ ] pwd で worktree 内であることを確認
[ ] git branch --show-current で正しいブランチを確認
[ ] .claude/ ディレクトリが存在することを確認
[ ] 依存関係がインストール済みであることを確認
```

### コミット前

```
[ ] テストが通ることを確認
[ ] lint/format が通ることを確認
[ ] 不要なファイル（デバッグ用コード等）が含まれていないことを確認
[ ] コミットメッセージが Conventional Commits に従っていることを確認
```

### PR 作成前

```
[ ] rebase で親ブランチの最新を取り込み済み
[ ] すべてのテストが通る
[ ] lint/format エラーがない
[ ] 変更内容がタスクのスコープ内に収まっている
[ ] WIP コミットが整理されている（必要に応じて squash）
```

### クリーンアップ時

```
[ ] worktree が削除されている
[ ] リモートブランチが削除されている（PR マージ後）
[ ] git worktree prune でメタデータが掃除されている
```

## リファレンス

- [worktree セットアップチェックリスト](references/worktree-setup-checklist.md) - 作成後の環境構築手順
- [rebase ワークフロー詳細](references/rebase-workflow.md) - rebase 手順とコンフリクト解消
- [コンフリクト予防戦略](references/conflict-prevention.md) - タスク設計によるコンフリクト回避
- [トラブルシューティング](references/troubleshooting.md) - よくある問題と解決策
