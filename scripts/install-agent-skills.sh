#!/bin/sh

set -eu

REPO="boxp/dotfiles"
REPO_ROOT="$HOME/ghq/github.com/boxp/dotfiles"
CLAUDE_AGENT="claude-code"
CODEX_AGENT="codex"
CLAUDE_SKILL_DIR="$HOME/.claude/skills"
CODEX_SKILL_DIR="$HOME/.codex/skills"

ENABLED_CLAUDE_SKILLS="
boxp-obsidian-search
claude-delegate
codex-exec
codex-review
codex-review-file
generate-image
generate-pixelart
multi-repo-dev
worktree
xai-web-search
xai-x-search
"

CODEX_EXCLUDED_SKILLS="
codex-exec
"

skill_is_codex_excluded() {
  skill_name="$1"
  for excluded_skill in $CODEX_EXCLUDED_SKILLS; do
    [ "$excluded_skill" = "$skill_name" ] && return 0
  done
  return 1
}

cleanup_legacy_skill_dir() {
  skill_dir="$1"
  [ -L "$skill_dir" ] || return 0

  skill_target="$(readlink "$skill_dir")"
  case "$skill_target" in
    "$REPO_ROOT/.claude/skills"|"$REPO_ROOT/skills")
      rm "$skill_dir"
      ;;
  esac
}

cleanup_legacy_skill_link() {
  skill_link="$1"
  [ -L "$skill_link" ] || return 0

  skill_target="$(readlink "$skill_link")"
  case "$skill_target" in
    "$REPO_ROOT/.claude/skills/"*|"$REPO_ROOT/skills/"*|"$CLAUDE_SKILL_DIR/"*)
      rm "$skill_link"
      ;;
  esac
}

install_skill() {
  skill_name="$1"
  agent_name="$2"
  agent_dir="$3"

  cleanup_legacy_skill_link "$agent_dir/$skill_name"
  if [ -e "$agent_dir/$skill_name" ]; then
    printf '%s already present for %s, skipping install\n' "$skill_name" "$agent_name"
    return 0
  fi

  printf 'Installing %s for %s\n' "$skill_name" "$agent_name"
  gh skill install "$REPO" "$skill_name" --agent "$agent_name" --scope user
}

if ! command -v gh >/dev/null 2>&1 || ! gh skill --help >/dev/null 2>&1; then
  echo "gh skill is unavailable. Update GitHub CLI to v2.90.0+ and rerun this script." >&2
  exit 1
fi

mkdir -p "$HOME/.claude" "$HOME/.codex"
cleanup_legacy_skill_dir "$CLAUDE_SKILL_DIR"
cleanup_legacy_skill_dir "$CODEX_SKILL_DIR"
mkdir -p "$CLAUDE_SKILL_DIR" "$CODEX_SKILL_DIR"

for skill_name in $ENABLED_CLAUDE_SKILLS; do
  install_skill "$skill_name" "$CLAUDE_AGENT" "$CLAUDE_SKILL_DIR"
  skill_is_codex_excluded "$skill_name" && continue
  install_skill "$skill_name" "$CODEX_AGENT" "$CODEX_SKILL_DIR"
done
