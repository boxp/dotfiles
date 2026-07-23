#!/usr/bin/env bash
# Regression test: concurrent updates to different tickets must not lose board entries.
# Two processes updating BOXP-1 and BOXP-2 simultaneously should both appear in the board.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/bin/task-board.bb"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/Boards" "$TMP/Tickets"

cat > "$TMP/Boards/Task Board.md" <<'BOARD'
# Task Board

## Backlog

- [ ] [[Tickets/BOXP-1|BOXP-1: ticket alpha]] #ticket status::backlog priority::medium
- [ ] [[Tickets/BOXP-2|BOXP-2: ticket beta]] #ticket status::backlog priority::medium

## Ready

## In Progress

## Review

## Blocked

## Done
BOARD

for ID in BOXP-1 BOXP-2; do
  TITLE="ticket alpha"; [[ "$ID" == "BOXP-2" ]] && TITLE="ticket beta"
  cat > "$TMP/Tickets/${ID}.md" <<EOF
---
id: ${ID}
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
created: 2026-01-01
due:
closed:
tags:
  - ticket
---

# ${ID}: ${TITLE}

## Notes

initial note.
EOF
done

FAILURES=0
ROUNDS=10
for _ in $(seq 1 $ROUNDS); do
  # Reset board to initial state with both tickets in Backlog
  cat > "$TMP/Boards/Task Board.md" <<'BOARD'
# Task Board

## Backlog

- [ ] [[Tickets/BOXP-1|BOXP-1: ticket alpha]] #ticket status::backlog priority::medium
- [ ] [[Tickets/BOXP-2|BOXP-2: ticket beta]] #ticket status::backlog priority::medium

## Ready

## In Progress

## Review

## Blocked

## Done
BOARD

  # Reset tickets to backlog
  sed -i 's/^status: .*/status: backlog/' "$TMP/Tickets/BOXP-1.md" "$TMP/Tickets/BOXP-2.md"

  # Run concurrent updates to different tickets (both move to In Progress)
  "$BIN" update BOXP-1 --vault "$TMP" --lane "In Progress" >/dev/null 2>&1 &
  PID1=$!
  "$BIN" update BOXP-2 --vault "$TMP" --lane "In Progress" >/dev/null 2>&1 &
  PID2=$!
  EXIT1=0; EXIT2=0
  wait $PID1 || EXIT1=$?
  wait $PID2 || EXIT2=$?

  if [[ "$EXIT1" -ne 0 || "$EXIT2" -ne 0 ]]; then
    FAILURES=$((FAILURES + 1))
    echo "FAIL round $_: child process failed (exit codes: BOXP-1=$EXIT1, BOXP-2=$EXIT2)" >&2
    continue
  fi

  BOARD_CONTENT=$(cat "$TMP/Boards/Task Board.md")
  FOUND_1=0; FOUND_2=0
  echo "$BOARD_CONTENT" | grep -q "BOXP-1.*status::in-progress" && FOUND_1=1 || true
  echo "$BOARD_CONTENT" | grep -q "BOXP-2.*status::in-progress" && FOUND_2=1 || true

  if [[ "$FOUND_1" -eq 0 || "$FOUND_2" -eq 0 ]]; then
    FAILURES=$((FAILURES + 1))
    echo "FAIL round $_: board after concurrent update:" >&2
    cat "$TMP/Boards/Task Board.md" >&2
  fi
done

if [[ "$FAILURES" -gt 0 ]]; then
  echo "FAIL: $FAILURES/$ROUNDS rounds had concurrent board update loss" >&2
  exit 1
fi

echo "concurrent-board-updates: $ROUNDS/$ROUNDS rounds passed"
