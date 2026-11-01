// Conditional-export facade for the landing page's web interop.
//
// `dart:js_interop` cannot be imported on native targets (VM/Windows) —
// the whole marketing module must keep compiling there (tests + the Windows
// app build), so the real JS bindings live in `web_interop_js.dart` and this
// facade picks them only when the JS platform library is available.
//
// See `web_interop_js.dart` for the contract every implementation must keep:
//   * `collectDeviceProbe()` → DeviceProbe? (null off-web)
//   * `fetchUaClientHints()` → UaClientHints? (null when unsupported)
//   * `triggerBrowserDownload(url, fileName)` → bool (false = caller falls
//     back to an external navigation)
export 'web_interop_io.dart' if (dart.library.js_interop) 'web_interop_js.dart';
