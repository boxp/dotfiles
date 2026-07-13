#!/usr/bin/env bash
set -euo pipefail

runner="$(cd "$(dirname "$0")" && pwd)/run-delegate.sh"
state_root="$(mktemp -d)"
mock_bin="$state_root/bin"
notify_log="$state_root/notifications.log"
mkdir -p "$mock_bin"
trap 'rm -rf "$state_root"' EXIT

printf '%s\n' '#!/usr/bin/env sh' 'printf "%s\\n" "$*" >> "$AI_DELEGATE_NOTIFY_LOG"' > "$mock_bin/osascript"
chmod +x "$mock_bin/osascript"
export PATH="$mock_bin:$PATH"
export AI_DELEGATE_NOTIFY_LOG="$notify_log"

"$runner" --state-root "$state_root" --session-id succeeds --working-directory /tmp -- sh -c 'printf success-output'
test "$(cat "$state_root/succeeds/status")" = success
test "$(cat "$state_root/succeeds/exit_code")" = 0
grep -q success-output "$state_root/succeeds/output.log"
grep -q 'AI delegate completed' "$notify_log"

if "$runner" --state-root "$state_root" --session-id fails --working-directory /tmp -- sh -c 'printf failure-output; exit 7'; then
  echo 'expected failing delegate command to fail' >&2
  exit 1
fi
test "$(cat "$state_root/fails/status")" = failed
test "$(cat "$state_root/fails/exit_code")" = 7
grep -q failure-output "$state_root/fails/output.log"
grep -q 'AI delegate failed' "$notify_log"
