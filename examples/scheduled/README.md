# `examples/scheduled/` — drop-in weekly drift-detection recipe

> **Goal**: run [`tokopt audit`](https://github.com/shinyay/tokopt) on a **cron schedule** in your repo and post the **week-over-week delta** to a tracking issue (and, optionally, Slack). This catches the **slow-creeping drift** that PR-time CI cannot — a SKILL.md that grows 5% per week is invisible to a threshold gate until it crosses the threshold.

This directory ships **one recipe** you can copy verbatim. It is complementary to [`examples/ci/`](../ci/) — PR-time gating catches **spikes**, scheduled audit catches **drift**.

> ⚠️ **You do NOT need the `tokopt-skills` Copilot CLI plugin** for this recipe. It uses the `tokopt` CLI binary directly. The plugin is only for interactive Copilot workflows on developer machines.

---

## How it works

```text
┌──────────────────────┐
│ Mon 08:00 UTC (cron) │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────────────────┐
│ tokopt audit . --format=json     │
│ → total = sum(files[].tokens)    │
└──────────┬───────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ Search issues by label                  │
│   tokopt-weekly-audit                   │
│                                         │
│  ┌─ FOUND ──┐         ┌─ NOT FOUND ──┐  │
│  │ read     │         │ create new   │  │
│  │ baseline │         │ issue with   │  │
│  │ from body│         │ baseline=0   │  │
│  └────┬─────┘         └──────┬───────┘  │
└───────┼──────────────────────┼──────────┘
        │                      │
        └──────────┬───────────┘
                   ▼
         ┌──────────────────┐
         │ delta = total -  │
         │         baseline │
         └────────┬─────────┘
                  ▼
         ┌──────────────────┐
         │ Post comment +   │
         │ update body with │
         │ new baseline     │
         └────────┬─────────┘
                  │
                  ├──► (optional) Slack via SLACK_WEBHOOK_URL
                  │
                  ▼
                done
```

The tracking issue is the **source of truth** for the baseline — no external storage, no PAT, no DB. Idempotent by issue-label search.

---

## Install

1. **Copy the workflow**:
   ```bash
   mkdir -p .github/workflows
   cp examples/scheduled/github-actions/weekly-audit.yml \
      .github/workflows/tokopt-weekly-audit.yml
   ```

2. **Create the tracking label** (one-time setup):
   ```bash
   gh label create tokopt-weekly-audit \
     --color FBCA04 \
     --description "Tracking issue for tokopt weekly audit drift"
   ```
   The first run will then find no labelled issue and **create one** — no manual issue setup required.

3. **(Optional) Add the Slack webhook secret**:
   - Repo settings → Secrets and variables → Actions → New repository secret
   - Name: `SLACK_WEBHOOK_URL`
   - Value: your incoming-webhook URL from <https://api.slack.com/messaging/webhooks>
   - The Slack step is gated by `if: env.SLACK_WEBHOOK_URL != ''`, so without the secret the workflow runs normally and just skips Slack.

4. **Commit + push**. The next Monday 08:00 UTC the cron fires; or trigger immediately with **Actions tab → tokopt-weekly-audit → Run workflow**.

---

## Knobs

Tune the defaults at the top of the workflow file:

| Variable | Default | What it does |
|---|---|---|
| `TOKOPT_VERSION` | _(empty = latest)_ | Pin to a specific tokopt release for reproducibility. Example: `v0.4.0`. See [shinyay/tokopt releases](https://github.com/shinyay/tokopt/releases). |
| `cron` (line ~22) | `0 8 * * 1` | Monday 08:00 UTC. Adjust to your team's timezone — [crontab.guru](https://crontab.guru) helps. |
| `ISSUE_LABEL` | `tokopt-weekly-audit` | Rename if you already use that label for something else. |
| `ISSUE_TITLE` | `tokopt weekly audit` | Title of the auto-created tracking issue. |

---

## Required permissions

The workflow uses **only the default `GITHUB_TOKEN`** — no PAT required.

```yaml
permissions:
  contents: read   # checkout
  issues: write    # create + update tracking issue
```

If your org enforces "read-only `GITHUB_TOKEN` by default" (org-level setting), the workflow's `permissions:` block overrides it for this job only — no org-admin action needed.

---

## What the tracking issue looks like

After 3 weekly runs, your tracking issue body looks like:

```markdown
<!-- tokopt-baseline: 1842 -->
<!-- tokopt-last-run: 2026-06-08T08:00:23Z -->

## tokopt always-on token tax

Updated every Monday 08:00 UTC by `.github/workflows/tokopt-weekly-audit.yml`.

**Current baseline**: 1842 tokens

See the most recent comment for this week's delta and breakdown.
```

…with the weekly delta posted as a **comment** (so the timeline is the history):

```markdown
### Weekly audit — 2026-06-08

**Total**: 1842 tokens (delta from last run: **+47 tokens**, +2.6%)

| Scope | Tokens | Files |
|---|---:|---:|
| always-on | 234 | 2 |
| conditional | 2094 | 2 |
| on-demand | 6302 | 9 |

Top 5 files by tokens (always-on + conditional):
- agents/token-doctor.agent.md — 1261 tokens
- agents/prompt-optimizer.agent.md — 833 tokens
- .github/copilot-instructions.md — 121 tokens
- AGENTS.md — 113 tokens
- (none)

[workflow run](https://github.com/owner/repo/actions/runs/12345)
```

The HTML-comment baseline marker (`<!-- tokopt-baseline: N -->`) is the only piece of state the workflow needs to recover after restart. The whole flow is idempotent: re-running the workflow on the same day computes the same delta and overwrites the same baseline marker.

---

## First-run behavior

The first time the workflow fires, **no labelled issue exists**. The workflow:

1. Creates a new issue with label `tokopt-weekly-audit`, body containing `<!-- tokopt-baseline: 0 -->`.
2. Posts the first comment with `delta from last run: **first run — no baseline**`.
3. Updates the issue body baseline to the current total.

Subsequent runs find the issue, parse the previous baseline, compute delta, post comment, update baseline. No manual bootstrap.

---

## Slack variant

Adding `SLACK_WEBHOOK_URL` as a repo secret enables a **single-message** Slack notification per weekly run, with a one-line summary and a link to the GitHub comment. The Slack step never blocks the workflow (it's `continue-on-error: true`) — if your webhook is misconfigured, the GitHub-issue update still succeeds.

If you prefer **only Slack** (no GitHub issue), comment out the `update-issue` step and keep the `notify-slack` step — but the baseline storage logic depends on the issue body, so you'll also need to add an external storage mechanism (out of scope for this recipe).

---

## Why not just track on every PR?

PR-time gating (`examples/ci/`) catches **threshold breaches** — "you just pushed a 200-token addition that put us over budget". Scheduled audit catches **slow drift** — "we gained 50 tokens/week for the last 8 weeks". Both signals are useful; neither subsumes the other.

| | PR gate (`examples/ci/`) | Weekly audit (this dir) |
|---|---|---|
| **Detects** | Spikes (>threshold in one PR) | Drift (sustained growth over weeks) |
| **Cadence** | Per PR (minutes) | Per week (Monday 08:00 UTC) |
| **Failure mode** | Red CI ❌ | Tracking-issue comment + optional Slack |
| **Visibility** | PR author + reviewer | Whole team via issue subscription / Slack |
| **Best for** | Catching regressions before merge | Spotting "we keep adding 50 tokens/week" trends |

**Recommendation**: ship both. The PR gate keeps the slope from going vertical; the weekly audit makes the integral visible.

---

## Maintenance

- **Tokopt new release**: pin `TOKOPT_VERSION` (or leave empty for latest). Pinning recommended for stable signal — a tokenizer change between tokopt versions can shift the baseline.
- **Tokenizer encoding**: defaults to `o200k_base`. If your provider uses `cl100k_base`, pass `--encoding cl100k_base` to `tokopt audit`. Document the choice somewhere — switching encodings mid-tracking creates a spurious step in the delta history.
- **Reset baseline**: edit the issue body comment `<!-- tokopt-baseline: N -->` to whatever you want the next-run delta to be measured against. (Or close the issue and let the next run create a fresh one with baseline=0.)

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Error: Resource not accessible by integration` on issue create | `GITHUB_TOKEN` lacks `issues: write` | Confirm the `permissions:` block is intact in the copied workflow |
| First run created **two** issues | Label was created mid-run by a parallel manual `gh issue create` | Close one; the workflow's idempotency picks up the surviving one next run |
| Delta shows huge negative number after a tokopt upgrade | Tokenizer changed between versions (e.g., switched to `o200k_base`) | Edit the issue body `tokopt-baseline:` value to the new total to reset the comparison |
| Slack notification missing | `SLACK_WEBHOOK_URL` secret not set, or webhook revoked | Check repo secrets; rotate webhook if needed |
| Issue body shows stale baseline | Workflow failed between comment-post and body-update | Re-run; the workflow updates body unconditionally on success |

---

## See also

- [`examples/ci/`](../ci/) — PR-time threshold gating (GitHub Actions + pre-commit)
- [`examples/batch/`](../batch/) — multi-file `slim` / `detect` / leaderboard scripts
- [tokopt repo](https://github.com/shinyay/tokopt) — CLI source + releases
