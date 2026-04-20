This repository publishes personal skills for `gh skill`.

The source of truth lives in `skills/<skill-name>/`. The checked-in `.claude/skills`
path is a compatibility symlink for local project discovery only.

Requirements:
- GitHub CLI `v2.90.0` or later
- `gh skill` available in the current installation

Examples:

```bash
gh skill install boxp/dotfiles worktree --agent claude-code --scope user
gh skill install boxp/dotfiles worktree --agent codex --scope user
gh skill update --all
```

Bootstrap all dotfiles-managed skills with:

```bash
./scripts/install-agent-skills.sh
```

The bootstrap script removes only the legacy symlinks previously created from this
dotfiles repository, then installs missing skills through `gh skill`.
