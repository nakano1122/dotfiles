# worktree セットアップチェックリスト

worktree 作成直後に実行するセットアップ手順。環境の不備による作業中断を防ぐ。

## 目次

- [共通セットアップ（全プロジェクト共通）](#共通セットアップ（全プロジェクト共通）)
  - [1. .claude/ ディレクトリのコピー](#1-claude-ディレクトリのコピー)
  - [2. 環境変数ファイルの設定](#2-環境変数ファイルの設定)
  - [3. Serena MCP の登録](#3-serena-mcp-の登録)
- [言語/FW 別セットアップ](#言語fw-別セットアップ)
  - [Node.js (pnpm / npm / yarn)](#nodejs-pnpm-npm-yarn)
  - [Go](#go)
  - [Python](#python)
  - [モノレポ（pnpm ワークスペース）](#モノレポ（pnpm-ワークスペース）)
- [検証ステップ](#検証ステップ)
- [セットアップスクリプト例](#セットアップスクリプト例)

## 共通セットアップ（全プロジェクト共通）

### 1. .claude/ ディレクトリのコピー

```bash
cd .worktrees/{dir-name}

# .claude/ は gitignore 対象のため worktree に自動コピーされない
if [ -d "../../.claude" ]; then
    cp -r "../../.claude" ".claude"
fi
```

**コピーされるもの:**
- `.claude/CLAUDE.md` - プロジェクト固有の Claude 指示
- `.claude/rules/` - プロジェクトルール
- `.claude/settings.local.json` - ローカル設定
- `.claude/commands/` - カスタムスラッシュコマンド

**注意:**
- プロジェクトルート直下の `CLAUDE.md` は worktree の親ディレクトリ探索で自動ロードされるためコピー不要
- `.claude/` 配下の `CLAUDE.md` はコピーしないとロードされない

### 2. 環境変数ファイルの設定

```bash
# .env ファイルのコピー（gitignore 対象のため手動コピーが必要）
if [ -f "../../.env" ]; then
    cp "../../.env" ".env"
fi

# .env.local がある場合
if [ -f "../../.env.local" ]; then
    cp "../../.env.local" ".env.local"
fi
```

### 3. Serena MCP の登録

```bash
# MCP 設定は ~/.claude.json にディレクトリパス別で保存される
# worktree ごとに登録が必要
claude mcp add serena -- uvx --from git+https://github.com/oraios/serena \
  serena-mcp-server --context ide-assistant --project $(pwd)
```

## 言語/FW 別セットアップ

### Node.js (pnpm / npm / yarn)

```bash
# 依存関係のインストール
pnpm install
# or
npm install
# or
yarn install

# ビルドが必要な場合（モノレポの共有パッケージ等）
pnpm build
# or
pnpm -r build  # モノレポの全パッケージをビルド
```

**注意:**
- `node_modules/` は gitignore 対象のため worktree ごとにインストールが必要
- モノレポの場合、ルートで `pnpm install` すれば全ワークスペースにインストールされる
- ロックファイル（`pnpm-lock.yaml` 等）は git 管理されているため自動的に同期される

### Go

```bash
# 依存関係のダウンロード
go mod download

# ビルド確認
go build ./...
```

### Python

```bash
# 仮想環境の作成（プロジェクトに応じて）
python -m venv .venv
source .venv/bin/activate

# 依存関係のインストール
pip install -r requirements.txt
# or
pip install -e ".[dev]"
# or
poetry install
```

**注意:**
- 仮想環境（`.venv/`）は gitignore 対象のため worktree ごとに作成が必要
- Poetry の場合は `pyproject.toml` と `poetry.lock` が git 管理されている

### モノレポ（pnpm ワークスペース）

```bash
# ルートで依存関係をインストール
pnpm install

# 共有パッケージのビルド（依存順に）
pnpm --filter @repo/shared build
pnpm --filter @repo/ui build

# 特定のアプリのみビルド確認
pnpm --filter @repo/web build
```

## 検証ステップ

セットアップ完了後、以下を確認して作業を開始する:

```bash
# 1. 作業ディレクトリの確認
pwd
# → .worktrees/{dir-name} であること

# 2. ブランチの確認
git branch --show-current
# → 正しいタスクブランチであること

# 3. .claude/ の確認
ls .claude/
# → CLAUDE.md, rules/ 等が存在すること

# 4. lint/test の実行確認
pnpm lint   # or go vet ./... / flake8
pnpm test   # or go test ./... / pytest

# 5. 環境変数の確認（必要に応じて）
cat .env | head -5
# → 必要な変数が設定されていること
```

## セットアップスクリプト例

頻繁に worktree を作成する場合、以下のようなスクリプトを用意すると便利:

```bash
#!/bin/bash
# setup-worktree.sh
# Usage: ./setup-worktree.sh <dir-name>

DIR_NAME=$1
WORKTREE_PATH=".worktrees/${DIR_NAME}"

if [ ! -d "${WORKTREE_PATH}" ]; then
    echo "Error: worktree ${WORKTREE_PATH} does not exist"
    exit 1
fi

cd "${WORKTREE_PATH}"

# .claude/ コピー
if [ -d "../../.claude" ]; then
    cp -r "../../.claude" ".claude"
    echo "Copied .claude/"
fi

# .env コピー
if [ -f "../../.env" ]; then
    cp "../../.env" ".env"
    echo "Copied .env"
fi

# 依存関係インストール（package.json がある場合）
if [ -f "package.json" ]; then
    pnpm install
    echo "Installed dependencies"
fi

# Go の場合
if [ -f "go.mod" ]; then
    go mod download
    echo "Downloaded Go modules"
fi

# MCP 登録
claude mcp add serena -- uvx --from git+https://github.com/oraios/serena \
  serena-mcp-server --context ide-assistant --project $(pwd)
echo "Registered Serena MCP"

echo "Setup complete for ${WORKTREE_PATH}"
```
