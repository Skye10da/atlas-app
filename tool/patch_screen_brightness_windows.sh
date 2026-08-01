#!/usr/bin/env bash
set -euo pipefail

# Patches screen_brightness_pro's Windows plugin so it compiles and links with
# current Flutter Windows toolchains. Two problems are fixed:
#
# 1. The plugin registers a dead flutter::EventChannel (channel
#    "screen_brightness_pro_events") without including
#    <flutter/event_channel.h>, so the build fails with
#    "error C2039: 'EventChannel': is not a member of 'flutter'". The channel is
#    never used by the Dart side to emit events from this plugin, and the native
#    side only calls SetStreamHandler(nullptr) on a freshly-created channel (a
#    no-op), so removing the block is functionally identical.
#
# 2. The plugin includes <comutil.h> and uses _bstr_t/bstr_t, which pull in
#    _com_issue_error and _com_util::ConvertStringToBSTR from comsuppw.lib.
#    Flutter tooling links comsuppw.lib for plugins, but the GitHub Actions
#    windows-latest toolchain (VS2026/MSVC 14.5x) does not export those symbols
#    from it, producing LNK2019 unresolved-external errors. The patch replaces
#    _bstr_t/bstr_t with a self-contained BSTR RAII holder that only depends on
#    oleaut32 (SysAllocString/SysFreeString), which is always available.

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

if grep -q 'class BstrHolder' "$plugin_file"; then
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

changed = False

# --- 1. Remove the dead EventChannel block (problem #1). ---
old = '''  auto events =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), "screen_brightness_pro_events",
          &flutter::StandardMethodCodec::GetInstance());
  events->SetStreamHandler(nullptr);

'''
if old in content:
    content = content.replace(old, "", 1)
    changed = True

# --- 2. Drop the comsuppw dependency (problem #2). ---

# 2a. Remove the <comutil.h> include.
if "#include <comutil.h>" in content:
    content = content.replace("#include <comutil.h>\n", "", 1)
    changed = True

# 2b. Insert a self-contained BSTR RAII holder after the pragma comment.
helper = '''
namespace {
class BstrHolder {
 public:
  explicit BstrHolder(const wchar_t *s) : bstr_(::SysAllocString(s ? s : L"")) {}
  explicit BstrHolder(const char *s) : bstr_(nullptr) {
    if (s) {
      int wlen = ::MultiByteToWideChar(CP_ACP, 0, s, -1, nullptr, 0);
      if (wlen > 0) {
        bstr_ = ::SysAllocStringLen(nullptr, wlen - 1);
        ::MultiByteToWideChar(CP_ACP, 0, s, -1, bstr_, wlen);
      }
    }
  }
  ~BstrHolder() { ::SysFreeString(bstr_); }
  BstrHolder(const BstrHolder &) = delete;
  BstrHolder &operator=(const BstrHolder &) = delete;
  operator BSTR() const { return bstr_; }

 private:
  BSTR bstr_;
};
}  // namespace
'''
anchor = '#pragma comment(lib, "wbemuuid.lib")'
if anchor in content:
    content = content.replace(anchor, anchor + helper, 1)
    changed = True

# 2c. Replace the _bstr_t / bstr_t call sites (order matters: _bstr_t first).
content = content.replace("_bstr_t", "BstrHolder")
content = content.replace("bstr_t", "BstrHolder")

with open(path, "w") as f:
    f.write(content)

print("patched", path)
PY
