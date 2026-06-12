#!/usr/bin/env bash
# Install agent-setup skills into user scope for Claude Code and Codex.
# Idempotent: re-running fixes broken links; existing real dirs are backed up, never deleted.
# Usage: ./install.sh [--claude-only|--codex-only] [--dry-run]
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_SKILLS="$HOME/.claude/skills"
CODEX_SKILLS="$HOME/.codex/skills"
DRY_RUN=0
TARGETS=(claude codex)

for arg in "$@"; do
  case "$arg" in
    --claude-only) TARGETS=(claude) ;;
    --codex-only)  TARGETS=(codex) ;;
    --dry-run)     DRY_RUN=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

link_skill() {
  local src="$1" dest="$2" name
  name="$(basename "$src")"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    # Real file/dir in the way: back it up rather than destroy it.
    local bak="$dest.bak.$(date +%Y%m%d%H%M%S)"
    echo "  backup: $dest -> $bak"
    [ "$DRY_RUN" = 1 ] || mv "$dest" "$bak"
  fi
  echo "  link: $dest -> $src"
  [ "$DRY_RUN" = 1 ] || ln -sfn "$src" "$dest"
  # Verify the link actually resolves into this repo. Skills are directories,
  # so cd + pwd -P canonicalizes both sides portably (readlink -f is GNU-only).
  if [ "$DRY_RUN" = 0 ]; then
    local resolved expected
    resolved="$(cd "$dest" 2>/dev/null && pwd -P || true)"
    expected="$(cd "$src" && pwd -P)"
    if [ "$resolved" != "$expected" ]; then
      echo "  ERROR: $dest resolves to '$resolved' (expected $expected)" >&2
      exit 1
    fi
  fi
}

echo "repo: $REPO_DIR"
for target in "${TARGETS[@]}"; do
  case "$target" in
    claude) dest_dir="$CLAUDE_SKILLS" ;;
    codex)  dest_dir="$CODEX_SKILLS" ;;
  esac
  echo "[$target] -> $dest_dir"
  [ "$DRY_RUN" = 1 ] || mkdir -p "$dest_dir"
  for src in "$REPO_DIR"/skills/*/; do
    src="${src%/}"
    [ -f "$src/SKILL.md" ] || { echo "  skip (no SKILL.md): $src"; continue; }
    link_skill "$src" "$dest_dir/$(basename "$src")"
  done
done

echo "done. Per-skill runtime requirements (CLI tools, auth) are listed in each SKILL.md."
