# Pi Agent skills and AGENTS.md setup

## Goal

Codex and Claude Code already receive shared local instructions and skills from this dotfiles repository. Pi Agent should receive the same global instructions and enabled skills through `setup.sh`.

## Plan

1. Add `~/.pi/agent/AGENTS.md` setup as a symlink to the repository `AGENTS.md`.
2. Create `~/.pi/agent/skills` during setup.
3. Reuse `ENABLED_CLAUDE_SKILLS` so Pi Agent receives the same enabled skill set as Claude Code.
4. Remove stale Pi Agent skill symlinks managed by this repository when they are no longer enabled.
5. Verify Pi Agent documentation paths:
   - global context file: `~/.pi/agent/AGENTS.md`
   - global skills directory: `~/.pi/agent/skills/`
6. Run `setup.sh` and confirm the resulting Pi Agent symlinks.
