#!/usr/bin/env bash
set -euo pipefail
script=$(cd "$(dirname "$0")/.." && pwd)/generate-image.bb
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin"
export TEST_LOG="$tmp/log" TEST_MODE=ok
cat > "$tmp/bin/codex" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" >> "$TEST_LOG"
case "$1" in
 login) if [ "$TEST_MODE" = badlogin ]; then echo 'Not logged in'; exit 1; else echo 'Logged in using ChatGPT'; fi ;;
 features) echo 'image_generation stable true' ;;
 --version) echo 'codex-cli stub' ;;
 exec)
   cat > /dev/null
   [ -z "${OPENAI_API_KEY+x}" ] || exit 8
   [ "$TEST_MODE" != fail ] || exit 29
   while [ "$#" -gt 0 ]; do if [ "$1" = -C ]; then dir=$2; break; fi; shift; done
   dest="$dir/result.png"
   if [ "$TEST_MODE" = thread ]; then
     mkdir -p "$CODEX_HOME/generated_images/1234-abcd"
     dest="$CODEX_HOME/generated_images/1234-abcd/result.png"
     printf '%s\n' '{"type":"thread.started","thread_id":"1234-abcd"}'
   fi
   base64 -d > "$dest" <<'PNG'
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4//8/AAX+Av4N70a4AAAAAElFTkSuQmCC
PNG
   ;;
esac
STUB
chmod +x "$tmp/bin/codex"
export PATH="$tmp/bin:$PATH" OPENAI_API_KEY=should-not-leak
printf reference > "$tmp/ref.png"
bb "$script" -i "$tmp/ref.png" -o "$tmp/out.png" 'test' > /dev/null
awk -v ref="$tmp/ref.png" 'p=="-i" && $0==ref {found=1} {p=$0} END {exit !found}' "$TEST_LOG"
test -f "$tmp/out.png.json"
export CODEX_HOME="$tmp/codex-home" TEST_MODE=thread
bb "$script" -o "$tmp/thread.png" test > /dev/null
test -f "$tmp/thread.png.json"
: > "$TEST_LOG"; export TEST_MODE=badlogin
if bb "$script" -o "$tmp/out.png" test > /dev/null 2>&1; then exit 1; fi
! grep -qx exec "$TEST_LOG"
: > "$TEST_LOG"; export TEST_MODE=fail
if bb "$script" -o "$tmp/out.png" test > /dev/null 2>&1; then exit 1; fi
[ "$(grep -cx exec "$TEST_LOG")" = 1 ]
if bb "$script" -m gemini-3-pro-image test > "$tmp/error" 2>&1; then exit 1; fi
grep -qi unsupported "$tmp/error"
! grep -E 'generativelanguage|GEMINI_API_KEY|curl' "$script"
printf 'PASS: attachment, session image retrieval, authentication, failure/no retry, rejected model, forbidden endpoints\n'
