# `examples/ci/` — drop-in token-budget recipes for downstream repos

> **Goal**: install [`tokopt`](https://github.com/shinyay/tokopt) in your CI / git hooks and **gate** any pull request (or commit) that pushes your always-on Copilot token tax over a budget you choose.

This directory ships two recipes you can copy verbatim into your own repository. They are independent — pick whichever fits your workflow, or use both for defense-in-depth.

> ⚠️ **You do NOT need the `tokopt-skills` Copilot CLI plugin for CI.** These recipes use the `tokopt` CLI binary directly. The plugin is only for interactive Copilot workflows on developer machines.

---

## When to use which

| | GitHub Actions | Pre-commit hook |
|---|---|---|
| **When it runs** | On every PR + push to `main` (also manually via `workflow_dispatch`) | Locally, on every `git commit` |
| **Feedback latency** | Minutes (after push) | Seconds (before commit lands) |
| **Failure mode** | Red ❌ on the PR — visible to reviewers | Commit refused — developer sees it immediately |
| **Bypass** | None unless workflow disabled | `git commit --no-verify` (escape hatch) |
| **Best for** | **Last-line defense** — catches what slipped past hooks; visible to the whole team | **Early gate** — cheapest feedback loop; keeps `main` clean |

**Recommendation**: run **both**. The hook keeps developers honest before push; the Action catches anyone who forgot to install hooks (or used `--no-verify`).

---

## Recipe 1 — GitHub Actions

📁 [`github-actions/token-budget.yml`](github-actions/token-budget.yml)

### Install

1. Copy `github-actions/token-budget.yml` to `.github/workflows/token-budget.yml` in your repo.
2. Commit + push. That's it — the workflow runs on the next PR.

### Knobs

Tune the defaults at the top of the file (`env:` block), or override per-run via the **Actions tab → Run workflow** UI:

| Input / env var | Default | What it does |
|---|---|---|
| `threshold` / `TOKOPT_THRESHOLD` | `1500` | Maximum allowed always-on token tax. Build fails (in `fail` mode) if `tokopt report --threshold N` returns non-zero. |
| `budget-mode` / `TOKOPT_BUDGET_MODE` | `fail` | `fail` = hard gate (red CI); `warn` = annotation only (yellow ⚠️, CI stays green). |
| `tokopt-version` / `TOKOPT_VERSION` | _(empty = latest)_ | Pin to a specific tokopt release for reproducibility (recommended for production). Example: `v0.1.0`. See [shinyay/tokopt releases](https://github.com/shinyay/tokopt/releases). |

### Triggers (no `paths` filter by default — why?)

The workflow runs on **every PR + push to main**, not just changes to obviously-customization files. This is intentional: customization files can live in arbitrary subdirectories (`.github/agents/`, `.copilot/skills/`, custom layouts) and a stricter path filter risks silently skipping high-impact changes. The audit is cheap (~10 seconds end-to-end), so correctness wins over savings.

If your repo is large and CI minutes matter, add a `paths:` filter:

```yaml
on:
  pull_request:
    paths:
      - '**/*.md'
      - '.github/copilot-instructions.md'
      - 'AGENTS.md'
```

### Hardening: pin the tokopt version

The default install uses `curl ... install.sh | sh` and pulls the latest release. For reproducible CI, set `TOKOPT_VERSION` (or pass `tokopt-version` input) to pin to a specific tag:

```yaml
env:
  TOKOPT_VERSION: v0.1.0
```

The installer **already verifies a `SHA256SUMS` file** from the matching release before extracting the tarball — no extra configuration needed.

**Supply-chain caveat**: pinning `TOKOPT_VERSION` pins the binary you download, but the workflow still fetches `scripts/install.sh` from `main`. For stricter supply-chain control (e.g. you don't want surprise installer changes), vendor the installer into your repo or fetch it from a pinned commit SHA via `https://raw.githubusercontent.com/shinyay/tokopt/<commit-sha>/scripts/install.sh`.

---

## Recipe 2 — pre-commit hook

📁 [`pre-commit/token-budget.sh`](pre-commit/token-budget.sh) + [`pre-commit/.pre-commit-config.yaml`](pre-commit/.pre-commit-config.yaml)

Requires the [pre-commit](https://pre-commit.com/) framework (`pip install pre-commit` or `brew install pre-commit`).

### Install — inline (minimal)

Add this to your repo's `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: local
    hooks:
      - id: tokopt-token-budget
        name: tokopt token-budget
        entry: tokopt report --threshold 1500 .
        language: system
        pass_filenames: false
        files: '(^AGENTS\.md$|^\.github/|^\.copilot/|\.md$|^\.pre-commit-config\.ya?ml$)'
```

Then:

```bash
pre-commit install   # one-time wire-up
```

### Install — wrapper script (recommended)

The wrapper adds a friendly "tokopt not installed" error message and centralizes the threshold via env vars.

1. Copy `pre-commit/token-budget.sh` to `tools/ci/token-budget.sh` in your repo, then `chmod +x tools/ci/token-budget.sh`.
2. Add the wrapper snippet from `pre-commit/.pre-commit-config.yaml` to your `.pre-commit-config.yaml`.
3. `pre-commit install`.

> 💡 **Overriding the threshold inline**: pre-commit does **not** run `entry:` through a shell, so `entry: TOKOPT_THRESHOLD=2000 tools/ci/token-budget.sh` will silently misbehave. Use `env` instead: `entry: env TOKOPT_THRESHOLD=2000 tools/ci/token-budget.sh`.

### Knobs (wrapper variant)

| Env var | Default | What it does |
|---|---|---|
| `TOKOPT_THRESHOLD` | `1500` | Max always-on tax. Hook exits non-zero (refuses commit) above this. |
| `TOKOPT_AUDIT_PATH` | `.` | Path to audit. Useful for monorepos targeting a subdir. |

---

## Maintenance: tuning the threshold

When the gate fires on a legitimate, intentional change (e.g. you genuinely need a longer `copilot-instructions.md`), the right response is usually:

1. Run `tokopt audit .` locally and confirm the new tax is reasonable for your team's budget.
2. Bump `TOKOPT_THRESHOLD` in `token-budget.yml` (and `.pre-commit-config.yaml` if you use the inline recipe).
3. **Commit the bump as a separate PR** with a short rationale. This makes the budget decision auditable.

When the gate fires on **unintentional bloat** (e.g. a new agent prompt accidentally became always-on), the right response is to slim the prompt — `tokopt slim`, `tokopt detect`, or `@token-doctor` in interactive Copilot can help.

---

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Workflow fails with `tokopt: command not found` after install step | Network blocked GitHub raw.githubusercontent.com — pin a version + mirror the install script in your runner image |
| Pre-commit refuses every commit including unrelated changes | Threshold set too low for current repo state. Run `tokopt audit .` to see current tax, bump threshold to current + headroom |
| `budget-mode=warn` shows yellow ⚠️ but PR still merges | Working as designed — `warn` only annotates. Switch to `fail` for a hard gate. |
| Workflow runs on every PR (annoying for non-content changes) | Add a `paths:` filter — see "Triggers" section above |

---

## See also

- **Plugin**: [`shinyay/tokopt-skills`](https://github.com/shinyay/tokopt-skills) — the Copilot CLI plugin (for interactive use on developer machines, not CI)
- **CLI binary**: [`shinyay/tokopt`](https://github.com/shinyay/tokopt) — the underlying Go CLI, with install.sh + multi-platform release binaries
- **Tutorial**: [`shinyay/getting-started-with-token-optimization`](https://github.com/shinyay/getting-started-with-token-optimization) — 14-chapter walkthrough of the theory + practice
