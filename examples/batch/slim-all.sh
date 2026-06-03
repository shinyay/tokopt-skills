#!/usr/bin/env bash
#
# slim-all.sh — Run `tokopt slim --input <file> --format=json` across all
# Copilot customization files under a root directory, in parallel, emitting
# JSONL (one record per file) to stdout or a file.
#
# Usage:
#   ./slim-all.sh [root]               # default root: .
#   ./slim-all.sh [root] -o <file>     # write JSONL to <file>
#   TOKOPT_BATCH_PARALLEL=4 ./slim-all.sh .
#
# Output: JSONL — each line is the single-file `tokopt slim` JSON record.
#
# Exit codes:
#   0  all files processed cleanly
#   1  1..50% of files failed
#   2  >50% of files failed (or no files found, or missing dependencies)
#
# Note: this is a dry-run preview — no file is modified. To actually apply
# slim changes, review individual files and run `tokopt slim --input <file>
# --apply` interactively per file. Never `--apply` in a batch loop.
#
# See examples/batch/README.md for the full recipe and prerequisites.
set -uo pipefail

# ─── Defaults ─────────────────────────────────────────────────────────────
ROOT="${1:-.}"
shift || true
OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o|--output) OUT="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "slim-all.sh: unknown arg: $1" >&2; exit 2 ;;
  esac
done

PARALLEL="${TOKOPT_BATCH_PARALLEL:-$(nproc 2>/dev/null || echo 4)}"

# ─── Dependency checks ────────────────────────────────────────────────────
if ! command -v tokopt >/dev/null 2>&1; then
  echo "slim-all.sh: tokopt not found in PATH" >&2
  echo "  Install: curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh | sh" >&2
  exit 2
fi

if [ ! -d "$ROOT" ]; then
  echo "slim-all.sh: root is not a directory: $ROOT" >&2
  exit 2
fi

# ─── Discover files ───────────────────────────────────────────────────────
# Customization file set mirrors tokopt-vscode COPILOT_CUSTOMIZATION_LANGS.
# Uses -print0 / xargs -0 throughout for filenames with spaces.
discover() {
  find "$ROOT" \
    \( -path '*/.git'         -prune \) -o \
    \( -path '*/node_modules' -prune \) -o \
    \( -path '*/vendor'       -prune \) -o \
    \( -type f \( \
         -name 'SKILL.md' -o \
         -name '*.agent.md' -o \
         -name '*.prompt.md' -o \
         -name '*.chatmode.md' -o \
         -name 'copilot-instructions.md' -o \
         -name 'AGENTS.md' -o \
         -name 'CLAUDE.md' \
    \) -print0 \)
}

# ─── Count files ──────────────────────────────────────────────────────────
TOTAL=0
while IFS= read -r -d '' _f; do
  TOTAL=$((TOTAL + 1))
done < <(discover)

if [ "$TOTAL" -eq 0 ]; then
  echo "slim-all.sh: no customization files found under $ROOT" >&2
  exit 2
fi

# ─── Output sink ──────────────────────────────────────────────────────────
# If -o given, truncate target; otherwise write to stdout. Workers append
# to file via flock-free `>>` redirect (single-line writes are atomic on
# POSIX for buffers < PIPE_BUF, which our JSON-per-line records are).
if [ -n "$OUT" ]; then
  : > "$OUT"
  SINK="$OUT"
else
  SINK="/dev/stdout"
fi

echo "slim-all.sh: $TOTAL file(s) under $ROOT, parallel=$PARALLEL" >&2

# ─── Worker (invoked per file) ────────────────────────────────────────────
# tokopt slim emits PRETTY-printed JSON; pipe through `jq -c .` to compact
# into one line per record (true JSONL). If jq is missing, fall back to a
# Python one-liner.
run_one() {
  local f="$1"
  local raw
  if raw=$(tokopt slim --input "$f" --format=json 2>/dev/null); then
    if command -v jq >/dev/null 2>&1; then
      printf '%s' "$raw" | jq -c .
    else
      printf '%s' "$raw" | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)))'
    fi
    return 0
  else
    echo "FAIL: $f" >&2
    return 1
  fi
}
export -f run_one

# ─── Run ──────────────────────────────────────────────────────────────────
ERR_FILE=$(mktemp -t slim-all-err.XXXXXX)
trap 'rm -f "$ERR_FILE"' EXIT

discover | \
  xargs -0 -n1 -P "$PARALLEL" bash -c 'run_one "$@"' _ \
  >> "$SINK" 2> >(tee "$ERR_FILE" >&2) || true

# Wait for the tee subshell to flush ERR_FILE
wait

# grep -c prints "0" to stdout when zero matches (and exits 1) — `|| true`
# swallows the exit code so the count is preserved.
FAIL=$(grep -c '^FAIL: ' "$ERR_FILE" 2>/dev/null || true)
FAIL=${FAIL:-0}

# ─── Report + exit ────────────────────────────────────────────────────────
PASS=$((TOTAL - FAIL))
echo "slim-all.sh: done — $PASS/$TOTAL succeeded, $FAIL failed" >&2

if [ "$FAIL" -eq 0 ]; then
  exit 0
elif [ "$FAIL" -gt $((TOTAL / 2)) ]; then
  exit 2
else
  exit 1
fi
