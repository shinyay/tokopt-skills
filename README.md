# tokopt-skills

> **Copilot CLI plugin** — 9 token-optimization skills + 2 agents for the [`tokopt`](https://github.com/shinyay/tokopt) CLI.

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

---

## ⚠️ Known limitations (Copilot CLI ≥ 1.0.55)

These are **upstream Copilot CLI issues**, not bugs in this plugin. Tracked publicly:

### 1. Plugin loader expects unprefixed directory name ([repro](https://github.com/github/copilot-cli/issues/3546))

`copilot plugin install shinyay/tokopt-skills` creates
`~/.copilot/installed-plugins/_direct/shinyay--tokopt-skills/` (GitHub
shorthand convention), but the loader resolves plugin dirs by the
`plugin.json` `name` field (`tokopt-skills`). Result: install succeeds,
nothing loads.

**Workaround** — add a symlink with the bare plugin name:

```bash
cd ~/.copilot/installed-plugins/_direct
ln -sf shinyay--tokopt-skills tokopt-skills
# Restart Copilot CLI; /skills should now list 8 tokopt-* entries
```

### 2. `slim-apply` silently dropped from `/skills list` ([#3546](https://github.com/github/copilot-cli/issues/3546))

After applying workaround 1, **8 of the 9 skills appear**; `slim-apply` is
silently dropped despite the install summary reporting all 9 loaded.
Root cause unknown (closed-source binary). Disproved hypotheses: frontmatter
format, BOM, description length, `DO NOT`/`Destructive` keyword filters.

**Impact** — `slim-apply` is unreachable via natural-language match.
`@token-doctor` will still call `tokopt slim --apply` directly when needed,
so the destructive-write workflow remains usable; only the standalone
auto-trigger of the skill is affected.

Track upstream resolution at <https://github.com/github/copilot-cli/issues/3546>.

---

## 🙋 Where this comes from

These skills + agents started life inside [`shinyay/getting-started-with-token-optimization`](https://github.com/shinyay/getting-started-with-token-optimization) — a tutorial / reference / hands-on workshop repository covering the full theory and practice of token optimisation across 14 chapters.

`tokopt-skills` is the **CLI distribution package** extracted from that work — small, focused, and `copilot plugin install`-able. The tutorial repository remains the place to learn _why_ and _how_ each skill works; this repository is the place to just _use_ them.

> **VS Code Copilot Chat user?** See the companion package [`shinyay/tokopt-vscode`](https://github.com/shinyay/tokopt-vscode) — same 9 skills + 2 agents in `.github/agents/` + `.github/skills/` layout, plus 4 `.prompt.md` slash-command wrappers (`/token-audit`, `/prompt-anatomy`, `/slim-suggest`, `/slim-apply`). One install script handles workspace OR user-profile scope.

---

## 📜 License

MIT — see [LICENSE](LICENSE).
