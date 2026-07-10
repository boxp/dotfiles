#!/usr/bin/env bash
set -euo pipefail

[ "$1" = "--start-epoch" ]
[ "$3" = "--end-epoch" ]
cat <<'EOF'
{"id":"private-trace-id","timestamp":"2026-07-10T03:00:00Z"}
{"id":"outside-target-day","timestamp":"2026-07-09T03:00:00Z"}
{"id":"invalid-offset","timestamp":"2026-07-10T23:00:00+15:00"}
EOF
