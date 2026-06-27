# Pi Agent GitHub gh skill

## Goal

Add a Pi Agent-only skill that gives Pi Agent GitHub operation workflows equivalent to Codex's GitHub helper behavior, but using the `gh` CLI instead of Codex's GitHub connector.

## Plan

1. Create `.pi/agent/skills/github-gh/SKILL.md`.
2. Keep the skill Pi-only instead of linking it into Claude Code or Codex.
3. Update `setup.sh` with a Pi Agent-only skill list and symlink management.
4. Run setup and verify `~/.pi/agent/skills/github-gh` points to the dotfiles skill.
5. Validate skill frontmatter and shell syntax.
6. Commit, merge to `master`, and push `origin/master`.
