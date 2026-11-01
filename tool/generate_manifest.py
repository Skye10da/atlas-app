#!/usr/bin/env python3
"""Generates manifest.json — the version feed consumed by the in-app updater.

Usage:
    python3 tool/generate_manifest.py <version-spec> <dist-dir> <output-name>

<version-spec> is the tag without the leading `v`, e.g. `1.0.8+8` or
`1.0.9-rc.1+9`. Every file in <dist-dir> is hashed (SHA-256) and mapped to a
platform based on its filename suffix (`-android.apk`, `-windows.zip`).

The in-app updater (lib/updater/) fetches the LATEST GitHub Release and parses
this file to learn what changed and which asset to download.
"""

import hashlib
import json
import re
import sys
import datetime
from pathlib import Path

# Asset naming contract (see .github/workflows/release.yml and
# docs/plans/landing_upgrade_plan.md):
#     atlas-<version>-<platform>[-<arch>].<ext>
#
# Keys map to the platform vocabulary the in-app updater consumes
# (lib/updater/infrastructure/manifest_codec.dart reads `artifacts[platform]`).
# Arch-tagged names widen the suffix match while keeping the same platform
# key when no plain-named sibling exists — sorted iteration picks the most
# specific suffix first.
PLATFORM_SUFFIXES = {
    "-android.apk": "android",
    "-windows.zip": "windows",
    "-windows-x64.zip": "windows",
    "-windows-arm64.zip": "windows-arm64",
    "-macos.zip": "macos",
    "-macos-arm64.zip": "macos-arm64",
    "-macos-x64.zip": "macos-x64",
    "-linux.tar.gz": "linux",
    "-linux-x64.tar.gz": "linux-x64",
}

VERSION_RE = re.compile(r"^(?P<version>[0-9]+\.[0-9]+\.[0-9]+(?:-[\w.]+)?)(?:\+(?P<build>\d+))?$")


def sha256_of(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_version(spec: str) -> dict:
    match = VERSION_RE.match(spec)
    if not match:
        sys.exit(f"ERROR: tag version '{spec}' is not valid (expected <semver>+<build>, e.g. 1.0.8+8)")
    version = match.group("version")
    build = match.group("build") or "0"
    return {
        "version": version,
        "versionCode": int(build),
        "channel": "beta" if "-" in version else "stable",
    }


def main() -> None:
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    spec, dist_dir, output_name = sys.argv[1], Path(sys.argv[2]), sys.argv[3]

    artifacts: dict[str, dict] = {}
    for path in sorted(dist_dir.iterdir()):
        if path.is_dir():
            continue
        for suffix, platform in PLATFORM_SUFFIXES.items():
            if path.name.endswith(suffix):
                artifacts[platform] = {
                    "file": path.name,
                    "sha256": sha256_of(path),
                    "size": path.stat().st_size,
                }
                break
        else:
            print(f"  (ignored, unknown platform suffix: {path.name})")

    if "android" not in artifacts:
        sys.exit("ERROR: no *-android.apk found in dist dir — the updater always requires an Android artifact.")

    manifest = parse_version(spec)
    manifest.update(
        {
            "publishedAt": datetime.datetime.now(datetime.timezone.utc)
            .isoformat()
            .replace("+00:00", "Z"),
            "artifacts": artifacts,
        }
    )

    out = dist_dir / output_name
    out.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {out}")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
