#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: sanitize-check.sh <file-path>" >&2
}

[ "$#" -eq 1 ] || { usage; exit 1; }
file="$1"
[ -f "$file" ] || { echo "File not found: $file" >&2; exit 1; }

check_pattern() {
  local label="$1"
  local pattern="$2"
  if grep -Eq "$pattern" "$file"; then
    echo "WARNING: sensitive pattern detected: $label" >&2
    exit 1
  fi
}

check_pattern "API key" 'sk-[a-zA-Z0-9]{20,}|pk-[a-zA-Z0-9]{20,}|xai-[a-zA-Z0-9]{20,}'
check_pattern "AWS credential" 'AKIA[A-Z0-9]{16}|aws_secret_access_key'
check_pattern "JWT" 'eyJ[a-zA-Z0-9_-]+\.[eE][yY][jJ][a-zA-Z0-9_-]+'
check_pattern "private IP address" '192\.168\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+'

if grep -Ev 'obsidian-headless' "$file" | grep -Eq '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'; then
  echo "WARNING: sensitive pattern detected: email address" >&2
  exit 1
fi

echo "OK: no sensitive patterns found"
