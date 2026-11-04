#!/usr/bin/env python3
"""Builds a GitHub Release body from the project changelog.

Usage:
    python3 tool/build_release_notes.py <tag> <changelog.md> <output.md>

The release body is the **actual changelog**, never GitHub's auto-generated
"Full Changelog: .../compare/..." link. Resolution order:

1. The section in <changelog.md> whose heading matches the tag's version,
   e.g. tag `v1.0.10+10` -> `## [1.0.10] - 2026-11-04`.
2. The `## [Unreleased]` section (a release cut before the heading was
   renamed still ships real notes).
3. The full commit messages between the previous release tag and HEAD
   (requires full git history — the release workflow checks out with
   `fetch-depth: 0`).

Exits non-zero when no usable notes can be produced, so a release can never be
published with an empty body.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

SECTION_RE = re.compile(
    r"^##\s+\[(?P<label>[^\]]+)\](?:\s*-\s*(?P<date>.+))?\s*$"
)


def tag_version(tag: str) -> str:
    """`v1.0.10+10` -> `1.0.10`."""
    spec = tag[1:] if tag.startswith("v") else tag
    return spec.split("+", 1)[0]


def parse_sections(text: str) -> dict[str, str]:
    """Maps changelog section labels to their markdown body.

    Labels are lower-cased (`unreleased`, `1.0.10`). Leading/trailing blank
    lines are trimmed from each body; heading lines themselves are excluded
    because the release title already carries the version.
    """
    sections: dict[str, list[str]] = {}
    current: list[str] | None = None

    for line in text.splitlines():
        if line.startswith("## "):
            match = SECTION_RE.match(line)
            if match:
                current = sections.setdefault(
                    match.group("label").strip().lower(), []
                )
            else:
                current = None
            continue
        if current is not None:
            current.append(line)

    return {
        label: "\n".join(lines).strip()
        for label, lines in sections.items()
        if "\n".join(lines).strip()
    }


def pick_notes(sections: dict[str, str], version: str) -> str | None:
    """Version section first, then `[Unreleased]`."""
    for label in (version.lower(), "unreleased"):
        body = sections.get(label)
        if body:
            return body
    return None


def _git(*args: str) -> str:
    return subprocess.check_output(
        ["git", *args], text=True, stderr=subprocess.DEVNULL
    ).strip()


def previous_tag(current_tag: str) -> str | None:
    """Most recent tag before HEAD, ignoring the tag being released."""
    for rev in (f"{current_tag}^", "HEAD^", "HEAD"):
        try:
            tag = _git("describe", "--tags", "--abbrev=0", "--match", "v*", rev)
        except (subprocess.CalledProcessError, FileNotFoundError):
            continue
        if tag and tag != current_tag:
            return tag
    return None


def git_notes(current_tag: str) -> str:
    """Full commit messages since the previous release, as a changelog."""
    previous = previous_tag(current_tag)
    rev_range = f"{previous}..HEAD" if previous else "HEAD"
    try:
        raw = _git(
            "log",
            "--no-merges",
            "--pretty=format:%h%x1f%s%x1f%b%x1e",
            rev_range,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ""

    entries: list[str] = []
    for record in raw.split("\x1e"):
        record = record.strip("\n")
        if not record:
            continue
        sha, subject, body = (record.split("\x1f", 2) + ["", ""])[:3]
        if not subject.strip():
            continue
        entry = f"- **{subject.strip()}** (`{sha.strip()}`)"
        paragraphs = [
            block.strip() for block in body.split("\n\n") if block.strip()
        ]
        for paragraph in paragraphs:
            indented = "\n".join(
                f"  {line}".rstrip() for line in paragraph.splitlines()
            )
            entry += f"\n\n{indented}"
        entries.append(entry)

    if not entries:
        return ""
    header = f"### Changes since {previous}" if previous else "### Changes"
    return f"{header}\n\n" + "\n\n".join(entries)


def build_notes(tag: str, changelog: Path) -> str:
    version = tag_version(tag)
    entries = ""
    if changelog.exists():
        entries = pick_notes(
            parse_sections(changelog.read_text(encoding="utf-8")), version
        ) or ""
    if not entries:
        entries = git_notes(tag)
    return entries.strip()


def main() -> None:
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    tag, changelog, output = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3])

    notes = build_notes(tag, changelog)
    if not notes:
        sys.exit(
            f"ERROR: no changelog entries for {tag}. Add the release notes to "
            f"{changelog} under '## [Unreleased]' (or '[{tag_version(tag)}]') "
            "before tagging."
        )

    output.write_text(notes + "\n", encoding="utf-8")
    print(f"Wrote {output} ({len(notes)} chars) from the changelog.")


if __name__ == "__main__":
    main()
