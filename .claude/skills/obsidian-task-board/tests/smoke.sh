#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/bin/task-board.bb"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/Boards" "$TMP/Tickets"

cat > "$TMP/Boards/Task Board.md" <<'BOARD'
# Task Board

## Backlog

- [ ] [[Tickets/BOXP-1|BOXP-1: Existing backlog]] #ticket status::backlog priority::medium assignee::boxp
- [ ] [[Tickets/BOXP-4|BOXP-4: Multi repo]] #ticket status::backlog priority::medium repo::boxp/a repo::boxp/b

## Ready

## In Progress

## Review

## Blocked

## Done
BOARD

cat > "$TMP/Tickets/BOXP-1.md" <<'TICKET'
---
id: BOXP-1
type: task
status: backlog
priority: medium
assignee: boxp
reporter: boxp
project: BOXP
epic:
sprint:
repo:
estimate:
created: 2026-07-01
due:
closed:
tags:
  - ticket
---

# BOXP-1: Existing backlog

## Summary

Original summary.

## Acceptance Criteria

- [ ] Keep this.

## Context

- Existing context.

## Plan

- [ ] Existing plan.

## Notes

Original note stays.
TICKET

cat > "$TMP/Tickets/BOXP-4.md" <<'TICKET'
---
id: BOXP-4
type: task
status: backlog
priority: medium
assignee: boxp
reporter: boxp
project: BOXP
epic:
sprint:
repo: boxp/a, boxp/b
estimate:
created: 2026-07-01
due:
closed:
tags:
  - ticket
---

# BOXP-4: Multi repo

## Summary

Original summary.
TICKET

assert_contains() {
  local file="$1"
  local expected="$2"
  if ! grep -Fq -- "$expected" "$file"; then
    echo "Expected '$expected' in $file" >&2
    exit 1
  fi
}

before_dry_run="$(sha256sum "$TMP/Boards/Task Board.md" "$TMP/Tickets/BOXP-1.md")"
"$BIN" create --vault "$TMP" --title "Dry run only" --summary "No write" --lane Backlog --dry-run --json >/tmp/task-board-create-dry-run.json
after_dry_run="$(sha256sum "$TMP/Boards/Task Board.md" "$TMP/Tickets/BOXP-1.md")"
[[ "$before_dry_run" == "$after_dry_run" ]]

"$BIN" create --vault "$TMP" --title "New task" --summary "Created summary." --lane Ready --priority high --assignee boxp --json >/tmp/task-board-create.json
assert_contains "$TMP/Tickets/BOXP-5.md" "id: BOXP-5"
assert_contains "$TMP/Tickets/BOXP-5.md" "status: ready"
assert_contains "$TMP/Boards/Task Board.md" "[[Tickets/BOXP-5|BOXP-5: New task]]"
assert_contains "$TMP/Boards/Task Board.md" "status::ready"

"$BIN" create --vault "$TMP" --title "Section task" --summary "Section summary." --acceptance "Custom acceptance." --context "Custom context." --plan "Custom plan." --notes "Custom notes." --lane Backlog --json >/tmp/task-board-create-sections.json
assert_contains "$TMP/Tickets/BOXP-6.md" "Custom acceptance."
assert_contains "$TMP/Tickets/BOXP-6.md" "Custom context."
assert_contains "$TMP/Tickets/BOXP-6.md" "Custom plan."
assert_contains "$TMP/Tickets/BOXP-6.md" "Custom notes."

rm "$TMP/Tickets/BOXP-5.md"
"$BIN" create --vault "$TMP" --title "After board only" --summary "Created summary." --lane Backlog --json >/tmp/task-board-create-after-board-only.json
assert_contains "$TMP/Tickets/BOXP-7.md" "id: BOXP-7"
assert_contains "$TMP/Boards/Task Board.md" "[[Tickets/BOXP-5|BOXP-5: New task]]"
assert_contains "$TMP/Boards/Task Board.md" "[[Tickets/BOXP-7|BOXP-7: After board only]]"

"$BIN" create --vault "$TMP" --title "Bracket ] task" --summary "Created summary." --lane Backlog --json >/tmp/task-board-create-bracket.json
assert_contains "$TMP/Tickets/BOXP-8.md" "# BOXP-8: Bracket ] task"
assert_contains "$TMP/Boards/Task Board.md" "[[Tickets/BOXP-8|BOXP-8: Bracket \\] task]]"
"$BIN" list --vault "$TMP" --lane Backlog --json >/tmp/task-board-list-bracket.json
assert_contains /tmp/task-board-list-bracket.json '"title":"Bracket ] task"'

"$BIN" create --vault "$TMP" --title "Already done" --summary "Created done." --lane Done --json >/tmp/task-board-create-done.json
assert_contains "$TMP/Tickets/BOXP-9.md" "id: BOXP-9"
create_done_date="$(grep -F "BOXP-9: Already done" "$TMP/Boards/Task Board.md" | sed -n 's/.*done::\([^ ]*\).*/\1/p')"
assert_contains "$TMP/Tickets/BOXP-9.md" "closed: $create_done_date"
"$BIN" request-codex BOXP-9 --vault "$TMP" --lane Ready --note "Reopen done ticket." --json >/tmp/task-board-request-done-ticket.json
assert_contains "$TMP/Tickets/BOXP-9.md" "status: ready"
grep -Fxq "closed:" "$TMP/Tickets/BOXP-9.md"

"$BIN" update BOXP-4 --vault "$TMP" --summary "Multi repo updated." --json >/tmp/task-board-multi-repo-update.json
assert_contains "$TMP/Boards/Task Board.md" "BOXP-4: Multi repo]] #ticket status::backlog priority::medium assignee::boxp repo::boxp/a repo::boxp/b"

"$BIN" update BOXP-1 --vault "$TMP" --summary "Updated summary." --priority high --json >/tmp/task-board-update.json
assert_contains "$TMP/Tickets/BOXP-1.md" "Updated summary."
assert_contains "$TMP/Tickets/BOXP-1.md" "Original note stays."
assert_contains "$TMP/Tickets/BOXP-1.md" "priority: high"
assert_contains "$TMP/Boards/Task Board.md" "BOXP-1: Existing backlog]] #ticket status::backlog priority::high assignee::boxp"

"$BIN" update BOXP-1 --vault "$TMP" --lane Done --json >/tmp/task-board-done.json
assert_contains "$TMP/Boards/Task Board.md" "BOXP-1: Existing backlog]] #ticket status::done priority::high assignee::boxp done::"
assert_contains "$TMP/Tickets/BOXP-1.md" "closed:"
done_date="$(grep -F "BOXP-1: Existing backlog" "$TMP/Boards/Task Board.md" | sed -n 's/.*done::\\([^ ]*\\).*/\\1/p')"
assert_contains "$TMP/Tickets/BOXP-1.md" "closed: $done_date"
"$BIN" update BOXP-1 --vault "$TMP" --summary "Updated done summary." --json >/tmp/task-board-done-update.json
assert_contains "$TMP/Boards/Task Board.md" "done::$done_date"
assert_contains "$TMP/Tickets/BOXP-1.md" "closed: $done_date"
"$BIN" update BOXP-1 --vault "$TMP" --lane Backlog --json >/tmp/task-board-backlog.json
if grep -Fq "closed: $done_date" "$TMP/Tickets/BOXP-1.md"; then
  echo "closed date remained after reopening" >&2
  exit 1
fi
grep -Fxq "closed:" "$TMP/Tickets/BOXP-1.md"

"$BIN" append-note BOXP-1 --vault "$TMP" --source hermes-agent --note "Appended note." --json >/tmp/task-board-note.json
assert_contains "$TMP/Tickets/BOXP-1.md" "Original note stays."
assert_contains "$TMP/Tickets/BOXP-1.md" "[hermes-agent]: Appended note."

"$BIN" request-codex BOXP-1 --vault "$TMP" --lane Review --note "Address review feedback." --json >/tmp/task-board-request.json
assert_contains "$TMP/Tickets/BOXP-1.md" "status: review"
assert_contains "$TMP/Tickets/BOXP-1.md" "assignee: codex"
assert_contains "$TMP/Tickets/BOXP-1.md" "[codex request]: Address review feedback."
assert_contains "$TMP/Boards/Task Board.md" "## Review"
assert_contains "$TMP/Boards/Task Board.md" "BOXP-1: Existing backlog]] #ticket status::review priority::high assignee::codex"

if "$BIN" request-codex BOXP-1 --vault "$TMP" --lane "In Progress" --note "Should fail." --json >/tmp/task-board-request-in-progress.json 2>&1; then
  echo "request-codex accepted In Progress" >&2
  exit 1
fi

if "$BIN" request-codex BOXP-1 --vault "$TMP" --lane Done --note "Should fail." --json >/tmp/task-board-request-done.json 2>&1; then
  echo "request-codex accepted Done" >&2
  exit 1
fi

before_delete="$(sha256sum "$TMP/Boards/Task Board.md" "$TMP/Tickets/BOXP-1.md")"
"$BIN" delete BOXP-1 --vault "$TMP" --dry-run --json >/tmp/task-board-delete-dry-run.json
after_delete="$(sha256sum "$TMP/Boards/Task Board.md" "$TMP/Tickets/BOXP-1.md")"
[[ "$before_delete" == "$after_delete" ]]

if "$BIN" delete BOXP-1 --vault "$TMP" --dry-run --confirm --json >/tmp/task-board-delete-both.json 2>&1; then
  echo "delete accepted --dry-run with --confirm" >&2
  exit 1
fi

"$BIN" list --vault "$TMP" --lane Review --json >/tmp/task-board-list.json
"$BIN" show BOXP-1 --vault "$TMP" --json >/tmp/task-board-show.json

echo "smoke tests passed"
