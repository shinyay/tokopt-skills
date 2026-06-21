#!/usr/bin/env python3
"""Validate the static inventory of skills, agents, and plugin.json.

Degraded-scope smoke test for the install/loader pathway. Acts as a guard
against accidental file deletions, renames, or unintended additions slipping
into ``main`` between releases. Does NOT exercise the loader itself — that
would require a non-interactive ``copilot /skills list`` surface which does
not exist as of Copilot CLI 1.0.57.

Complements ``scripts/validate_frontmatter.py``:
  * ``validate_frontmatter.py`` — does each file PARSE and have valid fields?
  * ``validate_inventory.py``   — is the set of files what we expect?

Checks performed:
  1. plugin.json schema:
     - ``name == "tokopt-skills"`` (matches plugin-loader expectations)
     - ``version`` is a string matching ``\\d+\\.\\d+\\.\\d+`` shape
     - ``skills`` is a list containing exactly ``./skills``
     - ``agents`` is a list containing exactly ``./agents``
     - ``repository == "https://github.com/shinyay/tokopt-skills"``
  2. Skill inventory (set equality vs. EXPECTED_SKILLS):
     - Every expected skill has ``skills/<name>/SKILL.md``
     - No unexpected directories under ``skills/``
  3. Agent inventory (set equality vs. EXPECTED_AGENTS):
     - Every expected agent has ``agents/<name>.agent.md``
     - No unexpected ``*.agent.md`` files under ``agents/``
  4. Cross-validation:
     - ``prompt-optimizer`` is intentionally a dual-surface (skill + agent);
       assert both exist.

Exit codes:
  0  inventory + schema both clean
  1  inventory mismatch (missing or unexpected skill/agent)
  2  plugin.json malformed or missing required fields
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

# Single source of truth — update intentionally when adding/removing assets.
EXPECTED_SKILLS = {
    "antipattern-scan",
    "heavy-tail",
    "hygiene-coach",
    "model-cost-compare",
    "prompt-anatomy",
    "prompt-optimizer",
    "slim-apply",
    "slim-rewind",
    "slim-suggest",
    "token-audit",
}
EXPECTED_AGENTS = {
    "prompt-optimizer",
    "token-doctor",
}
DUAL_SURFACE = {"prompt-optimizer"}

SEMVER = re.compile(r"^\d+\.\d+\.\d+(?:[-+].+)?$")
EXPECTED_NAME = "tokopt-skills"
EXPECTED_REPO = "https://github.com/shinyay/tokopt-skills"


def validate_plugin_json() -> list[str]:
    path = REPO / "plugin.json"
    if not path.exists():
        return [f"plugin.json: missing at {path}"]
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        return [f"plugin.json: JSON parse error: {e}"]
    errors: list[str] = []
    if not isinstance(data, dict):
        return [f"plugin.json: root is {type(data).__name__}, expected object"]
    name = data.get("name")
    if name != EXPECTED_NAME:
        errors.append(f"plugin.json: name={name!r}, expected {EXPECTED_NAME!r}")
    version = data.get("version")
    if not isinstance(version, str) or not SEMVER.match(version):
        errors.append(f"plugin.json: version={version!r}, expected semver string")
    skills = data.get("skills")
    if skills != ["./skills"]:
        errors.append(f"plugin.json: skills={skills!r}, expected ['./skills']")
    agents = data.get("agents")
    if agents != ["./agents"]:
        errors.append(f"plugin.json: agents={agents!r}, expected ['./agents']")
    repo = data.get("repository")
    if repo != EXPECTED_REPO:
        errors.append(f"plugin.json: repository={repo!r}, expected {EXPECTED_REPO!r}")
    return errors


def validate_skill_inventory() -> list[str]:
    errors: list[str] = []
    skills_dir = REPO / "skills"
    if not skills_dir.is_dir():
        return [f"skills/: missing at {skills_dir}"]
    actual_dirs = {p.name for p in skills_dir.iterdir() if p.is_dir()}
    missing = EXPECTED_SKILLS - actual_dirs
    unexpected = actual_dirs - EXPECTED_SKILLS
    for name in sorted(missing):
        errors.append(f"skills/: expected skill {name!r} not found")
    for name in sorted(unexpected):
        errors.append(
            f"skills/: unexpected skill {name!r} — add to EXPECTED_SKILLS or remove the directory"
        )
    # SKILL.md presence for every expected skill that DOES exist
    for name in sorted(EXPECTED_SKILLS & actual_dirs):
        skill_md = skills_dir / name / "SKILL.md"
        if not skill_md.exists():
            errors.append(f"skills/{name}/: missing SKILL.md")
    return errors


def validate_agent_inventory() -> list[str]:
    errors: list[str] = []
    agents_dir = REPO / "agents"
    if not agents_dir.is_dir():
        return [f"agents/: missing at {agents_dir}"]
    actual_files = {
        p.name.removesuffix(".agent.md")
        for p in agents_dir.iterdir()
        if p.is_file() and p.name.endswith(".agent.md")
    }
    missing = EXPECTED_AGENTS - actual_files
    unexpected = actual_files - EXPECTED_AGENTS
    for name in sorted(missing):
        errors.append(f"agents/: expected agent {name!r}.agent.md not found")
    for name in sorted(unexpected):
        errors.append(
            f"agents/: unexpected agent {name!r}.agent.md — add to EXPECTED_AGENTS or remove the file"
        )
    return errors


def validate_dual_surface() -> list[str]:
    errors: list[str] = []
    for name in sorted(DUAL_SURFACE):
        if name not in EXPECTED_SKILLS:
            errors.append(f"dual-surface: {name!r} missing from EXPECTED_SKILLS")
        if name not in EXPECTED_AGENTS:
            errors.append(f"dual-surface: {name!r} missing from EXPECTED_AGENTS")
    return errors


def main() -> int:
    print(f"Validating inventory under {REPO}")
    print(f"  Expected: {len(EXPECTED_SKILLS)} skill(s) + {len(EXPECTED_AGENTS)} agent(s)")

    schema_errs = validate_plugin_json()
    inventory_errs = (
        validate_skill_inventory()
        + validate_agent_inventory()
        + validate_dual_surface()
    )

    if schema_errs:
        print(f"\n{len(schema_errs)} plugin.json error(s):", file=sys.stderr)
        for e in schema_errs:
            print(f"  ✗ {e}", file=sys.stderr)
    if inventory_errs:
        print(f"\n{len(inventory_errs)} inventory error(s):", file=sys.stderr)
        for e in inventory_errs:
            print(f"  ✗ {e}", file=sys.stderr)

    if schema_errs:
        return 2
    if inventory_errs:
        return 1
    print(
        f"✓ Inventory clean: {len(EXPECTED_SKILLS)} skills + {len(EXPECTED_AGENTS)} agents + plugin.json schema OK"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
