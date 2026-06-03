# `examples/batch/` — multi-file `slim` / `detect` / leaderboard scripts

> **Goal**: run `tokopt slim`, `tokopt detect`, and "top-N worst offenders" across **many files at once** — for monorepos, organizations, or one-off audits — without rolling your own `xargs` loop and tripping over concurrency, filenames-with-spaces, or partial-failure semantics.

This directory ships **three POSIX shell scripts** you can use as-is or adapt to your repo layout:

| Script | What it does | Output |
|---|---|---|
| [`slim-all.sh`](slim-all.sh) | Run `tokopt slim --input <file> --format=json` on every customization file under a root, in parallel | JSONL (one record per file) → stdout, file via `-o`, or `slim-results.jsonl` default |
| [`detect-all.sh`](detect-all.sh) | Run `tokopt detect <dir> --format=json` across one or more root directories, in parallel | JSONL (one record per root, with `root` field spliced in) → stdout or file via `-o` |
| [`worst-offenders.sh`](worst-offenders.sh) | Combine `tokopt audit . --format=json` with `jq` to produce a sorted top-N leaderboard of files by token count | Plain-text table → stdout |

> ⚠️ **You do NOT need the `tokopt-skills` Copilot CLI plugin** for these scripts. They use the `tokopt` CLI binary directly. The plugin is only for interactive Copilot workflows on developer machines.

---

## Prerequisites

| Tool | Why | Install |
|---|---|---|
| [`tokopt`](https://github.com/shinyay/tokopt) | Does the work | `curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh \| sh` |
| `jq` | Parses JSON in `worst-offenders.sh` and is recommended for post-processing JSONL | `apt install jq` / `brew install jq` |
| `find`, `xargs` | POSIX, ships everywhere | _(already installed)_ |

GNU `parallel` works as a drop-in for `xargs -P` if you prefer, but it's not required.

---

## Customization file set

All three scripts target the same **customization file set**, mirroring the [`tokopt-vscode`](https://github.com/shinyay/tokopt-vscode) extension's `COPILOT_CUSTOMIZATION_LANGS` coverage:

- `**/SKILL.md`
- `**/*.agent.md`
- `**/*.prompt.md`
- `**/*.chatmode.md`
- `**/copilot-instructions.md`
- `**/AGENTS.md`
- `**/CLAUDE.md`

By default `find` is configured to **skip** `.git/`, `node_modules/`, and `vendor/` directories. Edit the `PATTERNS` and prune list at the top of each script if your repo uses other locations.

---

## Concurrency

All scripts use `xargs -P "${TOKOPT_BATCH_PARALLEL:-$(nproc)}"` — one worker per CPU by default. Override via env var:

```bash
TOKOPT_BATCH_PARALLEL=4 ./slim-all.sh ~/myrepo
```

`tokopt slim` is CPU-bound for tokenization, so `$(nproc)` is usually the right ceiling. For very large repos on shared CI runners, halve it to keep neighbours happy.

---

## Filenames with spaces

All scripts use `find -print0 | xargs -0` throughout — filenames containing spaces, tabs, newlines, or other unusual characters are handled correctly. Test with:

```bash
mkdir -p /tmp/space-test && touch '/tmp/space-test/a b.SKILL.md'
./slim-all.sh /tmp/space-test
```

---

## Exit codes

All three scripts use the same **3-tier exit semantics**:

| Exit | Meaning |
|---|---|
| **0** | All files processed cleanly |
| **1** | Some files failed (between 1 and 50% of total) |
| **2** | Majority failed (>50% of total) — likely a systemic problem (wrong tokopt version, missing binary, permission error) |

Per-file failures are **always** logged to stderr with the file path; the script continues to the next file. The aggregate exit code lets you wire scripts into CI without losing per-file detail.

---

## Recipe 1 — `slim-all.sh`

📁 [`slim-all.sh`](slim-all.sh)

### Use case

Preview slim savings across all customization files in a repo or organization, before deciding which files to actually compress.

### Run

```bash
# Dry-run preview against the current directory
./examples/batch/slim-all.sh .

# Against a different root, with explicit output path
./examples/batch/slim-all.sh ~/myrepo -o /tmp/slim-org.jsonl

# Limit to 4 workers
TOKOPT_BATCH_PARALLEL=4 ./examples/batch/slim-all.sh .
```

### Output (JSONL)

Each line is the full single-file `slim` JSON record (`format_version: "v1"`):

```jsonc
{"format_version":"v1","path":".github/copilot-instructions.md","encoding":"o200k_base","original_tokens":121,"compressed_tokens":118,"saved_tokens":3,"saved_percent":2.48,...}
{"format_version":"v1","path":"AGENTS.md","encoding":"o200k_base","original_tokens":113,"compressed_tokens":98,"saved_tokens":15,"saved_percent":13.27,...}
```

### Post-process — top savings opportunities

```bash
./examples/batch/slim-all.sh . | \
  jq -r 'select(.saved_tokens > 0) | "\(.saved_tokens)\t\(.saved_percent)%\t\(.path)"' | \
  sort -rn | head -10
```

### Note — slim runs in dry-run mode by design

This recipe **does not pass `--apply`** — you get a preview only. To actually compress a file, run `tokopt slim --input <file> --apply` interactively after reviewing the preview. **Never `--apply` in a batch loop** — slim's safety semantics are per-file, and a batch `--apply` defeats the dogfood-then-commit workflow.

---

## Recipe 2 — `detect-all.sh`

📁 [`detect-all.sh`](detect-all.sh)

### Use case

Find anti-patterns (kitchen-sink instructions, format inflation, etc.) across **one or more root directories** — for monorepo subtrees, multi-team setups, or sibling repos under one parent dir.

### Why per-directory (not per-file)?

`tokopt detect` walks a directory looking for the standard customization locations (`.github/copilot-instructions.md`, `.github/agents/*.agent.md`, `.github/skills/*/SKILL.md`, `AGENTS.md`, `CLAUDE.md`). It does **not** accept an individual file. So the batch shape for `detect` is "many roots", not "many files" — the script parallelizes across roots.

### Run

```bash
# Single repo (default root = .)
./examples/batch/detect-all.sh

# Multiple sibling repos in parallel
./examples/batch/detect-all.sh ~/work/repo-a ~/work/repo-b ~/work/repo-c -o /tmp/detect-org.jsonl

# Shell-expanded glob (e.g., one root per team)
./examples/batch/detect-all.sh ~/work/team/*

# Limit to 4 workers
TOKOPT_BATCH_PARALLEL=4 ./examples/batch/detect-all.sh ~/work/team/*
```

### Output (JSONL)

Each line is the per-root `detect` JSON with a `root` field spliced in (via `jq`) so each record is self-describing:

```jsonc
{"format_version":"v1","root":"/home/me/work/repo-a","findings":[{"detector":"kitchen-sink","severity":"warn","file":".github/copilot-instructions.md","line":42}]}
{"format_version":"v1","root":"/home/me/work/repo-b","findings":[]}
```

### Post-process — roots with any finding

```bash
./examples/batch/detect-all.sh ~/work/repo-* | \
  jq -r 'select(.findings != null and (.findings | length) > 0) | .root'
```

### Post-process — count findings per severity across all roots

```bash
./examples/batch/detect-all.sh ~/work/repo-* | \
  jq -r '.findings[]?.severity' | sort | uniq -c | sort -rn
```

### Post-process — flatten findings with their originating root

```bash
./examples/batch/detect-all.sh ~/work/repo-* | \
  jq -c '.findings[]? as $f | {root, $f}'
```

---

## Recipe 3 — `worst-offenders.sh`

📁 [`worst-offenders.sh`](worst-offenders.sh)

### Use case

Identify the top-N files by token count in a repo, so you know where slimming will have the biggest impact.

This script is **different from `slim-all` / `detect-all`** — it uses `tokopt audit . --format=json` (which is **already directory-aware** and walks the tree internally) instead of per-file `xargs`. Faster for this use case; no parallelism needed.

### Run

```bash
# Top 10 by default
./examples/batch/worst-offenders.sh .

# Top 20
./examples/batch/worst-offenders.sh . 20

# Different root
./examples/batch/worst-offenders.sh ~/myrepo
./examples/batch/worst-offenders.sh ~/myrepo 25
```

### Output (plain text)

```text
Top 10 files by tokens (encoding=o200k_base, root=.):

TOKENS  SCOPE         PATH
  1261  conditional   agents/token-doctor.agent.md
   833  conditional   agents/prompt-optimizer.agent.md
   820  on-demand     skills/hygiene-coach/SKILL.md
   742  on-demand     skills/slim-apply/SKILL.md
   670  on-demand     skills/antipattern-scan/SKILL.md
   ...
```

---

## CI integration

These scripts are intended for **interactive** or **scheduled** runs, not for blocking PRs. For PR gating, use [`examples/ci/`](../ci/) instead.

But if you want a weekly leaderboard posted to a tracking issue (similar to [`examples/scheduled/`](../scheduled/)), combine `worst-offenders.sh` with `gh issue comment`:

```bash
LEADERBOARD=$(./examples/batch/worst-offenders.sh . 20)
gh issue comment 42 --body "$(printf '## Weekly leaderboard\n\n```text\n%s\n```' "$LEADERBOARD")"
```

---

## See also

- [`examples/ci/`](../ci/) — PR-time threshold gating (GitHub Actions + pre-commit)
- [`examples/scheduled/`](../scheduled/) — weekly cron drift detection
- [tokopt repo](https://github.com/shinyay/tokopt) — CLI source + releases
- [`tokopt-vscode`](https://github.com/shinyay/tokopt-vscode) — same customization file set; CodeLens + Quick Fix in the editor
