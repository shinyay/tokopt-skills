# `examples/anatomy/` — multi-file `anatomy` auto-classification recipe

> **Goal**: run `tokopt anatomy <file>` across every recognised Copilot/agent customization file in one or more repositories, in parallel, and emit JSONL with per-file `inferred_segment` + `total_input_tokens`. Useful for audits like "which agent files cost the most `user` tokens?" or "show all `retrieved` segment skills sorted by size."

This directory ships **one POSIX shell script** that wraps the `tokopt v0.6.0+` positional auto-classify form:

| Script | What it does | Output |
|---|---|---|
| [`auto-classify.sh`](auto-classify.sh) | Discover recognised customization files under one or more roots; run `tokopt anatomy <file> --format=json` in parallel; emit JSONL (one record per file) | JSONL → stdout, file via `-o`, or default sink |

> ⚠️ **You do NOT need the `tokopt-skills` Copilot CLI plugin** for this script. It uses the `tokopt` CLI binary directly. The plugin is only for interactive Copilot workflows on developer machines.

---

## When to use `examples/anatomy/` vs the `prompt-anatomy` skill

| Surface | Use when… |
|---|---|
| **`skills/prompt-anatomy/SKILL.md`** (interactive) | A user asks "where are my tokens going for THIS prompt?" — single file, one-shot, rendered breakdown in the Copilot conversation. |
| **`examples/anatomy/auto-classify.sh`** (batch) | You want a machine-readable JSONL feed across many files — for sorting, dashboards, leaderboards, or audit reports. Pipe through `jq` to filter/sort downstream. |

The two surfaces share the same classifier — `auto-classify.sh` just batches what the skill does one file at a time.

---

## Prerequisites

| Tool | Why | Install |
|---|---|---|
| `tokopt` **v0.6.0+** | The positional `anatomy <file>` form (auto-classify) was added in v0.6.0. Earlier versions reject file arguments. | `curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh \| sh` |
| `jq` | Splices `file` field into each JSON record and is the recommended downstream filter. | `apt install jq` / `brew install jq` |
| `find` + `xargs` (with `-0`) | Filename-safe discovery and parallel dispatch. Both ship in GNU coreutils and BSD userland. | Pre-installed on Linux/macOS. |

---

## Quick start

```bash
# Audit one repo (current directory)
./auto-classify.sh > anatomy.jsonl

# Audit several repos in parallel (4 workers default; override via env)
TOKOPT_BATCH_PARALLEL=8 ./auto-classify.sh ~/work/repo-a ~/work/repo-b

# Top-10 agent files by user-segment cost
./auto-classify.sh ~/work/team/* | \
  jq -r 'select(.inferred_segment=="user") | "\(.total_input_tokens)\t\(.file)"' | \
  sort -rn | head -10
```

---

## Example output (one line per file)

```json
{"file":".github/agents/token-doctor.agent.md","format_version":"v1","encoding":"o200k_base","segments":[…],"total_input_tokens":1187,"inferred_segment":"user","inference_rule":"*.agent.md → conditional → agent body"}
{"file":".github/skills/heavy-tail/SKILL.md","format_version":"v1","encoding":"o200k_base","segments":[…],"total_input_tokens":634,"inferred_segment":"retrieved","inference_rule":"SKILL.md → on-demand → retrieved skill context"}
```

The `inferred_segment` and `inference_rule` fields are emitted only when auto-classification succeeded (`omitempty` on the binary side). Flag-driven invocations (`tokopt anatomy --user file.md`) deliberately omit them — that surface is unchanged from `tokopt v0.5.x`.

---

## File shapes recognised

`auto-classify.sh` discovers files using `find`; `tokopt anatomy` then strictly classifies each one. The shapes recognised in `tokopt v0.6.0`:

| Shape | Cost class | Inferred segment |
|---|---|---|
| `copilot-instructions.md` (root or `.github/`) | always-on | `always-on` |
| `AGENTS.md` (root or `.github/`) | always-on | `always-on` |
| `instructions.md` (root) | always-on | `always-on` |
| `*.instructions.md` | conditional | `system` |
| `*.agent.md` | conditional | `user` |
| `*.chatmode.md` | conditional | `system` |
| `SKILL.md` (under `.github/skills/*/`) | on-demand | `retrieved` |
| `*.prompt.md` | on-demand | `user` |
| `mcp-config.json` / `mcp.json` (`.copilot/`, `.vscode/`, `.cursor/`) | conditional | `tools` |

Files outside these shapes return an `UNRECOGNIZED_SHAPE` error envelope and count as failures in the script's exit-code tier.

---

## Exit codes

| Code | Meaning |
|---|---|
| `0` | All files processed cleanly. |
| `1` | 1–50% of files failed. Inspect stderr for `FAIL: <path>` lines (typically `UNRECOGNIZED_SHAPE` for genuinely unrecognised files swept up by `find`). |
| `2` | >50% of files failed, or no files found, or missing dependencies. Treat as a setup or scope error rather than a per-file noise issue. |

---

## See also

- [`skills/prompt-anatomy/SKILL.md`](../../skills/prompt-anatomy/SKILL.md) — interactive single-file workflow.
- [`examples/batch/`](../batch/) — multi-file `slim` / `detect` / leaderboard recipes (different command, same xargs-NUL pattern).
- [`tokopt anatomy <file>` CLI docs](https://shinyay.github.io/getting-started-with-token-optimization/cli/commands/anatomy/) — full reference for the positional auto-classify surface.
