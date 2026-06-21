---
name: model-cost-compare
description: Rank every model in the tokopt rate card by the projected AI Credit cost of a repo's token tax, cheapest first, via `tokopt report --by-model`. Use when a user asks "which model is cheapest for this repo?", "compare model cost", or "how much would Opus vs mini cost here?".
---

# model-cost-compare

Model choice is one of the two biggest levers on a Copilot/agent bill —
right alongside cutting tokens. The same repository can cost 20×+ more on
a frontier model than on a small one, every single turn. This skill puts
*your repo's* real token counts onto every model in the rate card so the
choice is measured, not guessed.

## When to use

- The user asks which model is cheapest (or most expensive) for their
  repository or always-on config.
- After `token-audit` quantifies the token tax, to turn that token number
  into a per-model AI Credit cost comparison.
- When the user is weighing a model switch ("is Opus worth it here?") and
  wants the cost delta grounded in their actual configuration.

## How to invoke

Requires **tokopt CLI ≥ 0.10.0** (the `report --by-model` flag). If
`tokopt` is on PATH, use it directly. Otherwise run from the source repo
(pass the repo you want to analyse explicitly — the subshell `cd`s into
the CLI source, so `.` would point at the wrong directory):

```bash
(repo="$PWD"; cd tools/tokopt && go run ./cmd/tokopt report --by-model "$repo")
```

`report --by-model` runs the audit once, then projects the repo's
token tax onto **every model in the active rate card**, ranked by
projected AI Credit (nano-AIU) cost, cheapest first.

```bash
tokopt report --by-model .
tokopt --format json report --by-model .
tokopt --format md report --by-model .
tokopt report --by-model --credit-rates ./my-rates.json .
```

- It is **focused output**: `--by-model` skips anti-pattern detection. It
  cannot be combined with `--credit-model` (which picks a single model) or
  `--threshold` (which gates the plain report) — both error fast.
- `--credit-rates <path>` ranks an external rate card's models instead of
  the embedded default.
- The `--format json` envelope is stable (`format_version` `v1`) with a
  `repo` block and a sorted `models` array — use it when you need to pull
  out specific numbers.
- **If `--by-model` errors** (an older CLI without the flag), check
  `tokopt --version`. If it is below `0.10.0`, ask the user to upgrade
  (or use the source fallback above). Do **not** reconstruct the ranking
  by hand from token counts and rates — only report numbers the CLI
  actually printed.

## How to read the output

- **Cheapest first.** The list is sorted ascending by always-on AI Credit
  cost. The cheapest row is the floor; the `REL` column shows each model
  as a multiple of it (e.g. `20.0x`).
- **`ALWAYS-ON AIU` vs `TOTAL AIU`.** Always-on is paid on *every* turn
  (the recurring cost model choice most affects). Total is the worst-case
  per-turn cost if conditional and on-demand context all trigger at once.
- **`BASIS` column.**
  - `empirical` = a rate measured from real Copilot CLI sessions.
  - `catalog` = derived from the official list price; treat it as a
    **conservative upper bound** (full input price, no cache / output /
    reasoning discount). Real cost is usually lower.
- The ranking generally follows each model's per-input-token rate (the
  same repo token counts are projected onto every model); the CLI's actual
  sort key is always-on AI Credit cost. The value of the view is attaching
  the user's *absolute* per-turn numbers to each model.

## What not to do

- Do not invent or round numbers the CLI did not print. Report exactly
  what `report --by-model` returned (this is the same discipline every
  tokopt skill follows).
- Do not present a `catalog` rate as an exact bill. Say it is a list-price
  upper bound and that cache hits, output, and reasoning move the real
  figure down.
- Do not convert AI Credits to a dollar amount unless the user asks; the
  honest unit here is the credit. If they do ask, use only
  `1 AIU = $0.01`, keep the CLI's printed AIU values, and label the dollar
  figure as a derived conversion.
- Do not recommend the cheapest model unconditionally — surface the cost
  ranking and let quality requirements drive the final choice.
