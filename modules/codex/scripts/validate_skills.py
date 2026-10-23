#!/usr/bin/env python3
"""Validate repo-managed Codex skills before they are linked into ~/.codex/skills."""

from __future__ import annotations

import re
import sys
from pathlib import Path


FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n", re.DOTALL)
FIELD_RE = {
    "name": re.compile(r"^name:\s*(.+?)\s*$", re.MULTILINE),
    "description": re.compile(r"^description:\s*(.+?)\s*$", re.MULTILINE),
}
MARKDOWN_LINK_RE = re.compile(r"(?<!!)\[[^\]]+\]\(([^)]+)\)")
VALID_SKILL_NAME_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,63}$")
IGNORED_LINK_PREFIXES = ("http://", "https://", "mailto:", "app://", "plugin://", "#")


def _strip_quotes(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
        return value[1:-1]
    return value


def _extract_frontmatter(skill_md: Path) -> str:
    text = skill_md.read_text(encoding="utf-8")
    match = FRONTMATTER_RE.match(text)
    if match is None:
        raise ValueError("missing YAML frontmatter")
    return match.group(1)


def _validate_frontmatter(skill_dir: Path, errors: list[str]) -> None:
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.is_file():
        errors.append(f"{skill_dir}: missing SKILL.md")
        return

    try:
        frontmatter = _extract_frontmatter(skill_md)
    except ValueError as exc:
        errors.append(f"{skill_md}: {exc}")
        return

    name_match = FIELD_RE["name"].search(frontmatter)
    if name_match is None:
        errors.append(f"{skill_md}: frontmatter missing name")
    else:
        name = _strip_quotes(name_match.group(1))
        if not VALID_SKILL_NAME_RE.fullmatch(name):
            errors.append(f"{skill_md}: invalid skill name '{name}'")
        if name != skill_dir.name:
            errors.append(
                f"{skill_md}: frontmatter name '{name}' must match directory name '{skill_dir.name}'"
            )

    description_match = FIELD_RE["description"].search(frontmatter)
    if description_match is None or not _strip_quotes(description_match.group(1)):
        errors.append(f"{skill_md}: frontmatter missing description")


def _validate_markdown_links(markdown_file: Path, errors: list[str]) -> None:
    text = markdown_file.read_text(encoding="utf-8")
    for raw_target in MARKDOWN_LINK_RE.findall(text):
        target = raw_target.strip().split()[0]
        if not target or target.startswith(IGNORED_LINK_PREFIXES):
            continue
        target = target.split("#", 1)[0]
        if not target:
            continue
        resolved = (markdown_file.parent / target).resolve(strict=False)
        if not resolved.exists():
            errors.append(f"{markdown_file}: broken relative link '{raw_target}'")


def validate_skills(root: Path) -> list[str]:
    errors: list[str] = []
    if not root.is_dir():
        return [f"{root}: skills directory not found"]

    skill_dirs = sorted(path for path in root.iterdir() if path.is_dir() and not path.name.startswith("."))
    for skill_dir in skill_dirs:
        _validate_frontmatter(skill_dir, errors)
        for markdown_file in sorted(skill_dir.rglob("*.md")):
            _validate_markdown_links(markdown_file, errors)
    return errors


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: validate_skills.py <skills-dir>", file=sys.stderr)
        return 2

    root = Path(argv[1]).expanduser()
    errors = validate_skills(root)
    if errors:
        print("Codex skill validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(f"Validated {root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
