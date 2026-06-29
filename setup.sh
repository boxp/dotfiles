#!/bin/sh

[ -e ~/.xmonad ] || ln -s ~/ghq/github.com/boxp/dotfiles/.xmonad ~/.xmonad
[ -e ~/.Xmodmap ] || ln -s ~/ghq/github.com/boxp/dotfiles/.Xmodmap ~/.Xmodmap
[ -e ~/.Xresources ] || ln -s ~/ghq/github.com/boxp/dotfiles/.Xresources ~/.Xresources
[ -e ~/.dein.toml ] || ln -s ~/ghq/github.com/boxp/dotfiles/.dein.toml ~/.dein.toml
[ -e ~/.dein_lazy.toml ] || ln -s ~/ghq/github.com/boxp/dotfiles/.dein_lazy.toml ~/.dein_lazy.toml
[ -e ~/.vimrc ] || ln -s ~/ghq/github.com/boxp/dotfiles/.vimrc ~/.vimrc
[ -e ~/.xmobarrc ] || ln -s ~/ghq/github.com/boxp/dotfiles/.xmobarrc ~/.xmobarrc
[ -e ~/.xsession ] || ln -s ~/ghq/github.com/boxp/dotfiles/.xsession ~/.xsession
[ -e ~/.zprofile ] || ln -s ~/ghq/github.com/boxp/dotfiles/.zprofile ~/.zprofile
[ -e ~/.zshrc ] || ln -s ~/ghq/github.com/boxp/dotfiles/.zshrc ~/.zshrc
[ -e ~/.tmux.conf ] || ln -s ~/ghq/github.com/boxp/dotfiles/.tmux.conf ~/.tmux.conf
[ -e ~/.mysnippets ] || ln -s ~/ghq/github.com/boxp/dotfiles/.mysnippets ~/.mysnippets
[ -e ~/.spacemacs ] || ln -s ~/ghq/github.com/boxp/dotfiles/.spacemacs ~/.spacemacs
[ -e ~/.aerospace.toml ] || ln -s ~/ghq/github.com/boxp/dotfiles/.aerospace.toml ~/.aerospace.toml
mkdir -p ~/.config
[ -e ~/.config/ghostty ] || ln -s ~/ghq/github.com/boxp/dotfiles/.config/ghostty ~/.config/ghostty
[ -e ~/.config/gwq ] || ln -s ~/ghq/github.com/boxp/dotfiles/.config/gwq ~/.config/gwq
mkdir -p ~/.codex
[ -e ~/.codex/AGENTS.md ] || ln -s ~/ghq/github.com/boxp/dotfiles/AGENTS.md ~/.codex/AGENTS.md
mkdir -p ~/.claude
[ -e ~/.claude/CLAUDE.md ] || ln -s ~/ghq/github.com/boxp/dotfiles/.claude/CLAUDE.md ~/.claude/CLAUDE.md
mkdir -p ~/.pi/agent
[ -e ~/.pi/agent/AGENTS.md ] || ln -s ~/ghq/github.com/boxp/dotfiles/AGENTS.md ~/.pi/agent/AGENTS.md
if [ -L ~/.claude/skills ] && [ "$(readlink ~/.claude/skills)" = "$HOME/ghq/github.com/boxp/dotfiles/.claude/skills" ]; then
  rm ~/.claude/skills
fi
mkdir -p ~/.claude/skills
mkdir -p ~/.pi/agent/skills
mkdir -p ~/.pi/agent/extensions

# Enable only the skills listed here (one symlink per skill).
ENABLED_CLAUDE_SKILLS="
claude-delegate
codex-exec
codex-review
codex-review-file
drawio-svg-preview
generate-image
generate-pixelart
end-of-day-ai-retro
multi-repo-dev
worktree
xai-web-search
xai-x-search
"

# Pi Agent-only skills, stored under .pi/agent/skills/ in this repository.
ENABLED_PI_AGENT_SKILLS="
github-gh
"

# Pi Agent extensions, stored under .pi/agent/extensions/ in this repository.
ENABLED_PI_AGENT_EXTENSIONS="
goal-harness.ts
"

# Skills that should NOT be symlinked to ~/.codex/skills/
# (e.g. skills that invoke codex CLI from Claude Code)
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

skill_is_enabled() {
  skill_name="$1"
  for enabled_skill in $ENABLED_CLAUDE_SKILLS; do
    [ "$enabled_skill" = "$skill_name" ] && return 0
  done
  return 1
}

skill_is_pi_enabled() {
  skill_name="$1"
  skill_is_enabled "$skill_name" && return 0
  for enabled_skill in $ENABLED_PI_AGENT_SKILLS; do
    [ "$enabled_skill" = "$skill_name" ] && return 0
  done
  return 1
}

for skill_link in "$HOME/.claude/skills"/*; do
  [ -L "$skill_link" ] || continue
  skill_name="${skill_link##*/}"
  skill_is_enabled "$skill_name" && continue
  skill_target="$(readlink "$skill_link")"
  case "$skill_target" in
    "$HOME/ghq/github.com/boxp/dotfiles/.claude/skills/"*)
      rm "$skill_link"
      ;;
  esac
done

for skill_name in $ENABLED_CLAUDE_SKILLS; do
  src="$HOME/ghq/github.com/boxp/dotfiles/.claude/skills/$skill_name"
  dst="$HOME/.claude/skills/$skill_name"
  [ -d "$src" ] || continue
  [ -e "$dst" ] || ln -s "$src" "$dst"
done

for skill_link in "$HOME/.pi/agent/skills"/*; do
  [ -L "$skill_link" ] || continue
  skill_name="${skill_link##*/}"
  skill_is_pi_enabled "$skill_name" && continue
  skill_target="$(readlink "$skill_link")"
  case "$skill_target" in
    "$HOME/.claude/skills/"*|"$HOME/ghq/github.com/boxp/dotfiles/.claude/skills/"*|"$HOME/ghq/github.com/boxp/dotfiles/.pi/agent/skills/"*)
      rm "$skill_link"
      ;;
  esac
done

for skill_name in $ENABLED_CLAUDE_SKILLS; do
  src="$HOME/.claude/skills/$skill_name"
  dst="$HOME/.pi/agent/skills/$skill_name"
  [ -d "$src" ] || continue
  [ -e "$dst" ] || ln -s "$src" "$dst"
done

for skill_name in $ENABLED_PI_AGENT_SKILLS; do
  src="$HOME/ghq/github.com/boxp/dotfiles/.pi/agent/skills/$skill_name"
  dst="$HOME/.pi/agent/skills/$skill_name"
  [ -d "$src" ] || continue
  [ -e "$dst" ] || ln -s "$src" "$dst"
done

for extension_link in "$HOME/.pi/agent/extensions"/*; do
  [ -L "$extension_link" ] || continue
  extension_name="${extension_link##*/}"
  extension_is_enabled=false
  for enabled_extension in $ENABLED_PI_AGENT_EXTENSIONS; do
    if [ "$enabled_extension" = "$extension_name" ]; then
      extension_is_enabled=true
      break
    fi
  done
  $extension_is_enabled && continue
  extension_target="$(readlink "$extension_link")"
  case "$extension_target" in
    "$HOME/ghq/github.com/boxp/dotfiles/.pi/agent/extensions/"*)
      rm "$extension_link"
      ;;
  esac
done

for extension_name in $ENABLED_PI_AGENT_EXTENSIONS; do
  src="$HOME/ghq/github.com/boxp/dotfiles/.pi/agent/extensions/$extension_name"
  dst="$HOME/.pi/agent/extensions/$extension_name"
  [ -f "$src" ] || continue
  if [ -f "$dst" ] && [ ! -L "$dst" ] && cmp -s "$src" "$dst"; then
    rm "$dst"
  fi
  [ -e "$dst" ] || ln -s "$src" "$dst"
done

mkdir -p ~/.codex/skills
for skill_link in "$HOME/.codex/skills"/*; do
  [ -L "$skill_link" ] || continue
  skill_name="${skill_link##*/}"
  skill_is_enabled "$skill_name" && continue
  skill_target="$(readlink "$skill_link")"
  case "$skill_target" in
    "$HOME/.claude/skills/"*)
      rm "$skill_link"
      ;;
  esac
done

for skill_dir in "$HOME/.claude/skills"/*; do
  [ -d "$skill_dir" ] || continue
  skill_name="${skill_dir##*/}"
  skill_is_codex_excluded "$skill_name" && continue
  [ -e "$HOME/.codex/skills/$skill_name" ] || ln -s "$skill_dir" "$HOME/.codex/skills/$skill_name"
done
