# delegate-to-pi-agent skill 作成計画

## Summary
`boxp/dotfiles` に `delegate-to-pi-agent` skill を追加し、Claude Code / Codex から Pi Agent へ「実装、push、Draft PR作成」だけを委任できるようにする。PR description は委任元が作成し、Pi Agent は渡された PR 本文テンプレートを使って Draft PR を作るだけに限定する。Pi Agent には絶対に merge / close / delete / force-push / Jira コメントをさせない。

参照方針は Codex manual の Skills / AGENTS.md / worktrees / non-interactive / approvals guidance と、Claude Code 公式 docs の Skills / CLI / subagents / common workflows に合わせる。

## Key Changes
- `.claude/skills/delegate-to-pi-agent/SKILL.md` を `skill-creator` の `init_skill.py` で作成し、instruction-only skill として実装する。
- `.claude/skills/delegate-to-pi-agent/agents/openai.yaml` を追加し、Codex UI 向けの `display_name` / `short_description` / `default_prompt` と `policy.allow_implicit_invocation: false` を設定する。
- `setup.sh` の `ENABLED_CLAUDE_SKILLS` に `delegate-to-pi-agent` を追加し、Claude Code、Pi Agent、Codex へ既存の symlink 同期方式で配布する。
- `docs/project_docs/pi-agent-delegate-skill/plan.md` にこの計画を保存し、dotfiles の変更として含める。
- 作業は `gwq add -b feature/pi-agent-delegate-skill` で専用 worktree を作って実施し、完了後は `master` に反映して `origin/master` へ push する。

## Skill Behavior
- 既定の起動方式は tmux 対話セッションにする。Pi Agent の長時間実装、権限確認、失敗時介入を監視しやすくするため。
- skill の引数は `<session-name> <target-repo-or-worktree> <task-or-prompt-file>` を基本形にする。足りない情報は repo 状態から補完し、補完不能な場合だけユーザーへ確認する。
- 委任元は Pi Agent 起動前に `/tmp/pi-agent-delegate/<session>/prompt.md` と `pr-body.md` を作る。
- Pi Agent への prompt には必ず以下を含める。
  - task goal、対象 repo、base branch、作業 branch、成功条件、検証コマンド
  - PR title と PR body file path
  - `gh pr create --draft --title ... --body-file ...` で Draft PR を作る指示
  - `gh pr merge`、merge button 操作、branch delete、issue close、Jira/チケットコメント、force-push、amend を禁止
  - PR 本文は委任元責任のため、指定された本文テンプレートを原則そのまま使い、許可された factual placeholder 以外は書き換えない
  - 変更前後に `git status --short --branch` を確認し、無関係な dirty work を触らない
- Pi Agent 起動コマンドは概ね次の形にする。
  `tmux new-session -d -s <session> -c <worktree>` の後、`pi --approve --name <session> --skill ~/.pi/agent/skills/github-gh @<prompt-file>` を送る。
- `~/.pi/agent/skills/github-gh` がない場合は、先に `./setup.sh` を実行して symlink を整える手順を skill 内に書く。

## Test Plan
- `python3 /Users/keitaro.takeuchi/.codex/skills/.system/skill-creator/scripts/quick_validate.py .claude/skills/delegate-to-pi-agent` を通す。
- `./setup.sh` を実行し、次の symlink を確認する。
  - `~/.claude/skills/delegate-to-pi-agent`
  - `~/.codex/skills/delegate-to-pi-agent`
  - `~/.pi/agent/skills/delegate-to-pi-agent`
- `sh -n setup.sh` を実行する。
- 実 PR を作らない範囲で、skill 本文の手順に従って session 名、prompt path、PR body path、禁止事項が漏れなく生成されるかレビューする。
- 最後に `git status --short --branch` で変更範囲を確認し、plan.md、skill、setup.sh だけが意図した変更であることを確認する。

## Assumptions
- skill 名は `delegate-to-pi-agent` とする。
- PR は既定で Draft PR にする。
- Pi Agent には既存の `github-gh` skill を併用させ、GitHub 操作は `gh` CLI に統一する。
- Claude Code 側の自動発火抑制は description で明示用途を絞り、Codex 側は `agents/openai.yaml` の `allow_implicit_invocation: false` で明示呼び出し中心にする。
- 参照資料:
  - https://developers.openai.com/codex/skills
  - https://developers.openai.com/codex/guides/agents-md
  - https://developers.openai.com/codex/noninteractive
  - https://developers.openai.com/codex/agent-approvals-security
  - https://developers.openai.com/codex/app/worktrees
  - https://code.claude.com/docs/en/skills
  - https://code.claude.com/docs/en/cli-reference
  - https://code.claude.com/docs/en/sub-agents
  - https://code.claude.com/docs/en/common-workflows
