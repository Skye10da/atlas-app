# Rule: Full Changelog on Every Commit and Every Release

**Effective:** 2026-11-04
**Scope:** Every commit pushed to `atlas-app`, and every GitHub Release the
release workflow publishes.

## Requirement

### 1. Commit with the full changelog (never a bare subject)

Before any `git commit`:

1. Update `CHANGELOG.md` under `## [Unreleased]` with the complete entry for
   the change. Use the Keep a Changelog headings (`### Added`, `### Changed`,
   `### Fixed`, `### Removed`, `### Security`).
2. The entry is the **full** changelog: what changed, why it broke or was
   missing, and the user-visible effect. A reader who never sees the diff must
   understand the change from the entry alone. Do not reduce a multi-part fix
   to a one-liner.
3. Put the same text in the commit message body. Subject = one-line summary
   (`area: what changed`), body = the full changelog entry. Never commit with
   only a subject, and never substitute `wip`/`chore`/`updates` for it.
4. Stage `CHANGELOG.md` in the same commit as the code it describes.

### 2. Publish releases with the actual changelog (never a compare link)

1. Before tagging, move `## [Unreleased]` to `## [<version>] - <YYYY-MM-DD>`
   (`<version>` without the `+<build>` suffix) and commit that promotion.
2. The release workflow generates the release body with
   `tool/build_release_notes.py`, which reads `CHANGELOG.md` (the matching
   version section first, then `[Unreleased]`) and falls back to the full
   commit messages between the previous tag and the new one.
3. `gh release create --generate-notes` is forbidden: it produces PR titles and
   a `Full Changelog: .../compare/...` link, which is not a changelog.
4. A release body that is empty, or that consists only of a commit/compare
   link, is a failed release. The workflow fails fast instead of publishing it.

## Enforcement

- CI: `.github/workflows/release.yml` builds the body with
  `tool/build_release_notes.py` (`--notes-file`) and the script exits non-zero
  when it cannot produce real notes.
- Review: reject commits that do not add a `CHANGELOG.md` entry or whose body
  does not describe the change; reject releases whose body is only a link.

## Verification

```bash
# Preview what the next release body will contain:
python3 tool/build_release_notes.py "v1.0.10+10" CHANGELOG.md release-notes.md
```
