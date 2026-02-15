#!/usr/bin/env bash
set -euo pipefail

# ~/.agents/ 配下の共通スキルを各エージェントから参照するためのシンボリックリンクを作成する

AGENTS_DIR="$HOME/.agents"
AGENTS_SKILLS="$AGENTS_DIR/skills"

# 共通スキルディレクトリの存在確認
if [ ! -d "$AGENTS_SKILLS" ]; then
  echo "Error: $AGENTS_SKILLS が見つかりません。先に chezmoi apply を実行してください。" >&2
  exit 1
fi

# --- Claude Code ---
CLAUDE_DIR="$HOME/.claude"
CLAUDE_SKILLS="$CLAUDE_DIR/skills"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
AGENTS_CLAUDE_MD="$AGENTS_DIR/CLAUDE.md"

mkdir -p "$CLAUDE_DIR"

# skills symlink
if [ -L "$CLAUDE_SKILLS" ]; then
  echo "[Claude Code] $CLAUDE_SKILLS は既にシンボリックリンクです。スキップします。"
elif [ -e "$CLAUDE_SKILLS" ]; then
  echo "Warning: $CLAUDE_SKILLS が既に存在します（シンボリックリンクではありません）。手動で確認してください。" >&2
else
  ln -s "$AGENTS_SKILLS" "$CLAUDE_SKILLS"
  echo "[Claude Code] $CLAUDE_SKILLS → $AGENTS_SKILLS を作成しました。"
fi

# CLAUDE.md symlink
if [ -L "$CLAUDE_MD" ]; then
  echo "[Claude Code] $CLAUDE_MD は既にシンボリックリンクです。スキップします。"
elif [ -e "$CLAUDE_MD" ]; then
  echo "Warning: $CLAUDE_MD が既に存在します（シンボリックリンクではありません）。手動で確認してください。" >&2
else
  ln -s "$AGENTS_CLAUDE_MD" "$CLAUDE_MD"
  echo "[Claude Code] $CLAUDE_MD → $AGENTS_CLAUDE_MD を作成しました。"
fi

# --- Codex CLI ---
CODEX_DIR="$HOME/.codex"
CODEX_SKILLS="$CODEX_DIR/skills"
CODEX_AGENTS_MD="$CODEX_DIR/AGENTS.md"
AGENTS_MD="$AGENTS_DIR/AGENTS.md"

mkdir -p "$CODEX_DIR"

# skills symlink
if [ -L "$CODEX_SKILLS" ]; then
  echo "[Codex CLI]   $CODEX_SKILLS は既にシンボリックリンクです。スキップします。"
elif [ -e "$CODEX_SKILLS" ]; then
  echo "Warning: $CODEX_SKILLS が既に存在します（シンボリックリンクではありません）。手動で確認してください。" >&2
else
  ln -s "$AGENTS_SKILLS" "$CODEX_SKILLS"
  echo "[Codex CLI]   $CODEX_SKILLS → $AGENTS_SKILLS を作成しました。"
fi

# AGENTS.md symlink
if [ -L "$CODEX_AGENTS_MD" ]; then
  echo "[Codex CLI]   $CODEX_AGENTS_MD は既にシンボリックリンクです。スキップします。"
elif [ -e "$CODEX_AGENTS_MD" ]; then
  echo "Warning: $CODEX_AGENTS_MD が既に存在します（シンボリックリンクではありません）。手動で確認してください。" >&2
else
  ln -s "$AGENTS_MD" "$CODEX_AGENTS_MD"
  echo "[Codex CLI]   $CODEX_AGENTS_MD → $AGENTS_MD を作成しました。"
fi

echo ""
echo "セットアップ完了。"
