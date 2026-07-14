# Changelog

All notable changes to **tokopt-skills** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.2] - 2026-07-14

### Changed

- **Compatibility and measured footprint now match the coordinated Trust
  Restoration release.** The README targets tokopt CLI v0.18.0 and reports
  the plugin's current `tokopt audit` result: 0 always-on, 2,202 conditional,
  and 8,662 on-demand tokens. The plugin still ships 10 skills and 2 agents;
  no runtime skill behavior changed in this patch.

## [0.3.1] - 2026-07-02

### Changed

- **slim skills now guide Japanese compression (skills#24)** — `slim-suggest`,
  `slim-apply`, and `hygiene-coach` previously told the agent to run
  `tokopt slim` with no Japanese flag, so a Japanese file previewed at 0 %.
  `slim-suggest` now instructs: when the JSON reports `language:"ja"` and
  `saved_tokens:0`, re-run with **`--enable-jp-idiom`** (a no-op on
  non-Japanese input; ~15 % on idiom-heavy prose) and report those numbers.
  `slim-apply` and `hygiene-coach` document the matching **flag parity** (the
  apply must reuse `--enable-jp-idiom` from the preview). All three note that
  **customization assets can't be idiom-compressed** (the customization
  pipeline ignores the Japanese stages) and that `--enable-nexus-ja` needs a
  kagome build. The skill keys off the structured `language` field because the
  CLI's stderr hint is suppressed under `--format json`. Parallel to
  [tokopt-vscode#45](https://github.com/shinyay/tokopt-vscode/issues/45).

## [0.3.0] - 2026-06-21

### Added

- **`skills/model-cost-compare/SKILL.md`: new skill** (skills#22, Wave 1
  "Model Cost Intelligence") — wraps `tokopt report --by-model` so Copilot
  CLI can answer "which model is cheapest for this repo?" in natural
  language. Runs the audit once, then ranks **every model in the rate
  card** by the repo's projected AI Credit cost (cheapest first), with the
  `empirical` vs `catalog` basis distinction and the standard honesty
  guardrails (report what the CLI measured; treat catalog rates as a
  list-price upper bound). Requires tokopt CLI ≥ 0.10.0. Brings the
  on-demand skill count to **ten**; `plugin.json` description and the
  static inventory check updated accordingly.

- **`skills/token-audit/SKILL.md`: `--follow-references` flag mention**
  ([gs#63](https://github.com/shinyay/getting-started-with-token-optimization/issues/63))
  — adds a one-paragraph subsection under "How to invoke" that
  documents the new `tokopt audit --follow-references` opt-in flag
  (added in tokopt v0.7.0). Calls out the ~60% under-count gap
  measured on coordinator-style configs (`.github/instructions/*.md`
  files referenced by name from a `*.agent.md` body without
  `applyTo:` frontmatter). Best-effort path detection — explicitly
  labelled as "may not load". Skill body still works against tokopt
  v0.6.x for the existing flow; the new section just becomes
  invocable when the user has v0.7.0+ installed.

- **Docs/examples: `examples/anatomy/auto-classify.sh` recipe**
  ([gs#60](https://github.com/shinyay/getting-started-with-token-optimization/issues/60))
  — POSIX shell script that walks one or more roots, discovers all
  recognised Copilot/agent customization files (`*.agent.md`,
  `SKILL.md`, `copilot-instructions.md`, `AGENTS.md`,
  `*.instructions.md`, `*.chatmode.md`, `*.prompt.md`, MCP configs),
  runs `tokopt anatomy <file> --format=json` in parallel (`xargs -P`,
  NUL-safe), and emits JSONL with `inferred_segment` +
  `inference_rule` + `total_input_tokens` per file. Mirrors the shape
  of `examples/batch/detect-all.sh` (same arg-parsing, env vars, exit
  tiers). Surfaces a sortable per-file segment breakdown useful for
  "which agent files cost the most user tokens" audits. Smoke-tested
  against the getting-started repo: 22/23 files succeeded (1 expected
  UNRECOGNIZED_SHAPE on a test-fixture file matching `*.prompt.md` but
  outside the path-anchor rules).

- **Docs/examples: `examples/anatomy/README.md`** —
  prerequisites, quick-start, output sample, file-shape table, exit-
  code tier table, and a "when to use" comparison vs the interactive
  `prompt-anatomy` skill.

### Changed

- **`skills/prompt-anatomy/SKILL.md`: positional form is now the
  primary example** — the `tokopt v0.6.0` positional auto-classification
  surface (`tokopt anatomy <file>`) leads the "How to invoke" section
  with a worked example and JSON output sample. The legacy 6-flag
  composition form (`--system <f> --always-on <f> ...`) is moved to a
  "For multi-segment composition" subsection where it still belongs
  for power-user workflows that stage a full prompt before/after.
  Closes the loop on [gs#60](https://github.com/shinyay/getting-started-with-token-optimization/issues/60).

- **`agents/prompt-optimizer.agent.md`: anatomy invocation guidance
  updated** — line 17-22 instructions now mention both the positional
  auto-classify form (preferred for recognised file shapes) and the
  explicit `--<segment>` form (fallback for unknown shapes, stdin, or
  when the user names a specific segment). Falls back to `user` only
  on `UNRECOGNIZED_SHAPE` rather than as the unconditional default.

- **Docs/examples: `examples/scheduled/` weekly drift detection recipe**
  ([#9](https://github.com/shinyay/tokopt-skills/issues/9)) —
  drop-in `weekly-audit.yml` workflow runs `tokopt audit . --format=json`
  on a Monday 08:00 UTC cron, finds-or-creates a single tracking issue
  via `actions/github-script@v7` (idempotent via label `tokopt-weekly-audit`),
  computes a delta against a baseline stored in the issue body
  (`<!-- tokopt-baseline: N -->`), posts a weekly comment, and optionally
  notifies Slack via `SLACK_WEBHOOK_URL` secret. Closes the slow-creeping-
  drift gap that PR-time `examples/ci/` cannot see (a SKILL.md growing 5%
  per week is invisible until it crosses an arbitrary threshold). Living
  under `examples/` (not `.github/workflows/`) means GitHub Actions will
  NOT auto-execute the template; users copy it into their own workflows
  directory.

- **Docs/examples: `examples/batch/` multi-file recipes**
  ([#8](https://github.com/shinyay/tokopt-skills/issues/8)) —
  three POSIX shell scripts for org-wide / monorepo workflows that the
  interactive single-file CLI surface doesn't cover:
  (a) **`slim-all.sh`** — `xargs -P` parallel `tokopt slim --input <file>
  --format=json` over every customization file under a root (matching the
  `tokopt-vscode` `COPILOT_CUSTOMIZATION_LANGS` set: `SKILL.md`,
  `*.agent.md`, `*.prompt.md`, `*.chatmode.md`, `copilot-instructions.md`,
  `AGENTS.md`, `CLAUDE.md`), emitting JSONL via `jq -c .`;
  (b) **`detect-all.sh`** — same shape but per-DIRECTORY (because `tokopt
  detect` is directory-walking, not file-accepting), splicing each root
  into the JSON via `jq` so records are self-describing;
  (c) **`worst-offenders.sh`** — `tokopt audit . --format=json` piped
  through `jq` sort/head/awk to produce a top-N leaderboard table.
  All scripts use `find -print0 | xargs -0` for filename-with-spaces
  safety, default `TOKOPT_BATCH_PARALLEL=$(nproc)` with env override, and
  share a 3-tier exit code semantic (0=clean, 1=some failed, 2=majority
  failed). Closes the "I have 50 .agent.md files across an org" gap.

- **CI: `skills-listing-smoke` workflow** ([#3](https://github.com/shinyay/tokopt-skills/issues/3)) —
  every push, PR, and release publish now runs `scripts/validate_inventory.py`,
  which asserts the static inventory is intact: (a) `plugin.json` matches the
  expected schema (`name=tokopt-skills`, semver `version`, `skills=["./skills"]`,
  `agents=["./agents"]`, correct `repository` URL); (b) the expected skill
  directories all exist under `skills/` with a `SKILL.md` each and no unexpected
  extras; (c) the 2 expected `*.agent.md` files exist under `agents/` with no
  unexpected extras; (d) the `prompt-optimizer` dual-surface (skill + agent)
  remains intact.
  Degraded scope: does NOT invoke `copilot /skills list` because that command
  has no documented non-interactive surface as of Copilot CLI 1.0.57. Loader-
  level smoke test deferred upstream. Complements `validate-frontmatter` which
  guards file-level YAML correctness; together they catch the silent-load class
  of bug from two distinct angles.

- **CI: `validate-frontmatter` workflow** — every push and PR now runs
  `scripts/validate_frontmatter.py`, which strict-parses each
  `skills/*/SKILL.md` and `agents/*.agent.md` frontmatter with PyYAML
  and fails on (a) YAML parse errors, (b) missing or empty `name` /
  `description`, or (c) `name` field not matching the file/dir basename.
  Regression guard for the v0.2.1 silent-load class of bug.

## [0.2.1] — 2026-05-31

### Fixed

- **`slim-apply` silently dropped from `/skills list`**
  ([skills/slim-apply/SKILL.md](skills/slim-apply/SKILL.md)) — the
  `description` field was an unquoted YAML plain scalar that contained
  `: ` (colon + space) inside the prose (`...with full safety: requires
  clean git tree...`). Strict YAML 1.2 parsers, including Copilot CLI's
  loader, treat `: ` as a mapping-key indicator and rejected the
  frontmatter with `mapping values are not allowed here`, so the skill
  was silently dropped from `/skills list`. The fix wraps the entire
  description in double-quotes — no content change. Root cause analysis
  validated by `python3 -c "import yaml; yaml.safe_load(...)"` against
  both old and new frontmatter. **This was not a Copilot CLI bug.**
- README "Known limitations" section 2 rewritten to retract the
  earlier "unknown root cause" claim and document the YAML fix.

### Docs

- **Known limitations refresh** ([README.md](README.md#%EF%B8%8F-known-limitations))
  re-verified all upstream Copilot CLI issues against
  `GitHub Copilot CLI 1.0.57-2`:
  - **#1 plugin loader directory resolution** — marked **✅ fixed in
    1.0.57+**; symlink workaround moved into a collapsed `<details>` block
    for legacy 1.0.55 / 1.0.56 users only.
  - **#2 `slim-apply` silently dropped** — root cause identified
    (YAML frontmatter) and fixed in 0.2.1 (see above).
  - **#3 namespace collision in `/skills list`** — new section documenting
    the risk that bare skill names (e.g., `prompt-optimizer`) collide if
    multiple plugins ship the same name, and recommending agent
    invocation (`@token-doctor`, `@prompt-optimizer`) when disambiguation
    matters. Filed upstream as a follow-on to
    [#3546](https://github.com/github/copilot-cli/issues/3546#issuecomment-4585423585).

## [0.2.0] — 2026-05-30

**Coordinated release** marking the completion of the 3-repo specialization.
Ships alongside `getting-started-with-token-optimization` **v0.4.0**,
[`tokopt-vscode`](https://github.com/shinyay/tokopt-vscode) **v0.6.0**, and
[`tokopt`](https://github.com/shinyay/tokopt) **v0.4.0** (pre-built binaries).

This release adds **two surface-specific features** that turn `tokopt-skills`
from "the Copilot CLI plugin that wraps `tokopt`" into the canonical
CLI-side specialization (analogous to `tokopt-vscode`'s 5 VS Code surfaces).

### Added

- **Shell completions install instructions** — README now documents the
  per-shell install paths for `tokopt completion <shell>` for bash, zsh,
  fish, and PowerShell, plus the "current shell only" `source <(tokopt
  completion …)` shortcut. The completion script itself is generated by
  the `tokopt` CLI (`getting-started-with-token-optimization` v0.4.0+)
  so the satellite ships zero pre-generated files and never goes stale
  on CLI releases.
  Closes [#6](https://github.com/shinyay/tokopt-skills/issues/6) via
  PR [#10](https://github.com/shinyay/tokopt-skills/pull/10).

- **`examples/ci/` — drop-in CI recipe** for downstream repos that want
  to enforce a token-tax budget in CI and/or git hooks. Ships four
  copy-paste-ready files:
  - `examples/ci/github-actions/token-budget.yml` — drop-in GitHub
    Actions workflow (PR + push + `workflow_dispatch` + reusable
    `workflow_call`), `ubuntu-latest`, three tunable inputs
    (`threshold` / `budget-mode` / `tokopt-version`), `warn` mode emits
    a clean `::warning::` annotation, installs `tokopt` via the
    canonical `curl install.sh | sh` (which already verifies
    SHA256SUMS).
  - `examples/ci/pre-commit/token-budget.sh` — bash wrapper with
    friendly missing-binary error.
  - `examples/ci/pre-commit/.pre-commit-config.yaml` — both inline
    (minimal) and wrapper (recommended) recipes.
  - `examples/ci/README.md` — when-to-use table (CI = late warning,
    pre-commit = early gate; recommends running both), knobs
    documentation, supply-chain hardening guide, troubleshooting.
  - Root README gets a new `## 🚦 Use it in your CI` section linking
    to the recipe.

  Explicitly states **CI does not need the `tokopt-skills` Copilot CLI
  plugin** — CI uses the `tokopt` binary directly. The plugin is only
  for interactive Copilot CLI workflows on developer machines.
  Closes [#7](https://github.com/shinyay/tokopt-skills/issues/7) via
  PR [#11](https://github.com/shinyay/tokopt-skills/pull/11).

### Changed

- `plugin.json` — `version` `0.1.0` → `0.2.0`.

### Architecture: CLI-side analogue of `tokopt-vscode`

With v0.2.0, the 3-repo specialization is complete:

| Repo | Role | Surfaces |
|---|---|---|
| `getting-started-with-token-optimization` | 教材 + CLI source | docs / RFC / Go binary / completion subcommand |
| **`tokopt-skills` (this repo)** | **Copilot CLI plugin canonical** | **9 skills / 2 agents / shell-completion install / CI recipe** |
| `tokopt-vscode` | VS Code canonical | CodeLens / Diagnostics / Quick Fix / Status bar / TreeView (5 surfaces) |

## [0.1.0] — 2026-05-28

Initial public release. Extracts the Copilot CLI plugin from the source
repo `getting-started-with-token-optimization` so users can install the
`@token-doctor` agent + 9 token-optimization skills via the standard
Copilot CLI plugin install path without cloning the (much larger)
教材 repo.

### Added

- **Two agents**:
  - `@token-doctor` — orchestrator that diagnoses + remediates token
    consumption in any Copilot/agent repository. Delegates to the 9
    skills below.
  - `@prompt-optimizer` — propose-only critic that suggests prompt
    rewrites without modifying files.

- **Nine on-demand skills**:
  - `token-audit` — measure always-on token tax for a repository.
  - `prompt-anatomy` — break down a prompt's anatomy.
  - `antipattern-scan` — find common token anti-patterns.
  - `heavy-tail` — locate the heavy-tail outliers in a file or directory.
  - `slim-suggest` — propose slim-pipeline edits without applying them.
  - `slim-apply` — apply slim-pipeline edits.
  - `slim-rewind` — undo the last slim-apply.
  - `hygiene-coach` — interactive coach for token hygiene.
  - `prompt-optimizer` — the standalone skill behind the agent.

- **Standard Copilot CLI plugin layout** (`plugin.json` + `skills/` +
  `agents/`) so installation works via the documented plugin path.

- **MIT LICENSE** + README with installation, layout, and link back to
  the source repo for the underlying `tokopt` CLI.

### Notes

- Requires the `tokopt` binary on PATH (install via
  [shinyay/tokopt](https://github.com/shinyay/tokopt)).
- Known limitation: Copilot CLI ≥1.0.55 plugin loader resolves install
  dirs by `plugin.json`'s `name` field (not by `<org>--<repo>/`).
  Workaround documented in README. Upstream tracking
  [github/copilot-cli#3546](https://github.com/github/copilot-cli/issues/3546).

## Format

This file follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions follow [Semantic Versioning](https://semver.org).

[Unreleased]: https://github.com/shinyay/tokopt-skills/compare/v0.3.2...HEAD
[0.3.2]: https://github.com/shinyay/tokopt-skills/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/shinyay/tokopt-skills/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/shinyay/tokopt-skills/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/shinyay/tokopt-skills/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/shinyay/tokopt-skills/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/shinyay/tokopt-skills/releases/tag/v0.1.0
