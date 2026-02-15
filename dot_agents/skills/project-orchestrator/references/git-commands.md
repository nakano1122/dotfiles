# Git コマンドリファレンス

> git worktree の詳細な操作・運用ガイド（ライフサイクル、rebase 詳細、コンフリクト予防、トラブルシューティング）は `/git-worktree` スキルを参照。

## 目次

- [ブランチ戦略 + worktree 構成](#ブランチ戦略--worktree-構成)
- [初期セットアップ](#初期セットアップ)
  - [.gitignore に worktree ディレクトリを追加（初回のみ）](#gitignore-に-worktree-ディレクトリを追加初回のみ)
  - [feature ブランチ作成（project-orchestrator が実行）](#feature-ブランチ作成project-orchestrator-が実行)
- [worktree 操作](#worktree-操作)
  - [タスクブランチ + worktree 作成（BE/FE orchestrator が実行）](#タスクブランチ--worktree-作成befe-orchestrator-が実行)
  - [worktree セットアップ（作成後に必須）](#worktree-セットアップ作成後に必須)
  - [一覧表示](#一覧表示)
  - [既存ブランチから worktree を作成](#既存ブランチから-worktree-を作成)
  - [worktree 削除](#worktree-削除)
  - [不整合の修復](#不整合の修復)
- [rebase 戦略](#rebase-戦略)
  - [タスクブランチを feature ブランチに rebase（マージ前に必須）](#タスクブランチを-feature-ブランチに-rebaseマージ前に必須)
  - [rebase 後のプッシュ](#rebase-後のプッシュ)
  - [feature ブランチで develop の最新を取り込む](#feature-ブランチで-develop-の最新を取り込む)
- [マージ操作](#マージ操作)
  - [タスクブランチ → feature ブランチ（rebase 後にマージ）](#タスクブランチ--feature-ブランチrebase-後にマージ)
  - [feature ブランチ → develop（PR 経由）](#feature-ブランチ--developpr-経由)
- [コンフリクト解消](#コンフリクト解消)
  - [担当オーケストレータの責務](#担当オーケストレータの責務)
  - [コンフリクト解消手順](#コンフリクト解消手順)
- [実装セッション用コマンド](#実装セッション用コマンド)
  - [作業開始時](#作業開始時)
  - [作業完了時](#作業完了時)
- [状況確認](#状況確認)
- [コミットメッセージ規約](#コミットメッセージ規約)
- [クリーンアップ（全タスク完了後）](#クリーンアップ全タスク完了後)

## ブランチ戦略 + worktree 構成

```
develop
└── feature/{機能名}                          ← project-orchestrator が管理
    ├── task/{作業名}-be-api                  ← BE orchestrator が管理
    │   → .worktrees/task-{作業名}-be-api/
    ├── task/{作業名}-be-schema               ← BE orchestrator が管理
    │   → .worktrees/task-{作業名}-be-schema/
    ├── task/{作業名}-fe-auth                 ← FE orchestrator が管理
    │   → .worktrees/task-{作業名}-fe-auth/
    └── task/{作業名}-fe-dashboard            ← FE orchestrator が管理
        → .worktrees/task-{作業名}-fe-dashboard/
```

## 初期セットアップ

### .gitignore に worktree ディレクトリを追加（初回のみ）

```bash
echo ".worktrees/" >> .gitignore
git add .gitignore && git commit -m "chore: .worktreesをgitignoreに追加"
```

### feature ブランチ作成（project-orchestrator が実行）

```bash
git checkout develop
git pull origin develop
git checkout -b feature/{機能名}
git push -u origin feature/{機能名}
```

## worktree 操作

### タスクブランチ + worktree 作成（BE/FE orchestrator が実行）

```bash
mkdir -p .worktrees

# 作業ブランチの作成と worktree の同時作成
# -b: 新しいブランチを作成
# 最後の引数: 分岐元のブランチ
git worktree add .worktrees/task-{作業名} -b task/{作業名} feature/{機能名}
```

### worktree セットアップ（作成後に必須）

worktree 作成直後に**必ず**以下を実行する:

```bash
cd .worktrees/task-{作業名}

# 1. .claude/ ディレクトリをコピー（CLAUDE.md, rules/, settings 等）
#    ※ .claude/ は gitignore 対象のため worktree に自動コピーされない
if [ -d "../../.claude" ]; then
    cp -r "../../.claude" ".claude"
fi

# 2. 依存関係のインストール（プロジェクトに応じて選択）
pnpm install  # npm install / yarn install / go mod download 等

# 3. プロジェクト固有のセットアップ（該当する場合）
# 例: 環境変数ファイルの作成、シンボリックリンクの設定、DB マイグレーション等

# 4. Serena MCP の登録（worktree パスに紐づけ）
claude mcp add serena -- uvx --from git+https://github.com/oraios/serena serena-mcp-server --context ide-assistant --project $(pwd)
```

**なぜ必要か:**
- `.claude/` は gitignore 対象のため worktree に自動コピーされない。コピーしないと `CLAUDE.md`（`.claude/` 配下）、`.claude/rules/`、`.claude/settings.local.json` が欠落する
- なお、プロジェクトルート直下の `CLAUDE.md` は worktree の親ディレクトリ探索で自動ロードされるため、コピー不要
- MCP 設定は `~/.claude.json` にディレクトリパス別で保存されるため、worktree ごとに登録が必要

### 一覧表示

```bash
git worktree list
```

### 既存ブランチから worktree を作成

```bash
# すでにブランチが存在する場合（-b は不要）
git worktree add .worktrees/task-{作業名} task/{作業名}
```

### worktree 削除

```bash
# 単体削除（クリーンな状態の場合）
git worktree remove .worktrees/task-{作業名}

# 未コミットの変更がある場合は強制削除
git worktree remove --force .worktrees/task-{作業名}

# 全 worktree を一括削除
rm -rf .worktrees && git worktree prune
```

### 不整合の修復

```bash
# ディレクトリが手動削除された場合にメタデータを掃除
git worktree prune
```

## rebase 戦略

### タスクブランチを feature ブランチに rebase（マージ前に必須）

```bash
cd .worktrees/task-{作業名}
git fetch origin
git rebase feature/{機能名}

# コンフリクト発生時
git status                      # コンフリクトファイルを確認
# コンフリクトを手動解消
git add {解消したファイル}
git rebase --continue

# rebase を中断する場合
git rebase --abort
```

### rebase 後のプッシュ

```bash
# rebase 後は force push が必要
git push --force-with-lease origin task/{作業名}
```

### feature ブランチで develop の最新を取り込む

```bash
git checkout feature/{機能名}
git fetch origin
git rebase origin/develop

# コンフリクト発生時は同様に解消
git push --force-with-lease origin feature/{機能名}
```

## マージ操作

### タスクブランチ → feature ブランチ（rebase 後にマージ）

BE/FE orchestrator が管理:

```bash
# 1. rebase（上記参照）
# 2. feature ブランチに移動してマージ
git checkout feature/{機能名}
git merge task/{作業名}
git push origin feature/{機能名}
```

または PR 経由でマージ:
```
task/{作業名} → feature/{機能名}
```

### feature ブランチ → develop（PR 経由）

project-orchestrator が管理。全タスクが feature ブランチにマージされた後:

```
feature/{機能名} → develop
```

## コンフリクト解消

### 担当オーケストレータの責務

- **BE タスクのコンフリクト**: `/backend-orchestrator` が解消
- **FE タスクのコンフリクト**: `/frontend-orchestrator` が解消
- **feature ブランチのコンフリクト**: `/project-orchestrator` が解消

### コンフリクト解消手順

```bash
# rebase 中のコンフリクト
git status                          # コンフリクトファイルを確認
# エディタでコンフリクトマーカーを解消
git add {解消したファイル}
git rebase --continue

# 全コンフリクト解消後
git push --force-with-lease origin {ブランチ名}
```

## 実装セッション用コマンド

### 作業開始時

```bash
# worktree ディレクトリに移動
cd .worktrees/task-{作業名}

# ブランチ確認
git branch --show-current

# 作業ディレクトリの確認（メインリポではないことを確認）
pwd  # .worktrees/task-{作業名} であること
```

**重要: メインリポジトリのファイルを誤編集しないこと。** ファイルパスは必ず worktree ルートからの相対パスで指定する。

### 作業完了時

```bash
cd .worktrees/task-{作業名}
git add {対象ファイル}
git commit -m "{type}: {概要}"
git push -u origin task/{作業名}
```

## 状況確認

```bash
# 現在のブランチ確認
git branch --show-current

# ブランチ一覧
git branch -a

# worktree 一覧
git worktree list

# 各ブランチのコミット状況
git log --oneline task/{作業名}

# feature ブランチとの差分
git diff feature/{機能名}...task/{作業名}
```

## コミットメッセージ規約

```
{type}: {概要}

{詳細（任意）}
```

| type | 用途 |
|------|------|
| feat | 新機能 |
| fix | バグ修正 |
| refactor | リファクタリング |
| test | テスト追加・修正 |
| docs | ドキュメント |
| chore | その他 |

## クリーンアップ（全タスク完了後）

```bash
# worktree 削除
git worktree remove .worktrees/task-{作業名}
# 全 worktree を一括削除する場合
rm -rf .worktrees && git worktree prune

# スラッシュコマンドファイル削除
rm -f .claude/commands/worker-*.md
rm -f .claude/commands/fix-*.md

# 作業ブランチ削除（任意）
git branch -d task/{作業名}
git push origin --delete task/{作業名}

# feature ブランチ削除（develop マージ後）
git branch -d feature/{機能名}
git push origin --delete feature/{機能名}
```
