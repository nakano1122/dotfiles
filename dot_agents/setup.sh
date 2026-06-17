#!/usr/bin/env bash
set -euo pipefail

# ~/.agents/ 配下の共通スキルを各エージェントから参照するためのシンボリックリンクを作成する

AGENTS_DIR="$HOME/.agents"
AGENTS_SKILLS="$AGENTS_DIR/skills"
CODEX_NATIVE_SKILLS="$HOME/.codex/skills"

GENSHIJIN_SKILLS=(
  "genshijin"
  "genshijin-commit"
  "genshijin-compress"
  "genshijin-crew"
  "genshijin-help"
  "genshijin-review"
  "genshijin-stats"
)

# 共通スキルディレクトリの存在確認
if [ ! -d "$AGENTS_SKILLS" ]; then
  echo "Error: $AGENTS_SKILLS が見つかりません。先に chezmoi apply を実行してください。" >&2
  exit 1
fi

# genshijin skills install
# chezmoi 管理下に存在しない場合、既存の Codex skills から ~/.agents/skills へ取り込む。
for skill in "${GENSHIJIN_SKILLS[@]}"; do
  target="$AGENTS_SKILLS/$skill"
  source="$CODEX_NATIVE_SKILLS/$skill"

  if [ -d "$target" ]; then
    echo "[genshijin]   $target は既に存在します。スキップします。"
  elif [ -d "$source" ]; then
    cp -R "$source" "$target"
    echo "[genshijin]   $source → $target をインストールしました。"
  else
    echo "Warning: $skill が見つかりません。必要な場合は genshijin skills を先に導入してください。" >&2
  fi
done

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
  current_target="$(readlink "$CODEX_AGENTS_MD")"
  if [ "$current_target" = "$AGENTS_MD" ] || [ "$current_target" = "../.agents/AGENTS.md" ]; then
    echo "[Codex CLI]   $CODEX_AGENTS_MD は既に正しいシンボリックリンクです。スキップします。"
  else
    ln -sfn "$AGENTS_MD" "$CODEX_AGENTS_MD"
    echo "[Codex CLI]   $CODEX_AGENTS_MD → $AGENTS_MD に更新しました。"
  fi
elif [ -e "$CODEX_AGENTS_MD" ]; then
  echo "Warning: $CODEX_AGENTS_MD が既に存在します（シンボリックリンクではありません）。手動で確認してください。" >&2
else
  ln -s "$AGENTS_MD" "$CODEX_AGENTS_MD"
  echo "[Codex CLI]   $CODEX_AGENTS_MD → $AGENTS_MD を作成しました。"
fi

echo ""
echo "セットアップ完了。"
