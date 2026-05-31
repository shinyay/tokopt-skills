#!/usr/bin/env python3
"""Validate YAML frontmatter in SKILL.md and *.agent.md files.

Regression guard for a class of silent-load failures where unquoted
``: `` (colon + space) inside a plain-scalar ``description`` is interpreted
by strict YAML parsers as a mapping-key indicator, causing the Copilot
CLI loader to drop the file from ``/skills list`` enumeration without
surfacing an error.

See:
  https://github.com/shinyay/tokopt-skills/issues/1
  CHANGELOG.md [0.2.1] (2026-05-31)

Checks per file:
  1. Frontmatter is well-formed (opens with ``---`` on line 1, has a
     matching closer).
  2. ``yaml.safe_load`` parses the frontmatter without error.
  3. The parsed value is a YAML mapping.
  4. ``name`` is a non-empty string and matches the expected basename
     (skill directory name, or agent file stem without ``.agent``).
  5. ``description`` is a non-empty string.

Exit codes:
  0  all files valid
  1  one or more validation errors
  2  no SKILL.md or *.agent.md files found (likely a layout change)
"""
from __future__ import annotations

import sys
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parent.parent
ERRORS: list[str] = []


def fail(path: Path, msg: str) -> None:
    rel = path.relative_to(REPO)
    ERRORS.append(f"{rel}: {msg}")


def extract_frontmatter(text: str, path: Path) -> str | None:
    lines = text.splitlines(keepends=True)
    if not lines or lines[0].rstrip() != "---":
        fail(path, "missing frontmatter opener '---' on line 1")
        return None
    for i, line in enumerate(lines[1:], start=1):
        if line.rstrip() == "---":
            return "".join(lines[1:i])
    fail(path, "missing frontmatter closer '---'")
    return None


def validate(path: Path, expected_name: str) -> None:
    text = path.read_text(encoding="utf-8")
    fm = extract_frontmatter(text, path)
    if fm is None:
        return
    try:
        data = yaml.safe_load(fm)
    except yaml.YAMLError as e:
        mark = getattr(e, "problem_mark", None)
        loc = f" at line {mark.line + 2}, column {mark.column + 1}" if mark else ""
        problem = getattr(e, "problem", str(e))
        fail(path, f"YAML parse error{loc}: {problem}")
        return
    if not isinstance(data, dict):
        fail(path, f"frontmatter is not a YAML mapping (got {type(data).__name__})")
        return
    name = data.get("name")
    desc = data.get("description")
    if not isinstance(name, str) or not name.strip():
        fail(path, "missing or empty 'name' field")
    elif name != expected_name:
        fail(path, f"name '{name}' does not match expected '{expected_name}'")
    if not isinstance(desc, str) or not desc.strip():
        fail(path, "missing or empty 'description' field")


def main() -> int:
    skills = sorted(REPO.glob("skills/*/SKILL.md"))
    agents = sorted(REPO.glob("agents/*.agent.md"))
    if not skills and not agents:
        print(
            f"ERROR: no SKILL.md or *.agent.md files found under {REPO}",
            file=sys.stderr,
        )
        return 2
    print(f"Validating {len(skills)} skill(s) + {len(agents)} agent(s)...")
    for p in skills:
        validate(p, p.parent.name)
    for p in agents:
        validate(p, p.name.removesuffix(".agent.md"))
    if ERRORS:
        print(f"\n{len(ERRORS)} validation error(s):", file=sys.stderr)
        for err in ERRORS:
            print(f"  ✗ {err}", file=sys.stderr)
        return 1
    print(f"✓ All {len(skills) + len(agents)} files valid.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
