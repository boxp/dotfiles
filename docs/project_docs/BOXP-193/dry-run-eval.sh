#!/usr/bin/env bash
# BOXP-193: jev-lint を API キーなし・外向き通信なしで dry-run 評価する。
#
#   dry-run-eval.sh run --repo <git dir> --base <sha> --head <sha>
#   dry-run-eval.sh fixtures
#   dry-run-eval.sh check      （リストと設定の検証だけ。jev-lint は起動しない）
#   dry-run-eval.sh check-tool （固定版の jev-lint / ast-grep が使えるかの検証だけ）
#
# 前提: JEV_TOOL_DIR に tool/package-lock.json から
#   npm ci --ignore-scripts
# 済みの node_modules があること（取得だけは network が要るので事前に済ませる）。
# --ignore-scripts では @ast-grep/cli の postinstall が走らないが、同梱の shim が
# platform 別 package の native binary を実行時に解決する。この前提が崩れたら
# check_tool が exit 2 で止める（unavailable や clean と混同させない）。
# このスクリプト自身は API を呼ばない。jev-lint は必ず --dry-run で、
# network namespace を切り離し、環境変数を空にして起動する。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JEV_TOOL_DIR="${JEV_TOOL_DIR:-$HERE/tool}"
CONFIG="${JEV_EVAL_CONFIG:-$HERE/jev-lint.pilot.yaml}"
ALLOWLIST="${JEV_EVAL_ALLOWLIST:-$HERE/allowlist.txt}"
DENYLIST="${JEV_EVAL_DENYLIST:-$HERE/denylist.txt}"
CONTENT_DENY="${JEV_EVAL_CONTENT_DENY:-$HERE/content-deny.txt}"

MAX_FILES="${JEV_EVAL_MAX_FILES:-10}"
MAX_BYTES="${JEV_EVAL_MAX_BYTES:-65536}"
MAX_TOKENS="${JEV_EVAL_MAX_TOKENS:-100000}"
MAX_USD="${JEV_EVAL_MAX_USD:-0.01}"

die() { echo "error: $*" >&2; exit 2; }

# リストを読めなければ fail-closed。grep の 1（該当行なし）だけを空として扱う。
# command substitution では set -e が効かないので、呼び出し側で必ず || die する。
read_list() {
  local rc=0
  [ -f "$1" ] && [ -r "$1" ] || { echo "error: list not readable: $1" >&2; return 2; }
  grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$1" || rc=$?
  [ "$rc" -le 1 ] || { echo "error: cannot read list: $1" >&2; return 2; }
}

# 送信可否を決める前にリストを検証して読み込む。欠落・読取不能・空・不正な
# 正規表現はどれも gate を素通しにするので、判定を始めずに止める。
load_lists() {
  local work="$1" list pattern rc
  list="$(read_list "$ALLOWLIST")" || die "allowlist unusable: $ALLOWLIST"
  [ -n "$list" ] || die "allowlist is empty: $ALLOWLIST"
  mapfile -t ALLOW_PATHS <<<"$list"
  # 正確な相対 path だけを受け付ける。glob や repo の外を指す行は誤記として止める。
  for pattern in "${ALLOW_PATHS[@]}"; do
    case "/$pattern/" in
      //* | */../* | */./* | *//* | *[\*\?\[\]\\]* | *[[:space:]]*)
        die "allowlist has an invalid path: $ALLOWLIST" ;;
    esac
  done

  list="$(read_list "$DENYLIST")" || die "denylist unusable: $DENYLIST"
  [ -n "$list" ] || die "denylist is empty: $DENYLIST"
  mapfile -t DENY_GLOBS <<<"$list"

  list="$(read_list "$CONTENT_DENY")" || die "content-deny unusable: $CONTENT_DENY"
  [ -n "$list" ] || die "content-deny is empty: $CONTENT_DENY"
  while IFS= read -r pattern; do
    rc=0
    grep -E -i -q -e "$pattern" </dev/null 2>/dev/null || rc=$?
    [ "$rc" -le 1 ] || die "content-deny has an invalid regex: $CONTENT_DENY"
  done <<<"$list"
  CONTENT_PATTERNS="$work/content-deny.re"
  printf '%s\n' "$list" >"$CONTENT_PATTERNS"
  BLOB_TMP="$work/blob"

  # 設定の files は gate を通った path から生成する。雛形が独自の files を
  # 持つと allowlist と食い違い、評価されない target が出るので受け付けない。
  [ -f "$CONFIG" ] && [ -r "$CONFIG" ] || die "config unusable: $CONFIG"
  rc=0
  grep -q -E '^[[:space:]]*"?files"?[[:space:]]*:' "$CONFIG" || rc=$?
  case "$rc" in
    0) die "config must not define files (generated from the allowlist): $CONFIG" ;;
    1) ;;
    *) die "config unusable: $CONFIG" ;;
  esac
}

# 信頼済みの雛形に、gate を通った path だけを files として足した設定を書く。
write_config() {
  local out="$1" path
  shift
  {
    echo "files:"
    for path in "$@"; do
      printf '  - %s\n' "$(jq -n --arg p "$path" '$p')"
    done
    cat "$CONFIG"
  } >"$out"
}

denied_path() {
  local path="$1" glob
  for glob in "${DENY_GLOBS[@]}"; do
    # shellcheck disable=SC2053
    if [[ "$path" == $glob || "${path##*/}" == $glob ]]; then
      echo "$glob"
      return 0
    fi
  done
  return 1
}

# blob の内容が content-deny のどれかに当たれば 0、当たらなければ 1、
# 検査できなければ 2。当たった行は出力しない。
denied_content() {
  local repo="$1" rev="$2" path="$3" rc=0
  git -C "$repo" show "$rev:$path" >"$BLOB_TMP" 2>/dev/null || return 2
  grep -a -E -i -q -f "$CONTENT_PATTERNS" "$BLOB_TMP" || rc=$?
  [ "$rc" -le 1 ] || return 2
  return "$rc"
}

blob_mode() { git -C "$1" ls-tree "$2" -- "$3" | awk '{print $1}'; }

# 1 path の送信可否を決める。出力: "<decision>\t<reason>"
gate_path() {
  local repo="$1" base="$2" head="$3" path="$4" changes="$5"
  local status mode glob size rc

  if grep -q -P "^R[0-9]*\t(\Q$path\E\t|[^\t]*\t\Q$path\E$)" <<<"$changes"; then
    printf 'skip\trename\n'; return
  fi
  status="$(awk -F'\t' -v p="$path" '$2 == p {print substr($1, 1, 1)}' <<<"$changes")"
  case "$status" in
    "") printf 'untouched\tnot-in-diff\n'; return ;;
    D) printf 'skip\tdeleted\n'; return ;;
    A | M) ;;
    *) printf 'skip\tstatus-%s\n' "$status"; return ;;
  esac
  if glob="$(denied_path "$path")"; then
    printf 'skip\tdenylist\n'; return
  fi
  for rev in "$base" "$head"; do
    mode="$(blob_mode "$repo" "$rev" "$path")"
    case "$mode" in
      "" | 100644 | 100755) ;;
      120000) printf 'skip\tsymlink\n'; return ;;
      *) printf 'skip\tmode-%s\n' "$mode"; return ;;
    esac
  done
  # 旧版も全文を読み込み・複製するので、上限は base/head の両方に掛ける。
  for rev in "$base" "$head"; do
    if [ "$rev" = "$base" ] && [ -z "$(blob_mode "$repo" "$rev" "$path")" ]; then
      continue
    fi
    size="$(git -C "$repo" cat-file -s "$rev:$path" 2>/dev/null)" || {
      printf 'skip\tunreadable\n'; return
    }
    if [ "$size" -gt "$MAX_BYTES" ]; then
      printf 'skip\ttoo-large\n'; return
    fi
  done
  # 削除行も旧版全文に含まれるので、base/head の両方を検査する。
  for rev in "$base" "$head"; do
    # 追加されたファイルは base に blob がない。head にないものは上で弾いている。
    [ -n "$(blob_mode "$repo" "$rev" "$path")" ] || continue
    rc=0
    denied_content "$repo" "$rev" "$path" || rc=$?
    case "$rc" in
      0) printf 'skip\tcontent\n'; return ;;
      1) ;;
      *) printf 'skip\tcontent-check-failed\n'; return ;;
    esac
  done
  printf 'send\tok\n'
}

# staging 用の git。呼び出し元の system/global 設定、template、core.hooksPath、
# GIT_* 環境変数を継承すると、network 分離より前に hook や filter が動き得る。
# 環境を空にし、設定と template を無効にして起動する。
staging_git() {
  local git_bin
  git_bin="$(command -v git)" || die "git not found"
  env -i PATH="$(dirname "$git_bin"):/usr/bin:/bin" HOME=/nonexistent \
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_SYSTEM=/dev/null GIT_CONFIG_GLOBAL=/dev/null \
    GIT_TERMINAL_PROMPT=0 \
    "$git_bin" -c core.hooksPath=/dev/null -c core.fsmonitor=false \
    -c commit.gpgSign=false -c user.name=eval -c user.email=eval@invalid "$@"
}

# 対象だけを 2 commit の使い捨て repo へ抽出する。履歴・hook・config は持ち込まない。
build_staging() {
  local repo="$1" base="$2" head="$3" staging="$4"
  shift 4
  local path rev
  staging_git init -q --template= "$staging"
  for rev in "$base" "$head"; do
    for path in "$@"; do
      mkdir -p "$staging/$(dirname "$path")"
      if git -C "$repo" cat-file -e "$rev:$path" 2>/dev/null; then
        git -C "$repo" show "$rev:$path" >"$staging/$path"
      else
        rm -f "$staging/$path"
      fi
    done
    staging_git -C "$staging" add -A
    staging_git -C "$staging" commit -q --no-verify --allow-empty -m "snapshot"
  done
}

# network namespace を分離し、環境変数を持ち込まずに jev-lint を起動する。
# node が /usr/bin の外にある環境のため、PATH には node の場所だけを足す。
jev_offline() {
  local home="$1" node_dir
  node_dir="$(command -v node)" || die "node not found"
  node_dir="$(dirname "$node_dir")"
  shift
  unshare -rn env -i PATH="$node_dir:/usr/bin:/bin" HOME="$home" \
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_SYSTEM=/dev/null GIT_CONFIG_GLOBAL=/dev/null \
    "$JEV_TOOL_DIR/node_modules/.bin/jev-lint" "$@"
}

# install script を走らせていない node_modules で、lockfile の固定版どおりの
# ast-grep が offline で起動できることを確かめる。
check_tool() {
  local lock="$JEV_TOOL_DIR/package-lock.json" bin="$JEV_TOOL_DIR/node_modules/.bin"
  local want got node_dir
  [ -x "$bin/jev-lint" ] || die "jev-lint not installed under $JEV_TOOL_DIR"
  [ -x "$bin/ast-grep" ] || die "ast-grep not installed under $JEV_TOOL_DIR"
  want="$(jq -er '.packages["node_modules/@ast-grep/cli"].version' "$lock")" \
    || die "ast-grep version not pinned in $lock"
  node_dir="$(command -v node)" || die "node not found"
  node_dir="$(dirname "$node_dir")"
  got="$(unshare -rn env -i PATH="$node_dir:/usr/bin:/bin" "$bin/ast-grep" --version 2>/dev/null)" \
    || die "ast-grep native binary not usable under $JEV_TOOL_DIR"
  [ "$got" = "ast-grep $want" ] || die "ast-grep version mismatch: want $want, got $got"
  echo "tool: ok ast-grep=$want"
}

evaluate() {
  local repo="$1" base="$2" head="$3"
  local work merge_base changes path decision reason state started elapsed
  local -a targets=()
  local considered=0 skipped=0 untouched=0

  check_tool >/dev/null
  base="$(git -C "$repo" rev-parse --verify "$base^{commit}")"
  head="$(git -C "$repo" rev-parse --verify "$head^{commit}")"
  merge_base="$(git -C "$repo" merge-base "$base" "$head")"
  changes="$(git -C "$repo" diff --name-status -M "$merge_base" "$head")"
  work="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$work'" RETURN
  load_lists "$work"

  echo "base=$base"
  echo "merge_base=$merge_base"
  echo "head=$head"
  echo "changed_files=$(grep -c . <<<"$changes" || true)"

  for path in "${ALLOW_PATHS[@]}"; do
    considered=$((considered + 1))
    decision="" reason=""
    IFS=$'\t' read -r decision reason < <(gate_path "$repo" "$merge_base" "$head" "$path" "$changes") || true
    echo "gate	$path	$decision	$reason"
    case "$decision" in
      send) targets+=("$path") ;;
      skip) skipped=$((skipped + 1)) ;;
      untouched) untouched=$((untouched + 1)) ;;
      *) die "gate gave no decision for $path" ;;
    esac
  done
  echo "allowlisted=$considered targets=${#targets[@]} skipped=$skipped untouched=$untouched"

  if [ "${#targets[@]}" -eq 0 ]; then
    echo "state=skipped-no-target"
    return 0
  fi
  if [ "${#targets[@]}" -gt "$MAX_FILES" ]; then
    echo "state=over-budget reason=files>${MAX_FILES}"
    return 0
  fi

  build_staging "$repo" "$merge_base" "$head" "$work/staging" "${targets[@]}"
  mkdir -p "$work/home" "$work/trusted"
  write_config "$work/trusted/jev-lint.yaml" "${targets[@]}"
  echo "config_files=${#targets[@]}"

  started="$(date +%s%N)"
  state=planned
  if ! (cd "$work/staging" && jev_offline "$work/home" review --base HEAD~1 \
    --dry-run --cache none --config "$work/trusted/jev-lint.yaml" \
    --json --show-subjects) >"$work/plan.json" 2>"$work/plan.err"; then
    state=unavailable
  fi
  elapsed=$((($(date +%s%N) - started) / 1000000))
  echo "elapsed_ms=$elapsed"
  if [ "$state" = unavailable ]; then
    echo "state=unavailable reason=dry-run-failed"
    sed 's/^/stderr: /' "$work/plan.err"
    return 0
  fi

  jq -r '"subjects=\(.subjects) requests=\(.requests) tokens=\(.tokens) usd=\(.usd)"' "$work/plan.json"
  jq -r '.batches[] | "batch\t\(.file)\tarm=\(.arm)\tsubjects=\(.subjects)\ttokens=\(.tokens)\tdegraded=\(.degraded)"' "$work/plan.json"
  jq -r '.byRule[] | "rule\t\(.rule)\tsubjects=\(.subjects)\trequests=\(.requests)\ttokens=\(.tokens)\tusd=\(.usd)"' "$work/plan.json"
  jq -r '.subjectList[]? | "subject\t\(.rule)\t\(.file):\(.line)-\(.endLine)"' "$work/plan.json"
  jq -r '"idle=\([.idleLanguages[]? | "\(.language)(\(.rules))"] | join(","))"' "$work/plan.json"
  for path in "${targets[@]}"; do
    echo "target_bytes	$path	$(wc -c <"$work/staging/$path")"
  done

  # 計画された送信が gate を通った path の外に出ていないこと。
  if jq -e '[.batches[].file] - $ARGS.positional | length > 0' \
    "$work/plan.json" --args "${targets[@]}" >/dev/null; then
    echo "state=unavailable reason=plan-outside-targets"
    return 0
  fi
  if jq -e --argjson t "$MAX_TOKENS" --argjson u "$MAX_USD" \
    '.tokens > $t or .usd > $u' "$work/plan.json" >/dev/null; then
    echo "state=over-budget reason=tokens-or-usd"
    return 0
  fi
  if [ -n "$(find "$work/staging" -path "$work/staging/.git" -prune -o -name '.jev-lint*' -print)" ]; then
    echo "state=unavailable reason=cache-written"
    return 0
  fi
  echo "state=dry-run-ok"
}

# 負例 fixtures を実行時に生成する。偽の credential は commit しない。
fixtures() {
  local root repo fake expected actual failed=0 out
  root="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$root'" RETURN
  repo="$root/src"
  fake="AKIA$(printf 'EXAMPLE%.0s' 1 2)12"
  git init -q "$repo"
  commit() { git -C "$repo" add -A && git -C "$repo" -c user.name=f -c user.email=f@invalid commit -q -m "$1"; }

  (
    cd "$repo"
    mkdir -p env
    printf '#!/bin/sh\necho ok\n' >ok.sh
    printf '# Agents\n\n- reply in Japanese\n' >AGENTS.md
    printf '#!/bin/sh\necho clean\n' >leaks-now.sh
    printf '#!/bin/sh\nKEY=%s\n' "$fake" >leaked-before.sh
    printf '#!/bin/sh\necho target\n' >real.sh
    ln -s real.sh link.sh
    printf '#!/bin/sh\necho gone\n' >gone.sh
    printf '#!/bin/sh\necho moved one\necho moved two\necho moved three\n' >old-name.sh
    printf 'region = "x"\n' >env/prod.tfvars
    printf '# Notes\n\nplain\n' >manifest.md
    printf '#!/bin/sh\necho big\n' >big.sh
    head -c 70000 /dev/zero | tr '\0' '#' >was-big.sh
    printf '#!/bin/sh\necho same\n' >unchanged.sh
    printf '#!/bin/sh\necho other\n' >unlisted.sh
  )
  commit base
  (
    cd "$repo"
    printf 'rm -rf "$DEST/"\n' >>ok.sh
    printf '\n## Commits\n\n- commit when appropriate\n' >>AGENTS.md
    printf 'KEY=%s\n' "$fake" >>leaks-now.sh
    printf '#!/bin/sh\necho cleaned\n' >leaked-before.sh
    printf 'echo more\n' >>real.sh
    rm link.sh && ln -s ok.sh link.sh
    git rm -q gone.sh
    git mv old-name.sh new-name.sh
    printf 'region = "y"\n' >env/prod.tfvars
    printf '\n```yaml\nkind: ExternalSecret\n```\n' >>manifest.md
    head -c 70000 /dev/zero | tr '\0' '#' >>big.sh
    printf '#!/bin/sh\necho small\n' >was-big.sh
    printf 'echo changed\n' >>unlisted.sh
  )
  commit head

  cat >"$root/allowlist.txt" <<'EOF'
ok.sh
AGENTS.md
leaks-now.sh
leaked-before.sh
link.sh
gone.sh
new-name.sh
env/prod.tfvars
manifest.md
big.sh
was-big.sh
unchanged.sh
EOF
  expected="$(
    cat <<'EOF'
gate	ok.sh	send	ok
gate	AGENTS.md	send	ok
gate	leaks-now.sh	skip	content
gate	leaked-before.sh	skip	content
gate	link.sh	skip	symlink
gate	gone.sh	skip	deleted
gate	new-name.sh	skip	rename
gate	env/prod.tfvars	skip	denylist
gate	manifest.md	skip	content
gate	big.sh	skip	too-large
gate	was-big.sh	skip	too-large
gate	unchanged.sh	untouched	not-in-diff
EOF
  )"

  out="$(ALLOWLIST="$root/allowlist.txt" evaluate "$repo" HEAD~1 HEAD)"
  echo "$out"
  actual="$(grep '^gate' <<<"$out")"
  if [ "$actual" != "$expected" ]; then
    echo "FAIL gate decisions"
    diff <(echo "$expected") <(echo "$actual") || true
    failed=1
  fi
  grep -q '^state=dry-run-ok$' <<<"$out" || { echo "FAIL expected state=dry-run-ok"; failed=1; }
  grep -q '^config_files=2$' <<<"$out" || { echo "FAIL config files differ from gate targets"; failed=1; }
  grep -q -P "^batch\tAGENTS\.md\t" <<<"$out" || { echo "FAIL AGENTS.md was not evaluated"; failed=1; }
  grep -q -P "^subject\tdestroys-beyond-its-scope\tok\.sh:" <<<"$out" || { echo "FAIL ok.sh produced no shell subject"; failed=1; }
  if grep '^batch' <<<"$out" | grep -v -P '^batch\t(ok\.sh|AGENTS\.md)\t' | grep -q .; then
    echo "FAIL a skipped file reached the plan"
    failed=1
  fi
  if grep -q "$fake" <<<"$out"; then
    echo "FAIL fake credential echoed"
    failed=1
  fi

  # 呼び出し元の Git 設定・template・GIT_* が staging の git に届かないこと。
  echo "--- case: hostile git environment"
  mkdir -p "$root/hostile/hooks" "$root/hostile/template/hooks"
  for out in "$root/hostile/hooks" "$root/hostile/template/hooks"; do
    printf '#!/bin/sh\ntouch "%s/hook-ran"\n' "$root" >"$out/pre-commit"
    cp "$out/pre-commit" "$out/post-commit"
    chmod +x "$out/pre-commit" "$out/post-commit"
  done
  printf '[core]\n\thooksPath = %s\n[init]\n\ttemplateDir = %s\n' \
    "$root/hostile/hooks" "$root/hostile/template" >"$root/hostile/gitconfig"
  out="$(ALLOWLIST="$root/allowlist.txt" HOME="$root/hostile" \
    GIT_CONFIG_GLOBAL="$root/hostile/gitconfig" GIT_TEMPLATE_DIR="$root/hostile/template" \
    GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0="$root/hostile/hooks" \
    evaluate "$repo" HEAD~1 HEAD)"
  grep -e '^allowlisted=' -e '^state=' <<<"$out"
  grep -q '^state=dry-run-ok$' <<<"$out" || { echo "FAIL expected state=dry-run-ok"; failed=1; }
  if [ -e "$root/hook-ran" ]; then
    echo "FAIL a git hook from the caller's environment ran"
    failed=1
  fi

  echo "--- case: no target"
  printf 'unchanged.sh\ngone.sh\n' >"$root/allowlist.txt"
  out="$(ALLOWLIST="$root/allowlist.txt" evaluate "$repo" HEAD~1 HEAD)"
  echo "$out"
  grep -q '^state=skipped-no-target$' <<<"$out" || { echo "FAIL expected skipped-no-target"; failed=1; }

  echo "--- case: huge diff"
  (
    cd "$repo"
    for i in $(seq 1 11); do printf '#!/bin/sh\necho %s\n' "$i" >"many-$i.sh"; done
  )
  commit many
  for i in $(seq 1 11); do echo "many-$i.sh"; done >"$root/allowlist.txt"
  out="$(ALLOWLIST="$root/allowlist.txt" evaluate "$repo" HEAD~1 HEAD)"
  echo "$out" | grep -v '^gate'
  grep -q '^state=over-budget ' <<<"$out" || { echo "FAIL expected over-budget"; failed=1; }

  # リストが使えないときは、判定を1件も出さずに失敗すること（fail-closed）。
  expect_refusal() {
    local label="$1" rc=0
    echo "--- case: $label"
    out="$(evaluate "$repo" HEAD~2 HEAD~1 2>&1)" || rc=$?
    echo "$out"
    if [ "$rc" -eq 0 ] || grep -q -e '^gate' -e '^state=' <<<"$out"; then
      echo "FAIL $label did not stop the gate"
      failed=1
    fi
  }
  printf 'ok.sh\nleaks-now.sh\n' >"$root/allowlist.txt"
  : >"$root/empty.txt"
  printf '# comment only\n\n' >"$root/comment-only.txt"
  printf 'AKIA[0-9A-Z]{16}\nbroken(\n' >"$root/bad-regex.txt"
  mkdir "$root/a-directory"
  ALLOWLIST="$root/allowlist.txt" CONTENT_DENY="$root/missing.txt" expect_refusal "content-deny missing"
  ALLOWLIST="$root/allowlist.txt" CONTENT_DENY="$root/a-directory" expect_refusal "content-deny not a file"
  ALLOWLIST="$root/allowlist.txt" CONTENT_DENY="$root/empty.txt" expect_refusal "content-deny empty"
  ALLOWLIST="$root/allowlist.txt" CONTENT_DENY="$root/comment-only.txt" expect_refusal "content-deny comment only"
  ALLOWLIST="$root/allowlist.txt" CONTENT_DENY="$root/bad-regex.txt" expect_refusal "content-deny invalid regex"
  ALLOWLIST="$root/allowlist.txt" DENYLIST="$root/missing.txt" expect_refusal "denylist missing"
  ALLOWLIST="$root/allowlist.txt" DENYLIST="$root/empty.txt" expect_refusal "denylist empty"
  ALLOWLIST="$root/missing.txt" expect_refusal "allowlist missing"
  ALLOWLIST="$root/empty.txt" expect_refusal "allowlist empty"
  ALLOWLIST="$root/comment-only.txt" expect_refusal "allowlist comment only"
  printf 'ok.sh\n*.sh\n' >"$root/glob-allowlist.txt"
  ALLOWLIST="$root/glob-allowlist.txt" expect_refusal "allowlist has a glob"
  printf 'ok.sh\n../ok.sh\n' >"$root/outside-allowlist.txt"
  ALLOWLIST="$root/outside-allowlist.txt" expect_refusal "allowlist leaves the repo"
  { printf 'files:\n  - ok.sh\n'; cat "$CONFIG"; } >"$root/own-files.yaml"
  ALLOWLIST="$root/allowlist.txt" CONFIG="$root/own-files.yaml" expect_refusal "config defines its own files"
  ALLOWLIST="$root/allowlist.txt" CONFIG="$root/missing.yaml" expect_refusal "config missing"

  if [ "$failed" -ne 0 ]; then
    echo "fixtures: FAILED"
    return 1
  fi
  echo "fixtures: ok"
}

cmd="${1:-}"
[ $# -gt 0 ] && shift
case "$cmd" in
  run)
    repo="" base="" head=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --repo) repo="$2"; shift 2 ;;
        --base) base="$2"; shift 2 ;;
        --head) head="$2"; shift 2 ;;
        *) die "unknown option $1" ;;
      esac
    done
    [ -n "$repo" ] && [ -n "$base" ] && [ -n "$head" ] || die "run needs --repo, --base and --head"
    evaluate "$repo" "$base" "$head"
    ;;
  fixtures) fixtures ;;
  check-tool) check_tool ;;
  check)
    work="$(mktemp -d)"
    trap 'rm -rf "$work"' EXIT
    load_lists "$work"
    echo "lists: ok allowlist=${#ALLOW_PATHS[@]} denylist=${#DENY_GLOBS[@]}"
    ;;
  *) die "usage: $0 run --repo <dir> --base <sha> --head <sha> | fixtures | check | check-tool" ;;
esac
