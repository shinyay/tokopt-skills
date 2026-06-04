---
name: prompt-anatomy
description: Decompose a single LLM prompt into the seven canonical segments (system, always-on, tools, history, retrieved, user, reasoning) and show where the tokens go. Use when a user asks "where are my tokens going?", "why is this prompt so big?", or wants to compare a before/after refactor.
---

# prompt-anatomy

Run `tokopt anatomy` to see the per-segment token breakdown.

## When to use

- A single prompt feels expensive and the user wants to know which
  segment dominates.
- Before/after a refactor — re-run anatomy and quote the deltas.
- When tuning history truncation, retrieved context limits, or tool
  catalog size — anatomy isolates the effect.

## How to invoke

If `tokopt` is on PATH, use it directly. Otherwise run from the repo:

```bash
(cd tools/tokopt && go run ./cmd/tokopt anatomy ...)
```

### Auto-classify a single customization file (preferred, `tokopt v0.6.0+`)

For Copilot/agent files with recognisable shape — `*.agent.md`,
`SKILL.md`, `copilot-instructions.md`, `AGENTS.md`, `*.instructions.md`,
`*.chatmode.md`, `*.prompt.md`, MCP configs — pass the file positionally
and `tokopt anatomy` will auto-classify it into the right segment:

```bash
tokopt anatomy ./.github/agents/my-agent.agent.md
# Output prepends: ↑ inferred segment: user (rule: *.agent.md → conditional → agent body)
#                  …followed by the standard per-segment breakdown.
```

JSON mode also emits `inferred_segment` and `inference_rule` fields
(both `omitempty` — absent for flag-driven invocations):

```bash
tokopt anatomy ./.github/skills/foo/SKILL.md --format=json
# {…, "inferred_segment": "retrieved",
#      "inference_rule": "SKILL.md → on-demand → retrieved skill context"}
```

If the file's shape is unrecognised, the command exits non-zero with an
`UNRECOGNIZED_SHAPE` error envelope and suggests the explicit fallback
form below.

### For multi-segment composition (explicit flags)

When you have separate files per segment — e.g. you're staging a full
prompt for before/after measurement — pass each segment via its flag:

```bash
tokopt anatomy \
  --system     ./prompt-parts/system.md \
  --always-on  ./prompt-parts/always-on.md \
  --tools      ./prompt-parts/tools.json \
  --history    ./prompt-parts/history.txt \
  --retrieved  ./prompt-parts/retrieved.txt \
  --user       ./prompt-parts/user.txt
```

…or pipe a JSON object whose keys mirror the flag names. Both
`always_on` and `always-on` are accepted; unknown keys are rejected:

```bash
echo '{"system":"…","always-on":"…","user":"…"}' | tokopt --format json anatomy --json -
```

The positional form (`tokopt anatomy <file>`) and flag form
(`tokopt anatomy --user <file>`) are mutually exclusive — combining them
returns a clear error pointing at whichever form best fits the use case.

## How to read the output

Look for a single segment that dominates. Common culprits:

- `tools` > 30 % → see the `antipattern-scan` skill (mcp-overload,
  verbose-tool-descriptions).
- `history` > 40 % → truncation or summarisation is overdue (Ch 13).
- `retrieved` > 50 % → over-retrieval; tighten `k` or rerank (Ch 12 P3).
- `always-on` > 25 % → run `token-audit`; the static config is too fat.

The tool currently emits warnings for:

- `user` < 1 % of input
- `system + always-on + tools` > 50 % of input
- `history` > 40 % of input
- `reasoning` > 20 % of input (when supplied)

If you provide only some segments, cross-segment ratios involving the
missing ones are skipped and a `partial input` note is added so the
remaining warnings are not misread.
