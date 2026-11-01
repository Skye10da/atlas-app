// Real (web) implementation of the landing page web interop.
//
// Thin, hand-rolled JS bindings — the only web interop surface in the
// marketing module. Two responsibilities, deliberately minimal (navigator +
// document only):
//   1. Device probe collection: UA string + UA Client Hints (high-entropy
//      values) for `DeviceProfileService` classification.
//   2. Browser download trigger: an invisible anchor click so the browser's
//      native download flow (dialog/progress/notification) is used instead
//      of navigating the visitor away.
//
// Hand-rolled `@JS` declarations with explicit extension types (no generic
// unsafe property/method calls) so the API surface is statically owned here;
// every call is failure-tolerant (null/false) because no browser guarantees
// are made (Safari lacks userAgentData, Android/iOS WebView hybrids vary).
//
// DOM-wrapping rationale: the invisible anchor is created, configured,
// appended to `document.body`, clicked, and removed — a microtask burst the
// browser GC reclaims; nothing persists.

import 'dart:js_interop';

import 'package:atlas_app/marketing/domain/entities/device_profile.dart';
import 'package:atlas_app/marketing/domain/services/web_interop_io.dart'
    show UaClientHints;

@JS('window.navigator')
external NavigatorBinding get _navigator;

extension type NavigatorBinding._(JSObject _) implements JSObject {
  external JSString get userAgent;
  external JSString? get platform;
  external JSAny? get userAgentData;

  /// `Navigator.maxTouchPoints`, nullable in WebIDL; absent environments are
  /// `undefined` at runtime and resolve to `null` here. `int` is an allowed
  /// primitive in extension-type interop members (maps to JSNumber).
  external int? get maxTouchPoints;
}

extension type NavigatorUaData._(JSObject _) implements JSObject {
  external JSPromise<UaDataValues> getHighEntropyValues(JSAny hints);
}

/// Typed view of the high-entropy values object returned by the browser.
extension type UaDataValues._(JSObject _) implements JSObject {
  external JSString? get platform;
  external JSString? get platformVersion;
  external JSString? get architecture;
  external JSString? get bitness;
}

@JS('window.document')
external DocumentBinding get _document;

extension type DocumentBinding._(JSObject _) implements JSObject {
  external JSObject createElement(String tag);
  external JSObject? get body;
}

extension type BodyBinding._(JSObject _) implements JSObject {
  external void appendChild(JSObject child);
}

extension type AnchorBinding._(JSObject _) implements JSObject {
  external set href(String value);
  external set download(String value);
  external void click();
  external void remove();
}

/// Collects the device probe off the real browser.
///
/// Returns `null` when no browser is available (non-web target) or collection
/// failed hard — never throws. UA-CH is best-effort: a browser without
/// `userAgentData` yields a probe that only carries UA-string fields.
Future<DeviceProbe?> collectDeviceProbe() async {
  try {
    final navigator = _navigator;
    final ua = navigator.userAgent.toDart;
    final platform = navigator.platform?.toDart ?? '';
    final touchPoints = navigator.maxTouchPoints ?? 0;
    final base = DeviceProbe(
      userAgent: ua,
      platform: platform,
      maxTouchPoints: touchPoints,
    );

    final hints = await fetchUaClientHints();
    return base.hinted(
      platform: hints?.platform,
      platformVersion: hints?.platformVersion,
      architecture: hints?.architecture,
      bitness: hints?.bitness,
    );
  } catch (_) {
    return null;
  }
}

/// Fetches high-entropy UA Client Hints when the browser supports them
/// (Chromium family). Unsupported browsers resolve to `null`.
Future<UaClientHints?> fetchUaClientHints() async {
  try {
    final data = _navigator.userAgentData;
    if (data == null || !data.isA<NavigatorUaData>()) return null;

    const hintNames = <String>[
      'platform',
      'platformVersion',
      'architecture',
      'bitness',
    ];
    final values = await (data as NavigatorUaData)
        .getHighEntropyValues(hintNames.jsify()!)
        .toDart;

    return UaClientHints(
      platform: values.platform?.toDart,
      platformVersion: values.platformVersion?.toDart,
      architecture: values.architecture?.toDart,
      bitness: values.bitness?.toDart,
    );
  } catch (_) {
    return null;
  }
}

/// Triggers the browser's native download flow for [url] by dispatching a
/// one-shot click on an invisible anchor with a `download` attribute.
///
/// Returns false when no DOM body exists yet or the DOM call failed, so
/// callers can fall back to an external navigation.
bool triggerBrowserDownload(String url, String suggestedFileName) {
  try {
    final doc = _document;
    final body = doc.body;
    if (body == null) return false;
    final anchor = doc.createElement('a') as AnchorBinding;
    anchor.href = url;
    anchor.download = suggestedFileName;
    (body as BodyBinding).appendChild(anchor);
    anchor.click();
    anchor.remove();
    return true;
  } catch (_) {
    return false;
  }
}
