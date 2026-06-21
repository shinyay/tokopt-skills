# tokopt-skills

> **Copilot CLI plugin** — 10 token-optimization skills + 2 agents for the [`tokopt`](https://github.com/shinyay/tokopt) CLI.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Plugin format](https://img.shields.io/badge/format-Copilot%20CLI%20plugin-blue)](https://docs.github.com/copilot/how-tos/copilot-cli)

Install once. Then ask Copilot CLI in natural language to **measure**, **diagnose**, and **fix** the token cost of any Copilot/agent repository — without ever typing a `tokopt` shell command yourself.

---

## 📦 Install (2 steps)

### Step 1 — Install the `tokopt` binary

```bash
curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh | sh
```

Verify: `tokopt --version`

### Step 2 — Install this plugin

```bash
copilot plugin install shinyay/tokopt-skills
```

Verify: `copilot plugin list | grep tokopt-skills`

### Step 3 — (optional) Enable shell completions

Tab-completion for `tokopt` subcommands and flag values (`--format`, `--encoding`). Pick your shell — each command is idempotent and installs **per-user** (no `sudo`):

```bash
# bash (Linux)
mkdir -p ~/.local/share/bash-completion/completions \
  && tokopt completion bash > ~/.local/share/bash-completion/completions/tokopt

# zsh — ensure ~/.zshrc has `autoload -U compinit && compinit`, then:
mkdir -p ~/.zsh/completions \
  && tokopt completion zsh > ~/.zsh/completions/_tokopt \
  && fpath+=(~/.zsh/completions)   # add this line to ~/.zshrc

# fish
mkdir -p ~/.config/fish/completions \
  && tokopt completion fish > ~/.config/fish/completions/tokopt.fish

# PowerShell — add to $PROFILE:
tokopt completion powershell | Out-String | Invoke-Expression
```

Just want it for the current shell session? `source <(tokopt completion bash)` (or `zsh`/`fish` equivalent).

Full per-shell guide (incl. macOS bash-completion v2 caveat and `--no-descriptions` for terser zsh/fish output): [tokopt CLI README → Shell completions](https://github.com/shinyay/getting-started-with-token-optimization/tree/main/tools/tokopt#shell-completions).

---

## ✨ What you get

### 🤖 2 Agents (paid only when invoked)

| Agent | Role | Tools |
|---|---|---|
| `@token-doctor` | Full optimisation orchestrator: measure → diagnose → propose → apply → re-measure | `bash`, `edit`, `view` |
| `@prompt-optimizer` | Propose-only critic for a single prompt — never edits files | `bash`, `view` |

### 🧩 9 Skills (loaded on demand by description match)

| Skill | When it loads | Calls |
|---|---|---|
| `token-audit` | "audit my repo", "always-on tax" | `tokopt audit` |
| `prompt-anatomy` | "decompose this prompt", "7 segments" | `tokopt anatomy` |
| `antipattern-scan` | "find token antipatterns" | `tokopt detect` |
| `heavy-tail` | "find longest prompts", "p95 cost" | `tokopt tail` |
| `model-cost-compare` | "which model is cheapest for this repo?", "compare model cost" | `tokopt report --by-model` |
| `slim-suggest` | "show what could be slimmed" | `tokopt slim` (read-only) |
| `slim-apply` | "apply the slim", "compact this transcript" | `tokopt slim --write` / `chat-compact` |
| `slim-rewind` | "undo the last slim", "restore" | `tokopt rewind` |
| `hygiene-coach` | "make it healthier", "cleanup" | recommends + delegates to others |
| `prompt-optimizer` | "review this prompt", "improve writing quality" | propose-only critic |

Every skill **grounds recommendations in real `tokopt` output** — never invented numbers.

---

## 💬 Usage examples

**Casual measurement** — a skill auto-loads:

```text
Copilot, このリポジトリの token を audit して
```

→ Skill `token-audit` matches → runs `tokopt audit .` → Copilot explains the output.

**End-to-end optimisation** — invoke the agent explicitly:

```text
@token-doctor reduce my always-on tax to under 200 tokens
```

→ Agent measures → diagnoses → proposes 3 changes → applies (with your approval) → re-measures.

**Single-prompt critique** — no file edits:

```text
@prompt-optimizer review prompts/my-system-prompt.md
```

→ Agent reads the prompt, scores it against the 7 segments, outputs a BEFORE/AFTER markdown report you can copy.

---

## 🚦 Use it in your CI

Want to enforce a token-tax budget on every PR or git commit in your own repo? Drop-in recipes for **GitHub Actions** and **pre-commit** live in [`examples/ci/`](examples/ci/):

```bash
# 1. Add a token-budget gate to your repo's CI
mkdir -p /path/to/your-repo/.github/workflows
cp examples/ci/github-actions/token-budget.yml \
   /path/to/your-repo/.github/workflows/

# 2. Or add a pre-commit hook for instant local feedback
#    (see examples/ci/README.md for full pre-commit setup)
```

CI uses the `tokopt` binary directly — **the Copilot CLI plugin is not required in CI**. See [`examples/ci/README.md`](examples/ci/README.md) for tunable knobs (`threshold`, `budget-mode`, `tokopt-version`), pre-commit recipes, and maintenance tips.

---

## 📅 Catch slow-creeping drift (scheduled)

PR-time CI catches a single bad commit; it doesn't catch a SKILL.md that grows 5% per week as a team adds examples. The [`examples/scheduled/`](examples/scheduled/) recipe ships a **weekly audit workflow**: a Monday cron runs `tokopt audit`, finds-or-creates a single tracking issue (idempotent via label), posts a delta against last week's baseline (stored in the issue body), and optionally pings Slack:

```bash
mkdir -p /path/to/your-repo/.github/workflows
cp examples/scheduled/github-actions/weekly-audit.yml \
   /path/to/your-repo/.github/workflows/
```

See [`examples/scheduled/README.md`](examples/scheduled/README.md) for cron tuning, label setup, Slack opt-in, and the `<!-- tokopt-baseline: N -->` issue-body convention.

---

## 🧵 Run `slim` / `detect` / leaderboard across many files

Single-file `tokopt slim` is interactive and per-file by design. For monorepos, organizations, or one-off org-wide audits — where you want to **preview slim** across hundreds of customization files, **scan multiple repos** for anti-patterns, or rank the **top-N worst offenders** — see [`examples/batch/`](examples/batch/):

| Script | What it does |
|---|---|
| [`slim-all.sh`](examples/batch/slim-all.sh) | `xargs -P` parallel `tokopt slim --input <file>` over every customization file under a root → JSONL preview |
| [`detect-all.sh`](examples/batch/detect-all.sh) | Run `tokopt detect` across one or more root directories in parallel → JSONL (one record per root) |
| [`worst-offenders.sh`](examples/batch/worst-offenders.sh) | Sorted top-N leaderboard of files by token count → plain-text table |

All scripts are filename-with-spaces safe (`find -print0 | xargs -0`), respect `TOKOPT_BATCH_PARALLEL`, and use a 3-tier exit code (0 / 1 / 2). See [`examples/batch/README.md`](examples/batch/README.md) for prerequisites, post-processing recipes, and customization tips.

---

## 💸 Token cost of the plugin itself

This plugin's own footprint, measured with `tokopt audit`:

```text
on-demand   6,301 tokens   (9 SKILL.md files — zero cost until matched)
conditional 2,094 tokens   (2 agent files — paid per step only when invoked)
always-on   0 tokens       (no copilot-instructions.md installed by this plugin)
```

**On-demand and conditional only** — installing this plugin does **not** add to your always-on context tax.

---

## 🔧 Requirements

- **Copilot CLI** ≥ 1.0.55
- **`tokopt` binary** (installed via the install.sh in Step 1) — required at runtime by every skill and agent
- Linux / macOS / Windows (WSL)

For which `tokopt` CLI version each skill needs, see the canonical
[COMPATIBILITY.md](https://github.com/shinyay/tokopt/blob/main/COMPATIBILITY.md)
and [VERSIONING.md](https://github.com/shinyay/tokopt/blob/main/VERSIONING.md)
in the CLI repo.

---

## ⚠️ Known limitations

These are **upstream Copilot CLI issues**, not bugs in this plugin. Tracked publicly at <https://github.com/github/copilot-cli/issues/3546>.

### 1. Plugin loader directory resolution — ✅ fixed in Copilot CLI 1.0.57+

**Status: resolved upstream** (re-verified 2026-05-31 on `GitHub Copilot CLI 1.0.57-2`).

`copilot plugin install shinyay/tokopt-skills` creates
`~/.copilot/installed-plugins/_direct/shinyay--tokopt-skills/` (GitHub
shorthand convention). On CLI **1.0.55 / 1.0.56**, the loader resolved
plugin dirs by the `plugin.json` `name` field (`tokopt-skills`) instead
of the actual directory name, so install succeeded but nothing loaded.

On CLI **1.0.57+** the loader uses the saved `cache_path` from
`~/.copilot/config.json` and finds skills correctly with no symlink.

<details>
<summary>Legacy workaround (only for CLI 1.0.55 / 1.0.56)</summary>

```bash
cd ~/.copilot/installed-plugins/_direct
ln -sf shinyay--tokopt-skills tokopt-skills
# Restart Copilot CLI
```

If you are on 1.0.57+ you can **safely remove** any leftover symlink:

```bash
rm ~/.copilot/installed-plugins/_direct/tokopt-skills
```

</details>

### 2. `slim-apply` silently dropped from `/skills list` — ✅ fixed in 0.2.1

**Status: resolved in this plugin** (v0.2.1, 2026-05-31).

Earlier releases (≤ 0.2.0) shipped `skills/slim-apply/SKILL.md` with an
**unquoted YAML plain scalar** in the `description` field that contained a
`: ` (colon + space) inside the prose:

```yaml
description: ...with full safety: requires clean git tree, refuses symlinks...
                              ^^ unquoted ': ' = YAML mapping-key indicator
```

Strict YAML 1.2 parsers (Copilot CLI's loader included) reject the file
with `mapping values are not allowed here`, so the skill was silently
dropped from `/skills list`. The other 8 skill descriptions did not
contain `: ` so they loaded fine — which is why the symptom was specific
to `slim-apply`.

The fix (one line) double-quotes the entire description string.
`copilot plugin upgrade shinyay/tokopt-skills` brings v0.2.1 in; verify
with `/skills list` showing all 9 entries under the appropriate group
(`project:`, `personal-copilot:`, or `plugin:`).

This was **not** a Copilot CLI bug; the loader's behaviour was correct.

To prevent regressions, every push and pull request now runs
`scripts/validate_frontmatter.py` via the `validate-frontmatter` GitHub
Actions workflow. It strict-parses each `SKILL.md` / `*.agent.md`
frontmatter with PyYAML and fails the build on any parse error, missing
`name`/`description`, or name/path mismatch. Run it locally before
opening a PR:

```bash
python scripts/validate_frontmatter.py
```

### 3. Namespace collision risk in `/skills list`

The CLI installs plugins under `_direct/<owner>--<repo>/` (namespace-safe at
the filesystem level), but `/skills list` displays skills by **bare name**
(`prompt-optimizer`) without a `<plugin>:` prefix. Agents already render as
`<plugin-name>:<agent-name>` (`tokopt-skills:prompt-optimizer`); skills do
not.

**Impact** — if you install another plugin that also exposes a skill named
`prompt-optimizer` (or any of the other 9 names in this plugin), `/skills list`
will show two identical-looking rows with no disambiguation. The autonomous
matcher may then pick either at random.

**Mitigation** — until upstream qualifies skill names in the listing, prefer
the explicit agent invocation (`@token-doctor`, `@prompt-optimizer`) when you
need a guarantee about which implementation runs. The 10 skill names are
intentionally specific (`tokopt-` style prefixes were considered and rejected
to keep natural-language matching strong), so practical collisions are rare
today but possible as the plugin ecosystem grows.

---

## 🙋 Where this comes from

These skills + agents started life inside [`shinyay/getting-started-with-token-optimization`](https://github.com/shinyay/getting-started-with-token-optimization) — a tutorial / reference / hands-on workshop repository covering the full theory and practice of token optimisation across 14 chapters.

`tokopt-skills` is the **CLI distribution package** extracted from that work — small, focused, and `copilot plugin install`-able. The tutorial repository remains the place to learn _why_ and _how_ each skill works; this repository is the place to just _use_ them.

> **VS Code Copilot Chat user?** See the companion package [`shinyay/tokopt-vscode`](https://github.com/shinyay/tokopt-vscode) — the core skills + 2 agents in `.github/agents/` + `.github/skills/` layout, plus 4 `.prompt.md` slash-command wrappers (`/token-audit`, `/prompt-anatomy`, `/slim-suggest`, `/slim-apply`). One install script handles workspace OR user-profile scope. (The `model-cost-compare` skill is currently CLI-plugin only; the VS Code package mirrors cost comparison through its dashboard view.)

---

## 📜 License

MIT — see [LICENSE](LICENSE).
