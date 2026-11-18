---
name: obsidian-task-board
description: Claude / Codex / Pi Agent / hermes-agent workflow for safely listing, showing, creating, updating, deleting, and requesting Codex work for the Obsidian Task Board. Use when the user asks to operate BOXP tickets, Boards/Task Board.md, or Tickets/BOXP-*.md.
---

# Obsidian Task Board

Use this skill only through the bundled helper script. Do not manually edit `Boards/Task Board.md` or `Tickets/BOXP-*.md` unless the helper reports an unrecoverable format problem.

Default vault:

```bash
/home/boxp/Documents/obsidian-headless/BOXP
```

Helper:

```bash
if [ -x "$HOME/.claude/skills/obsidian-task-board/bin/task-board.bb" ]; then
  TASK_BOARD_HELPER="$HOME/.claude/skills/obsidian-task-board/bin/task-board.bb"
elif [ -x "$HOME/.codex/skills/obsidian-task-board/bin/task-board.bb" ]; then
  TASK_BOARD_HELPER="$HOME/.codex/skills/obsidian-task-board/bin/task-board.bb"
elif [ -x "$HOME/.pi/agent/skills/obsidian-task-board/bin/task-board.bb" ]; then
  TASK_BOARD_HELPER="$HOME/.pi/agent/skills/obsidian-task-board/bin/task-board.bb"
else
  TASK_BOARD_HELPER="$HOME/ghq/github.com/boxp/dotfiles/.claude/skills/obsidian-task-board/bin/task-board.bb"
fi
```

## Safety Rules

- Treat the Task Board lane as the source of truth for ticket status.
- Keep ticket frontmatter `status` and board card `status::` synchronized with the lane.
- Preserve unspecified ticket fields and existing `## Notes` content.
- Use `--dry-run` before destructive or broad changes.
- `delete` requires `--dry-run` or `--confirm`; prefer dry-run first and report the affected ticket file and board card.
- Do not move Codex requests to `In Progress`. The runner owns that transition.

## Commands

List tickets:

```bash
"$TASK_BOARD_HELPER" list --vault /home/boxp/Documents/obsidian-headless/BOXP --json
"$TASK_BOARD_HELPER" list --vault /home/boxp/Documents/obsidian-headless/BOXP --lane Ready --json
```

Show a ticket:

```bash
"$TASK_BOARD_HELPER" show BOXP-55 --vault /home/boxp/Documents/obsidian-headless/BOXP --json
```

Create a ticket:

```bash
"$TASK_BOARD_HELPER" create \
  --vault /home/boxp/Documents/obsidian-headless/BOXP \
  --title "Short title" \
  --summary "What should be achieved." \
  --lane Backlog \
  --priority medium \
  --assignee boxp \
  --dry-run
```

Update only explicit fields:

```bash
"$TASK_BOARD_HELPER" update BOXP-55 \
  --vault /home/boxp/Documents/obsidian-headless/BOXP \
  --priority high \
  --assignee boxp \
  --summary-file /tmp/summary.md \
  --dry-run
```

Append a timestamped note without deleting existing Notes:

```bash
"$TASK_BOARD_HELPER" append-note BOXP-55 \
  --vault /home/boxp/Documents/obsidian-headless/BOXP \
  --source hermes-agent \
  --note "追加調査条件を確認した。"
```

Request Codex work while preserving the stop lane:

```bash
"$TASK_BOARD_HELPER" request-codex BOXP-55 \
  --vault /home/boxp/Documents/obsidian-headless/BOXP \
  --lane Ready \
  --note "レビュー指摘に対応して。CI と codex-review も確認する。" \
  --dry-run
```

Delete dry-run:

```bash
"$TASK_BOARD_HELPER" delete BOXP-55 \
  --vault /home/boxp/Documents/obsidian-headless/BOXP \
  --dry-run
```

## Codex Request Workflow

- Backlog: requirements grooming request. Keep the card in `Backlog`, set `assignee: codex`, and append the request to Notes.
- Ready: implementation start request. Keep the card in `Ready`, set `assignee: codex`, and append the request to Notes.
- Blocked: retry or blocker re-check request. Keep the card in `Blocked`, set `assignee: codex`, and append the new condition to Notes.

Lane contract (BOXP-395): there is no Review lane. PR code review and the runner's gates remain.

- Ready: approved and runnable, with an assignee and a next action.
- In Progress: actual work, including code review, fixes, merge, and approved deployment and verification. A run ending does not end the work.
- Blocked: cannot continue alone (new Owner decision, owner-only acceptance, missing permission, external dependency, unrecoverable failure or retry limit). Notes must give the reason, required input, who resolves it, and the next action. `PR created`, `reported`, or fixable review findings are not blockers.
- Done: the original goal is demonstrated. A merge alone is not deployment or acceptance. Work closed as obsolete or moved to a successor says so with the reason and successor.

The Task Board runner specification is the operational source for lane behavior:

```text
Projects/codex-task-board-runner/spec.md
```

## Conditions（作業中ずっと有効な条件）

承認の範囲、してはいけないこと、他票との取決め、止める条件など、後の run にも守らせることは Notes に書くだけにせず、票の `## Conditions` 節に項目（`CD-NN`）として登録する（BOXP-588）。Notes は経緯の記録として今までどおり残す。

この節は `task-board.bb` ではなく `task_board_todos.bb` で操作する。codex-workspace では `/opt/codex-workspace/task-board/task_board_todos.bb`、Hermes では skill の `bin/task_board_todos.bb` にある。helper が無い環境では登録せず、Notes に書いて Hermes か runner の担当に登録を頼む。

```bash
TODOS=/opt/codex-workspace/task-board/task_board_todos.bb
bb "$TODOS" conditions list BOXP-55 --vault /home/boxp/Documents/obsidian-headless/BOXP
bb "$TODOS" conditions add BOXP-55 --vault /home/boxp/Documents/obsidian-headless/BOXP \
  --kind 制約 --text "本番の設定は変えない" --source claude
bb "$TODOS" conditions cancel BOXP-55 CD-01 --vault /home/boxp/Documents/obsidian-headless/BOXP \
  --reason "作業が終わった" --source claude
```

- 種別は `承認`（Owner が許した範囲）、`制約`（してはいけないこと・範囲の限定）、`要確認`（今も有効か分からない。制約として扱う）、`取消`（無効。行は残る）。
- `承認` の登録と、Owner 由来の項目の取消は Owner の経路（Hermes）が行う。runner が起動した担当の process（`CODEX_TASK_BOARD_RUN_ID` がある）からは命令が拒否するので、blocked を返して Owner に渡す。
- 項目は新しい権限を与えない。他の節と食い違うときは狭い方に従う。
- 内容を変えるときは新しい項目を登録してから古い項目を取り消す。`## Conditions` 節の行を手で消したり書き換えたりしない。節には項目行とその子の行だけを書く。
- 登録と取消は票の TODO の版（rev）を変える。作業中の担当には次のツール境界で届く。
- 読めない行や、Owner の返答（`reply_id` / `event`）が無い `承認` が節にある間は、runner の担当の done は保留になり、merge・配備は拒否される。
- 登録しても prompt から Notes が省かれることはない（現時点）。

詳しい規則は boxp/arch の `docker/hermes-agent/skills/obsidian-task-board/SKILL.md` と `docs/project_docs/BOXP-588/plan.md` にある。

## Failure Handling

If the helper refuses a change, report the exact command and error. Common causes are missing ticket files, malformed frontmatter delimiters, missing board lanes, or multiple board cards for one ticket. Prefer `show` and `list --json` to inspect state before retrying.


## Hermes での実行

Hermes への `kubectl exec` は root で動くため、書き込み系コマンドは `--dry-run` を含め拒否されます。root が lock や vault のファイルを作ると gateway が書き込めなくなるためです。次のように Hermes ユーザーに切り替えて実行してください。

```sh
kubectl -n hermes-agent exec deploy/hermes-agent -c hermes-agent -- /command/s6-setuidgid hermes bb /opt/data/skills/note-taking/obsidian-task-board/bin/task-board.bb <command> ...
```

`--vault "$OBSIDIAN_VAULT_PATH"` を指定する場合は、変数をコンテナ内のシェルで展開します（例: `kubectl ... -- sh -c 'exec /command/s6-setuidgid hermes bb /opt/data/skills/note-taking/obsidian-task-board/bin/task-board.bb list --vault "$OBSIDIAN_VAULT_PATH"'`）。
