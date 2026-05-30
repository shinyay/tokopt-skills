#!/usr/bin/env bash
# Local pre-commit hook: gate commits that push always-on token tax
# over $TOKOPT_THRESHOLD tokens. Designed to be wired as a `local`
# pre-commit hook (see .pre-commit-config.yaml in this directory).
#
# Requires the tokopt binary on PATH. Install once with:
#   curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh | sh
#
# Environment overrides:
#   TOKOPT_THRESHOLD   max always-on tax in tokens (default: 1500)
#   TOKOPT_AUDIT_PATH  path to audit (default: . — repo root)

set -euo pipefail

THRESHOLD="${TOKOPT_THRESHOLD:-1500}"
AUDIT_PATH="${TOKOPT_AUDIT_PATH:-.}"

if ! command -v tokopt >/dev/null 2>&1; then
  cat >&2 <<'EOF'
[token-budget] tokopt not found on PATH.

Install it with:

  curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh | sh

Then re-try `git commit`.
EOF
  exit 1
fi

exec tokopt report --threshold "$THRESHOLD" "$AUDIT_PATH"
