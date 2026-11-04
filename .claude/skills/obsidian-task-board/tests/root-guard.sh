#!/usr/bin/env bash
set -euo pipefail
HELPER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/task-board.bb"
root_guard_test() {
  local t bin before after cmd mode
  t="$(mktemp -d)"
  bin="$t/bin"
  mkdir -p "$bin" "$t/vault/Boards" "$t/vault/Tickets" "$t/tmp"
  cat > "$bin/id" <<'FAKE'
#!/bin/sh
printf '%s\n' "${FAKE_UID_VALUE:-0}"
FAKE
  chmod +x "$bin/id"
  cat > "$t/vault/Boards/Task Board.md" <<'BOARD'
# Task Board

## Backlog

- [ ] [[Tickets/BOXP-1|BOXP-1: Test]] #ticket status::backlog priority::medium

## Ready

## In Progress

## Blocked

## Done
BOARD
  cat > "$t/vault/Tickets/BOXP-1.md" <<'TICKET'
---
id: BOXP-1
type: task
status: backlog
priority: medium
---

# BOXP-1: Test

## Notes
TICKET
  before="$(cd "$t/vault" && find . -type f -print0 | sort -z | xargs -0 sha256sum)"
  for cmd in create update append-note request-codex delete; do
    for mode in normal dry; do
      local extra=()
      [[ "$mode" == dry ]] && extra=(--dry-run)
      if PATH="$bin:$PATH" bb -Djava.io.tmpdir="$t/tmp" "$HELPER" "$cmd" BOXP-1 --vault "$t/vault" "${extra[@]}" >"$t/out" 2>"$t/err"; then
        echo "root $cmd $mode unexpectedly succeeded" >&2; return 1
      fi
      grep -Fq 'kubectl -n hermes-agent exec deploy/hermes-agent -c hermes-agent -- /command/s6-setuidgid hermes bb /opt/data/skills/note-taking/obsidian-task-board/bin/task-board.bb <command> ...' "$t/err"
      [[ ! -e "$t/tmp/task-board-locks" ]]
    done
  done
  PATH="$bin:$PATH" bb -Djava.io.tmpdir="$t/tmp" "$HELPER" list --vault "$t/vault" >/dev/null
  PATH="$bin:$PATH" bb -Djava.io.tmpdir="$t/tmp" "$HELPER" show BOXP-1 --vault "$t/vault" >/dev/null
  [[ ! -e "$t/tmp/task-board-locks" ]]
  after="$(cd "$t/vault" && find . -type f -print0 | sort -z | xargs -0 sha256sum)"
  [[ "$before" == "$after" ]]
  FAKE_UID_VALUE=1000 PATH="$bin:$PATH" bb -Djava.io.tmpdir="$t/tmp" "$HELPER" append-note BOXP-1 --vault "$t/vault" --source test --note 'non-root write' >/dev/null
  grep -Fq 'non-root write' "$t/vault/Tickets/BOXP-1.md"
  rm -rf "$t"
}
root_guard_test
echo "root guard tests passed"
