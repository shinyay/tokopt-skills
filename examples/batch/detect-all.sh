#!/usr/bin/env bash
#
# detect-all.sh — Run `tokopt detect <dir> --format=json` across one or
# more root directories in parallel, emitting JSONL (one record per root).
#
# Why per-DIRECTORY, not per-file?
#   `tokopt detect` walks a directory looking for the standard customization
#   locations (.github/copilot-instructions.md, .github/agents/*.agent.md,
#   .github/skills/*/SKILL.md, AGENTS.md, CLAUDE.md). It does not accept a
#   single arbitrary file. So the batch shape is "many roots" (e.g., multi-
#   team monorepo subtrees, sibling repos under one parent dir) — not
#   "many files".
#
# Usage:
#   ./detect-all.sh                       # default root: .
#   ./detect-all.sh ~/work/repo-a ~/work/repo-b
#   ./detect-all.sh ~/work/team/*         # shell expands to many dirs
#   ./detect-all.sh ROOT1 ROOT2 -o <file> # write JSONL to <file>
#   TOKOPT_BATCH_PARALLEL=4 ./detect-all.sh ~/work/team/*
#
# Output: JSONL — each line is `{root, format_version, findings:[...]}`.
#   `root` is spliced in via jq so each row is self-describing.
#
# Exit codes:
#   0  all roots processed cleanly
#   1  1..50% of roots failed
#   2  >50% of roots failed (or no roots given, or missing dependencies)
#
# See examples/batch/README.md for the full recipe and prerequisites.
set -uo pipefail

# ─── Argument parsing ─────────────────────────────────────────────────────
ROOTS=()
OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o|--output) OUT="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "detect-all.sh: unknown flag: $1" >&2
      exit 2 ;;
    *) ROOTS+=("$1"); shift ;;
  esac
done

# Default to current directory if no roots given
if [ "${#ROOTS[@]}" -eq 0 ]; then
  ROOTS=(".")
fi

PARALLEL="${TOKOPT_BATCH_PARALLEL:-$(nproc 2>/dev/null || echo 4)}"

# ─── Dependency checks ────────────────────────────────────────────────────
if ! command -v tokopt >/dev/null 2>&1; then
  echo "detect-all.sh: tokopt not found in PATH" >&2
  echo "  Install: curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh | sh" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "detect-all.sh: jq not found in PATH" >&2
  echo "  Install: apt install jq  /  brew install jq" >&2
  exit 2
fi

# Validate every root is a directory
for r in "${ROOTS[@]}"; do
  if [ ! -d "$r" ]; then
    echo "detect-all.sh: not a directory: $r" >&2
    exit 2
  fi
done

TOTAL="${#ROOTS[@]}"

# ─── Output sink ──────────────────────────────────────────────────────────
if [ -n "$OUT" ]; then
  : > "$OUT"
  SINK="$OUT"
else
  SINK="/dev/stdout"
fi

echo "detect-all.sh: $TOTAL root(s), parallel=$PARALLEL" >&2

# ─── Worker — single root, emit one JSON line tagged with root path ───────
# `tokopt detect <dir> --format=json` returns {format_version, findings:[...]}
# without a `root` field. We splice the root in via jq so each JSONL row is
# self-describing.
run_one() {
  local root="$1"
  local raw
  if raw=$(tokopt detect "$root" --format=json 2>/dev/null); then
    printf '%s' "$raw" | jq -c --arg r "$root" '. + {root: $r}'
    return 0
  else
    echo "FAIL: $root" >&2
    return 1
  fi
}
export -f run_one

# ─── Run ──────────────────────────────────────────────────────────────────
ERR_FILE=$(mktemp -t detect-all-err.XXXXXX)
trap 'rm -f "$ERR_FILE"' EXIT

# Pass roots to xargs via NUL-delimited stream — filename-safe.
printf '%s\0' "${ROOTS[@]}" | \
  xargs -0 -n1 -P "$PARALLEL" bash -c 'run_one "$@"' _ \
  >> "$SINK" 2> >(tee "$ERR_FILE" >&2) || true

wait

# grep -c prints "0" to stdout when zero matches (and exits 1) — `|| true`
# swallows the exit code so the count is preserved.
FAIL=$(grep -c '^FAIL: ' "$ERR_FILE" 2>/dev/null || true)
FAIL=${FAIL:-0}

PASS=$((TOTAL - FAIL))
echo "detect-all.sh: done — $PASS/$TOTAL succeeded, $FAIL failed" >&2

if [ "$FAIL" -eq 0 ]; then
  exit 0
elif [ "$FAIL" -gt $((TOTAL / 2)) ]; then
  exit 2
else
  exit 1
fi
