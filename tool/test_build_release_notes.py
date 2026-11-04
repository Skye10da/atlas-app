#!/usr/bin/env python3
"""Tests for tool/build_release_notes.py (run: python -m unittest tool/test_build_release_notes.py)."""

import tempfile
import unittest
from pathlib import Path

from build_release_notes import (
    build_notes,
    parse_sections,
    pick_notes,
    tag_version,
)

CHANGELOG = """# Changelog

Intro text that must never leak into a release.

## [Unreleased]

### Added
- **Unreleased feature** — does the new thing.

## [1.0.10] - 2026-11-04

### Fixed
- **Install button** — opens the permission screen.

## [1.0.9] - 2026-10-30

### Changed
- Old release note.

## Notes

Not a release section.
"""


class TagVersionTest(unittest.TestCase):
    def test_strips_prefix_and_build_suffix(self):
        self.assertEqual(tag_version("v1.0.10+10"), "1.0.10")

    def test_accepts_bare_spec(self):
        self.assertEqual(tag_version("1.0.9-rc.1+9"), "1.0.9-rc.1")


class SectionParsingTest(unittest.TestCase):
    def test_sections_are_keyed_by_label(self):
        sections = parse_sections(CHANGELOG)
        self.assertIn("1.0.10", sections)
        self.assertIn("unreleased", sections)
        self.assertNotIn("Notes", sections["1.0.10"])

    def test_version_section_wins(self):
        notes = pick_notes(parse_sections(CHANGELOG), "1.0.10")
        self.assertIn("Install button", notes)
        self.assertNotIn("Unreleased feature", notes)

    def test_unreleased_is_the_fallback(self):
        notes = pick_notes(parse_sections(CHANGELOG), "2.0.0")
        self.assertIn("Unreleased feature", notes)

    def test_missing_section_returns_none(self):
        notes = pick_notes(parse_sections("## [1.0.9]\n\n### Fixed\n- x\n"), "9.9.9")
        self.assertIsNone(notes)


class BuildNotesTest(unittest.TestCase):
    def test_release_body_is_the_actual_changelog(self):
        with tempfile.TemporaryDirectory() as tmp:
            changelog = Path(tmp) / "CHANGELOG.md"
            changelog.write_text(CHANGELOG, encoding="utf-8")
            notes = build_notes("v1.0.10+10", changelog)
        self.assertIn("### Fixed", notes)
        self.assertIn("Install button", notes)
        # Never a GitHub compare link.
        self.assertNotIn("/compare/", notes)


if __name__ == "__main__":
    unittest.main()
