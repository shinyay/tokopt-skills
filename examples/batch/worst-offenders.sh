#!/usr/bin/env bash
#
# worst-offenders.sh — Print the top-N files by token count in a repo,
# sorted descending. Uses `tokopt audit . --format=json` (which already
# walks directories internally) and pipes through jq.
#
# Usage:
#   ./worst-offenders.sh [root] [top-n]
#
# Defaults: root=.  top-n=10
#
# Output: plain-text aligned table to stdout.
#
# Exit codes:
#   0  success
#   2  missing dependencies or `tokopt audit` failure
#
# See examples/batch/README.md for the full recipe and prerequisites.
set -uo pipefail

ROOT="${1:-.}"
TOP_N="${2:-10}"

# ─── Dependency checks ────────────────────────────────────────────────────
if ! command -v tokopt >/dev/null 2>&1; then
  echo "worst-offenders.sh: tokopt not found in PATH" >&2
  echo "  Install: curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh | sh" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "worst-offenders.sh: jq not found in PATH" >&2
  echo "  Install: apt install jq  /  brew install jq" >&2
  exit 2
fi

if [ ! -d "$ROOT" ]; then
  echo "worst-offenders.sh: root is not a directory: $ROOT" >&2
  exit 2
fi

case "$TOP_N" in
  ''|*[!0-9]*)
    echo "worst-offenders.sh: top-n must be a positive integer (got: $TOP_N)" >&2
    exit 2 ;;
esac

# ─── Audit + format ───────────────────────────────────────────────────────
if ! AUDIT=$(tokopt audit "$ROOT" --format=json 2>/dev/null); then
  echo "worst-offenders.sh: tokopt audit failed for $ROOT" >&2
  exit 2
fi

# Detect zero files cleanly
FILE_COUNT=$(printf '%s' "$AUDIT" | jq '.files | length')
if [ "$FILE_COUNT" -eq 0 ]; then
  echo "worst-offenders.sh: no customization files audited under $ROOT" >&2
  exit 0
fi

ENCODING=$(printf '%s' "$AUDIT" | jq -r '.encoding')

printf 'Top %s files by tokens (encoding=%s, root=%s):\n\n' "$TOP_N" "$ENCODING" "$ROOT"
printf '%-7s %-13s %s\n' "TOKENS" "SCOPE" "PATH"

printf '%s' "$AUDIT" | jq -r \
  --argjson n "$TOP_N" '
    .files
    | sort_by(-.tokens)
    | .[:$n]
    | .[]
    | [.tokens, .scope, .path]
    | @tsv
  ' | \
  awk -F'\t' '{ printf "%7s %-13s %s\n", $1, $2, $3 }'
