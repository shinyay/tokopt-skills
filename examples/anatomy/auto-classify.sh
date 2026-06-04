#!/usr/bin/env bash
#
# auto-classify.sh — Run `tokopt anatomy <file> --format=json` across every
# recognised Copilot/agent customization file under one or more root
# directories, in parallel, emitting JSONL (one record per file). Useful for
# "which agent files cost the most user/retrieved tokens?" audits.
#
# Why per-FILE, not per-directory?
#   `tokopt anatomy` (v0.6.0+) decomposes a SINGLE prompt into segments. Its
#   positional form auto-classifies the file by name shape:
#     copilot-instructions.md / AGENTS.md / instructions.md  → always-on
#     *.agent.md / *.chatmode.md / *.instructions.md         → conditional
#     SKILL.md / *.prompt.md / MCP configs                   → on-demand
#   Each output line carries `inferred_segment` + `inference_rule` so the
#   JSONL is sortable and self-describing without a separate manifest.
#
# Usage:
#   ./auto-classify.sh                       # default root: .
#   ./auto-classify.sh ~/work/repo-a ~/work/repo-b
#   ./auto-classify.sh ~/work/team/*         # shell expands to many dirs
#   ./auto-classify.sh ROOT1 -o <file>       # write JSONL to <file>
#   TOKOPT_BATCH_PARALLEL=4 ./auto-classify.sh ~/work/team/*
#
# Output: JSONL — each line is
#   {file, format_version, encoding, segments, total_input_tokens,
#    inferred_segment, inference_rule, ...}
#   where `file` is spliced in via jq so each row is self-describing.
#
# Exit codes:
#   0  all files processed cleanly
#   1  1..50% of files failed
#   2  >50% of files failed (or no files found, or missing dependencies)
#
# Requires: tokopt v0.6.0+, jq, find, xargs
# See examples/anatomy/README.md for the full recipe and prerequisites.
set -uo pipefail

# ─── Argument parsing ─────────────────────────────────────────────────────
ROOTS=()
OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o|--output) OUT="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,35p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "auto-classify.sh: unknown flag: $1" >&2
      exit 2 ;;
    *) ROOTS+=("$1"); shift ;;
  esac
done

if [ "${#ROOTS[@]}" -eq 0 ]; then
  ROOTS=(".")
fi

PARALLEL="${TOKOPT_BATCH_PARALLEL:-$(nproc 2>/dev/null || echo 4)}"

# ─── Dependency checks ────────────────────────────────────────────────────
if ! command -v tokopt >/dev/null 2>&1; then
  echo "auto-classify.sh: tokopt not found in PATH" >&2
  echo "  Install: curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh | sh" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "auto-classify.sh: jq not found in PATH" >&2
  echo "  Install: apt install jq  /  brew install jq" >&2
  exit 2
fi

# Validate every root is a directory
for r in "${ROOTS[@]}"; do
  if [ ! -d "$r" ]; then
    echo "auto-classify.sh: not a directory: $r" >&2
    exit 2
  fi
done

# ─── Discover recognised files under all roots ────────────────────────────
# Mirror the shapes recognised by tokopt v0.6.0+ internal/classify:
#   anchored (root or .github/): copilot-instructions.md, AGENTS.md, instructions.md
#   anchored (.github/skills/*/): SKILL.md
#   anchored (.copilot|.vscode|.cursor): mcp-config.json, mcp.json
#   suffix anywhere: *.agent.md, *.chatmode.md, *.instructions.md, *.prompt.md
#
# We are intentionally lax in discovery — `tokopt anatomy` itself does the
# strict classification and returns UNRECOGNIZED_SHAPE for false positives,
# which we count as failures (informative; sorted to bottom).
FILES_FILE=$(mktemp -t auto-classify-files.XXXXXX)
trap 'rm -f "$FILES_FILE" "$ERR_FILE" 2>/dev/null' EXIT

for r in "${ROOTS[@]}"; do
  find "$r" \
    \( -name 'copilot-instructions.md' \
       -o -name 'AGENTS.md' \
       -o -name 'instructions.md' \
       -o -name 'SKILL.md' \
       -o -name 'mcp-config.json' \
       -o -name 'mcp.json' \
       -o -name '*.agent.md' \
       -o -name '*.chatmode.md' \
       -o -name '*.instructions.md' \
       -o -name '*.prompt.md' \) \
    -type f -print0 2>/dev/null
done > "$FILES_FILE"

TOTAL=$(tr -cd '\0' < "$FILES_FILE" | wc -c)

if [ "$TOTAL" -eq 0 ]; then
  echo "auto-classify.sh: no recognised customization files found under: ${ROOTS[*]}" >&2
  exit 2
fi

# ─── Output sink ──────────────────────────────────────────────────────────
if [ -n "$OUT" ]; then
  : > "$OUT"
  SINK="$OUT"
else
  SINK="/dev/stdout"
fi

echo "auto-classify.sh: $TOTAL file(s), parallel=$PARALLEL" >&2

# ─── Worker — single file, emit one JSON line tagged with file path ───────
run_one() {
  local file="$1"
  local raw
  if raw=$(tokopt anatomy "$file" --format=json 2>/dev/null); then
    printf '%s' "$raw" | jq -c --arg f "$file" '. + {file: $f}'
    return 0
  else
    echo "FAIL: $file" >&2
    return 1
  fi
}
export -f run_one

# ─── Run ──────────────────────────────────────────────────────────────────
ERR_FILE=$(mktemp -t auto-classify-err.XXXXXX)

# Pass files to xargs via NUL-delimited stream — filename-safe.
xargs -0 -a "$FILES_FILE" -n1 -P "$PARALLEL" bash -c 'run_one "$@"' _ \
  >> "$SINK" 2> >(tee "$ERR_FILE" >&2) || true

wait

FAIL=$(grep -c '^FAIL: ' "$ERR_FILE" 2>/dev/null || true)
FAIL=${FAIL:-0}
PASS=$((TOTAL - FAIL))
echo "auto-classify.sh: done — $PASS/$TOTAL succeeded, $FAIL failed" >&2

if [ "$FAIL" -eq 0 ]; then
  exit 0
elif [ "$FAIL" -gt $((TOTAL / 2)) ]; then
  exit 2
else
  exit 1
fi
