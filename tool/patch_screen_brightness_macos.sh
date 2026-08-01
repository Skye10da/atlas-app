#!/usr/bin/env bash
set -euo pipefail

# Patches screen_brightness_pro's macOS plugin so it compiles with modern
# Xcode SDKs. The plugin only does `import IOKit`, but the power-management
# and power-sources symbols it uses (IOPMAssertion*, IOPSCopyPowerSources*)
# live in the IOKit.pwr_mgt and IOKit.ps submodules, which are no longer
# exposed transitively under Swift's explicit-modules builds.

plugin_file=""
for f in "$HOME"/.pub-cache/hosted/pub.dev/screen_brightness_pro-*/macos/Classes/ScreenBrightnessProPlugin.swift; do
  if [[ -f "$f" ]]; then
    plugin_file="$f"
    break
  fi
done

if [[ -z "$plugin_file" ]]; then
  echo "screen_brightness_pro macOS plugin not found in pub cache" >&2
  exit 1
fi

if grep -q 'import IOKit.pwr_mgt' "$plugin_file"; then
  echo "screen_brightness_pro macOS plugin already patched"
  exit 0
fi

python3 - "$plugin_file" <<'PY'
import sys

path = sys.argv[1]
with open(path, "r") as f:
    lines = f.readlines()

out = []
for line in lines:
    out.append(line)
    if line.strip() == "import IOKit":
        out.append("import IOKit.pwr_mgt\n")
        out.append("import IOKit.ps\n")

with open(path, "w") as f:
    f.writelines(out)

print("patched", path)
PY
