# トラブルシューティング

git worktree 運用で発生しやすい問題と解決策。

## 目次

- [worktree 作成時のエラー](#worktree-作成時のエラー)
  - [同一ブランチの二重チェックアウト](#同一ブランチの二重チェックアウト)
  - [存在しないブランチの指定](#存在しないブランチの指定)
  - [ディレクトリが既に存在する](#ディレクトリが既に存在する)
- [worktree 削除時の問題](#worktree-削除時の問題)
  - [未コミットの変更がある](#未コミットの変更がある)
  - [rm -rf で手動削除してしまった場合](#rm-rf-で手動削除してしまった場合)
  - [ロックされた worktree](#ロックされた-worktree)
- [rebase 時のトラブル](#rebase-時のトラブル)
  - [rebase の中断と復旧](#rebase-の中断と復旧)
  - [force-with-lease の失敗](#force-with-lease-の失敗)
  - [detached HEAD 状態](#detached-head-状態)
  - [rebase 中に同じコンフリクトが繰り返される](#rebase-中に同じコンフリクトが繰り返される)
- [環境関連の問題](#環境関連の問題)
  - [node_modules が壊れた](#node_modules-が壊れた)
  - [.claude/ ディレクトリが欠落](#claude-ディレクトリが欠落)
  - [MCP が登録されていない](#mcp-が登録されていない)
  - [環境変数が設定されていない](#環境変数が設定されていない)
- [復旧手順チートシート](#復旧手順チートシート)

## worktree 作成時のエラー

### 同一ブランチの二重チェックアウト

```
エラー:
  fatal: '{branch}' is already checked out at '{path}'

原因:
  同じブランチが別の worktree（またはメインリポジトリ）でチェックアウト済み

解決:
  # どの worktree がブランチを使用しているか確認
  git worktree list

  # 対処方法 1: 使用中の worktree でブランチを切り替える
  cd {使用中のworktreeパス}
  git checkout {別のブランチ}

  # 対処方法 2: 使用していない worktree を削除する
  git worktree remove {使用中のworktreeパス}

  # 対処方法 3: 新しいブランチ名で作成する
  git worktree add .worktrees/{dir} -b {新しいブランチ名} {base-branch}
```

### 存在しないブランチの指定

```
エラー:
  fatal: invalid reference: '{branch}'

原因:
  指定したベースブランチがローカルに存在しない

解決:
  # リモートの最新を取得
  git fetch origin

  # リモートブランチからローカルブランチを作成
  git checkout -b {branch} origin/{branch}

  # 再度 worktree を作成
  git worktree add .worktrees/{dir} -b {new-branch} {branch}
```

### ディレクトリが既に存在する

```
エラー:
  fatal: '{path}' already exists

原因:
  worktree のディレクトリパスが既に存在する

解決:
  # ディレクトリの中身を確認
  ls -la {path}

  # 不要なら削除して再作成
  rm -r {path}
  git worktree add {path} -b {branch} {base}

  # git worktree のメタデータに残骸がある場合
  git worktree prune
  git worktree add {path} -b {branch} {base}
```

## worktree 削除時の問題

### 未コミットの変更がある

```
エラー:
  fatal: '{path}' contains modified or untracked files, use --force to delete it

解決:
  # 変更内容を確認
  cd {worktreeパス}
  git status
  git diff

  # 変更をコミットしてから削除
  git add {files}
  git commit -m "{type}: {概要}"
  git push origin {branch}
  cd {メインリポジトリ}
  git worktree remove {worktreeパス}

  # 変更が不要なら強制削除
  git worktree remove --force {worktreeパス}
```

### rm -rf で手動削除してしまった場合

```
症状:
  - worktree ディレクトリを rm -rf で削除した
  - git worktree list に残骸が表示される

解決:
  # メタデータを掃除
  git worktree prune

  # 確認
  git worktree list
  # → 削除した worktree が一覧から消えていること
```

### ロックされた worktree

```
エラー:
  fatal: '{path}' is locked

原因:
  worktree がロックされている（手動ロック or プロセスが使用中）

解決:
  # ロックを解除
  git worktree unlock {path}

  # 解除後に削除
  git worktree remove {path}
```

## rebase 時のトラブル

### rebase の中断と復旧

```
症状:
  - rebase 中にコンフリクトが複雑すぎる
  - 解消方法がわからない

解決:
  # rebase を中断して元の状態に戻す
  git rebase --abort
  # → rebase 開始前の状態に完全に戻る

  # 対策を検討してから再試行
  # 1. 小さなコミットに分割してから rebase
  # 2. 親ブランチの変更内容を確認してから rebase
  # 3. 先に merge で取り込んでから rebase に切り替え
```

### force-with-lease の失敗

```
エラー:
  ! [rejected] {branch} -> {branch} (stale info)

原因:
  リモートブランチが期待と異なる状態
  （他のプロセスが push した、または前回の push 後にリモートが更新された）

解決:
  # リモートの最新を取得
  git fetch origin

  # リモートとローカルの差分を確認
  git log origin/{branch}..{branch} --oneline
  git log {branch}..origin/{branch} --oneline

  # リモートの変更が自分の push である場合（安全）
  git push --force-with-lease origin {branch}

  # リモートに自分以外の変更がある場合
  # → マージまたは rebase で統合してから push
  git rebase origin/{branch}
  git push --force-with-lease origin {branch}
```

### detached HEAD 状態

```
症状:
  - git branch --show-current が空を返す
  - HEAD detached at {commit} と表示される

原因:
  - rebase 中に操作を誤った
  - 直接コミットハッシュをチェックアウトした

解決:
  # 現在の状態を確認
  git status
  git log --oneline -5

  # ブランチに戻る
  git checkout {branch-name}

  # 変更を失いたくない場合
  # 1. 現在の状態で新しいブランチを作成
  git checkout -b {temp-branch}
  # 2. 元のブランチに変更を cherry-pick
  git checkout {branch-name}
  git cherry-pick {commit-hash}
```

### rebase 中に同じコンフリクトが繰り返される

```
症状:
  - 同じファイルで何度もコンフリクトが発生する

原因:
  - 複数のコミットが同じファイルを変更している
  - rebase はコミット単位で適用するため、毎回コンフリクトする

解決:
  # rerere を有効化（Reuse Recorded Resolution）
  git config rerere.enabled true
  # → 一度解消したコンフリクトパターンを記憶する
  # → 同じパターンのコンフリクトを自動解消する

  # 代替策: squash してからrebase
  git rebase --abort
  git rebase -i {base-branch}
  # → 同じファイルを変更するコミットを squash で1つにまとめる
  # → まとめたコミットで rebase すればコンフリクトは1回で済む
```

## 環境関連の問題

### node_modules が壊れた

```
症状:
  - モジュールが見つからない
  - バージョン不整合のエラー

解決:
  # node_modules を削除して再インストール
  rm -rf node_modules
  pnpm install
  # or
  rm -rf node_modules package-lock.json && npm install
```

### .claude/ ディレクトリが欠落

```
症状:
  - CLAUDE.md の設定が反映されない
  - スラッシュコマンドが見つからない

原因:
  - worktree 作成後に .claude/ のコピーを忘れた

解決:
  # メインリポジトリから .claude/ をコピー
  cp -r {メインリポジトリパス}/.claude .claude

  # worktree からの相対パスでコピー（通常は2階層上）
  cp -r ../../.claude .claude
```

### MCP が登録されていない

```
症状:
  - Serena 等の MCP ツールが使えない

解決:
  # worktree ディレクトリで MCP を登録
  cd {worktreeパス}
  claude mcp add serena -- uvx --from git+https://github.com/oraios/serena \
    serena-mcp-server --context ide-assistant --project $(pwd)
```

### 環境変数が設定されていない

```
症状:
  - API キーが見つからない
  - データベース接続に失敗する

解決:
  # .env ファイルをコピー
  cp {メインリポジトリパス}/.env .env

  # 確認
  cat .env | head -5
```

## 復旧手順チートシート

| 症状 | 原因 | 解決コマンド |
|------|------|-------------|
| ブランチが二重チェックアウト | 別の worktree で使用中 | `git worktree list` → 使用中の worktree を特定 |
| worktree list に残骸が残る | rm -rf で手動削除した | `git worktree prune` |
| rebase が失敗し続ける | コンフリクトが複雑 | `git rebase --abort` → 戦略を見直し |
| force push が拒否される | リモートが更新済み | `git fetch origin` → 差分確認 → 再 push |
| HEAD が detached | rebase 中の操作ミス | `git checkout {branch-name}` |
| モジュールが見つからない | node_modules が古い | `rm -rf node_modules && pnpm install` |
| CLAUDE.md が反映されない | .claude/ が欠落 | `cp -r ../../.claude .claude` |
| MCP ツールが使えない | MCP 未登録 | `claude mcp add serena ...` |
| テストが通らない | 依存が未インストール | `pnpm install` / `go mod download` |
| worktree が locked | ロック状態 | `git worktree unlock {path}` |
