#!/usr/bin/env bash
set -euo pipefail

# Patches screen_brightness_pro's Windows plugin so it compiles with the
# Flutter Windows engine headers. The plugin registers a dead
# flutter::EventChannel (channel "screen_brightness_pro_events") without
# including <flutter/event_channel.h>, so the build fails with
# "error C2039: 'EventChannel': is not a member of 'flutter'". The channel is
# never used by the Dart side to emit events from this plugin, and the native
# side only calls SetStreamHandler(nullptr) on a freshly-created channel (a
# no-op), so removing the block is functionally identical.

plugin_file=""
if [[ -n "${PUB_CACHE:-}" ]]; then
  for f in "$PUB_CACHE"/hosted/pub.dev/screen_brightness_pro-*/windows/screen_brightness_pro_plugin.cpp; do
    if [[ -f "$f" ]]; then
      plugin_file="$f"
      break
    fi
  done
fi
if [[ -z "$plugin_file" && -n "${LOCALAPPDATA:-}" ]]; then
  cache_dir="$(cygpath -u "$LOCALAPPDATA" 2>/dev/null || echo "$LOCALAPPDATA")/Pub/Cache"
  for f in "$cache_dir"/hosted/pub.dev/screen_brightness_pro-*/windows/screen_brightness_pro_plugin.cpp; do
    if [[ -f "$f" ]]; then
      plugin_file="$f"
      break
    fi
  done
fi
if [[ -z "$plugin_file" ]]; then
  for f in "$HOME"/.pub-cache/hosted/pub.dev/screen_brightness_pro-*/windows/screen_brightness_pro_plugin.cpp; do
    if [[ -f "$f" ]]; then
      plugin_file="$f"
      break
    fi
  done
fi

if [[ -z "$plugin_file" ]]; then
  echo "screen_brightness_pro Windows plugin not found in pub cache" >&2
  exit 1
fi

if ! grep -q 'screen_brightness_pro_events' "$plugin_file"; then
  echo "screen_brightness_pro Windows plugin already patched"
  exit 0
fi

if command -v python >/dev/null 2>&1; then
  PYTHON=python
else
  PYTHON=python3
fi

"$PYTHON" - "$plugin_file" <<'PY'
import sys

path = sys.argv[1]
with open(path, "r") as f:
    content = f.read()

old = '''  auto events =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), "screen_brightness_pro_events",
          &flutter::StandardMethodCodec::GetInstance());
  events->SetStreamHandler(nullptr);

'''

if old not in content:
    print("screen_brightness_pro Windows plugin: EventChannel block not found")
    sys.exit(1)

content = content.replace(old, "", 1)
with open(path, "w") as f:
    f.write(content)

print("patched", path)
PY
