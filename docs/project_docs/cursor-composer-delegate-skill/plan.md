# Cursor Composer 2 Delegate Skill 作成計画

## Summary
`boxp/dotfiles` に `delegate-to-cursor-composer` skill を追加し、Claude Code / Codex / Pi Agent から Cursor Agent CLI の Composer 2系モデルへ実装作業を委譲できるようにする。既存の `delegate-to-pi-agent` と同じ責務分離にし、委任元が prompt と PR body を用意し、委譲先は「実装、検証、commit、push、Draft PR作成」だけを行う。

## Key Changes
- 作業は `worktree` skill 方針に従い、`gwq add -b feature/cursor-composer-delegate-skill` の専用worktreeで行う。
- `.claude/skills/delegate-to-cursor-composer/SKILL.md` を追加し、Cursor Agent CLI 用の委譲手順を記述する。
- `.claude/skills/delegate-to-cursor-composer/agents/openai.yaml` を追加し、UI表示名、短い説明、default prompt、`policy.allow_implicit_invocation: false` を設定する。
- `setup.sh` の `ENABLED_CLAUDE_SKILLS` に `delegate-to-cursor-composer` を追加し、Claude Code / Pi Agent / Codex へ既存の symlink 同期方式で配布する。
- `docs/project_docs/cursor-composer-delegate-skill/plan.md` にこの計画を保存し、変更に含める。

## Skill Behavior
- 引数は `<session-name> <target-repo-or-worktree> <task-or-prompt-file>` とする。
- 委任前に対象repoで `git status --short --branch`、remote、現在branch、default branchを確認する。
- 委任元が `/tmp/cursor-composer-delegate/<session-name>/prompt.md` と `pr-body.md` を作成する。
- 既定モデルは環境で確認済みの `composer-2.5-fast` とし、必要時に `composer-2.5` へ変更可能と明記する。
- 起動コマンドは tmux 対話セッションを標準にする。
  ```bash
  tmux new-session -d -s <session-name> -c <target-repo-or-worktree>
  tmux send-keys -t <session-name> 'cursor-agent --model composer-2.5-fast --workspace "<target-repo-or-worktree>" --force @"<prompt-file>"' Enter
  ```
- prompt には task goal、repo/worktree path、base branch、working branch、成功条件、検証コマンド、PR title、PR body file path、Draft PR作成コマンドを必ず含める。
- 禁止事項は `delegate-to-pi-agent` と同じく、merge、close、branch delete、force-push、amend、Jira/チケットコメント、PR本文の創作的書き換えを禁止する。

## Test Plan
- `python3 /Users/keitaro.takeuchi/.codex/skills/.system/skill-creator/scripts/quick_validate.py .claude/skills/delegate-to-cursor-composer`
- `sh -n setup.sh`
- `./setup.sh` 実行後、以下の symlink を確認する。
  - `~/.claude/skills/delegate-to-cursor-composer`
  - `~/.codex/skills/delegate-to-cursor-composer`
  - `~/.pi/agent/skills/delegate-to-cursor-composer`
- `cursor-agent models` で `composer-2.5-fast` が存在することを確認する。
- 実PRを作らない範囲で、skill本文のコマンド、prompt雛形、禁止事項、完了確認手順をレビューする。

## Assumptions
- 「composer2モデル」は、この環境で利用可能な Cursor モデルID `composer-2.5-fast` / `composer-2.5` を指すものとして扱う。
- GUIのCursor Composerではなく、再現性とtmux監視性を優先して `cursor-agent` CLI を標準にする。
- 作成するPRは常に Draft PR とし、Jira/チケットにはコメントしない。
- dotfiles変更完了時は、ユーザーが明示的に止めない限り `master` へ反映し、`origin/master` へ push する。
