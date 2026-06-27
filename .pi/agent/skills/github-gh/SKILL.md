---
name: github-gh
description: GitHub operations through the gh CLI for Pi Agent. Use when the user asks Pi Agent to inspect repositories, issues, pull requests, review comments, GitHub Actions checks/logs, releases, labels, or to create/update PRs using local git and `gh` commands.
---

# GitHub gh

Use `gh` as the primary GitHub interface. Prefer explicit repository context and local git state over assumptions.

## First Checks

1. Verify authentication when a GitHub command may require network or private repo access:
   ```bash
   gh auth status
   ```
2. Resolve repository context:
   ```bash
   git remote -v
   git branch --show-current
   gh repo view --json nameWithOwner,url,defaultBranchRef
   ```
3. If the user references "this PR" or "current branch", discover it from the branch:
   ```bash
   gh pr status
   gh pr view --json number,title,url,state,headRefName,baseRefName
   ```

Ask for `owner/repo` only when neither the user request nor local checkout identifies the target.

## Common Tasks

### Repository and Issue Triage

Use:
```bash
gh repo view OWNER/REPO --json nameWithOwner,description,url,defaultBranchRef
gh issue list --repo OWNER/REPO --state open --limit 20
gh issue view ISSUE --repo OWNER/REPO --comments
```

For summaries, report the target repo, item numbers, state, and the concrete next action.

### Pull Request Inspection

Use:
```bash
gh pr list --repo OWNER/REPO --state open --limit 20
gh pr view PR --repo OWNER/REPO --comments --json number,title,url,state,author,headRefName,baseRefName,reviewDecision,statusCheckRollup
gh pr diff PR --repo OWNER/REPO
```

When reviewing comments or requested changes, inspect comments before proposing code changes. If line-level review thread state is needed and `gh pr view` is insufficient, use `gh api graphql` with the PR node.

### GitHub Actions and CI

Use `gh` for checks and logs:
```bash
gh pr checks PR --repo OWNER/REPO
gh run list --repo OWNER/REPO --branch BRANCH --limit 10
gh run view RUN_ID --repo OWNER/REPO --log-failed
```

For CI fixes, identify the failing job and exact error before editing files. Do not infer the cause from check names alone.

### Publishing Local Changes

Before creating commits or PRs:
```bash
git status --short --branch
git diff
```

Keep unrelated user changes out of commits. Commit only the files needed for the request.

Publish with:
```bash
git add PATHS
git commit -m "Message"
git push -u origin BRANCH
gh pr create --draft --title "Title" --body "Body"
```

### Updating an existing PR

When a PR already exists for the branch, push new commits as separate commits (do NOT use `git commit --amend` or `--force` unless the user explicitly asks):

```bash
git add PATHS
git commit -m "fixup: description"  # or descriptive message
git push origin BRANCH
```

Then update the PR title/description if needed:
```bash
gh pr edit PR --title "Title" --body "Body"
```

For CI reruns:
```bash
github run rerun RUN_ID --repo OWNER/REPO --failed
```

### Comments, Labels, and Reviews

Use targeted commands:
```bash
gh pr comment PR --repo OWNER/REPO --body "..."
gh issue comment ISSUE --repo OWNER/REPO --body "..."
gh issue edit ISSUE --repo OWNER/REPO --add-label "label"
gh pr review PR --repo OWNER/REPO --comment --body "..."
```

Before write actions, restate the exact target and action unless the user already gave an unambiguous command.

## Safety Rules

- Never use `--force` or `--force-with-lease` unless the user explicitly asks for it.
- **Never use `git commit --amend` to update existing PRs.** Push new commits instead.
- Do not close, merge, delete branches, edit labels, or submit reviews without clear user intent.
- Prefer JSON output for parsing and summaries.
- Preserve local dirty work that is unrelated to the requested GitHub operation.
- If `gh` fails from authentication, network, or permission errors, report the exact blocker and the command that failed.
