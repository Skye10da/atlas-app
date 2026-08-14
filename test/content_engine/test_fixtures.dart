import 'package:atlas_app/core/content_engine/plugins/plugin_filters.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/plugins/verification.dart';
import 'package:atlas_app/core/content_engine/selectors/selector_set.dart';
import 'package:atlas_app/core/content_engine/templates/template.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';

/// Test transport keyed by URL path (query-string order agnostic). Throws
/// [TransportException] on a miss, like OfflineTransport, so template
/// fallback paths are exercised naturally.
class FakeTransport implements Transport {
  final Map<String, String> htmlByPath = {};
  final Map<String, Object?> jsonByPath = {};
  final Map<String, String> htmlByUrl = {};
  final Map<String, Object?> jsonByUrl = {};
  final Map<String, String> postHtmlByUrl = {};
  final Map<String, Object?> postJsonByUrl = {};
  int htmlCalls = 0;
  int jsonCalls = 0;

  void addHtml(String url, String body) {
    htmlByUrl[url] = body;
    htmlByPath[Uri.parse(url).path] = body;
  }

  void addJson(String url, Object? value) {
    jsonByUrl[url] = value;
    jsonByPath[Uri.parse(url).path] = value;
  }

  /// Registers the body a form POST to [url] returns. Keyed by URL only; the
  /// exact form payload is whatever the template under test is configured to
  /// send.
  void addPostHtml(String url, String body) => postHtmlByUrl[url] = body;

  /// Registers the body a JSON POST to [url] returns. Keyed by URL only; the
  /// exact JSON payload is whatever the template under test sends.
  void addPostJson(String url, Object? value) => postJsonByUrl[url] = value;

  @override
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) async {
    htmlCalls++;
    final body = htmlByUrl[url.toString()] ?? htmlByPath[url.path];
    if (body == null) throw TransportException('No fixture for $url');
    return body;
  }

  @override
  Future<String> fetchHtmlPost(
    Uri url, {
    Map<String, String>? headers,
    Map<String, String>? form,
  }) async {
    htmlCalls++;
    final body = postHtmlByUrl[url.toString()];
    if (body == null) throw TransportException('No fixture for POST $url');
    return body;
  }

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) async {
    jsonCalls++;
    final value = jsonByUrl[url.toString()] ?? jsonByPath[url.path];
    if (value == null) throw TransportException('No fixture for $url');
    return value;
  }

  @override
  Future<Object?> fetchJsonPost(
    Uri url, {
    Map<String, String>? headers,
    Object? jsonBody,
  }) async {
    jsonCalls++;
    final value = postJsonByUrl[url.toString()];
    if (value == null) throw TransportException('No fixture for POST $url');
    return value;
  }

  @override
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers}) async {
    final body = await fetchHtml(url, headers: headers);
    return body.codeUnits;
  }
}

PluginManifest buildManifest({
  String id = 'test-plugin',
  String templateId = 'html',
  String transport = 'http',
  String baseUrl = 'https://example.com',
  String sourceName = 'Test Plugin',
  List<PluginCapability>? capabilities,
}) =>
    PluginManifest(
      id: id,
      name: 'Test Plugin',
      sourceName: sourceName,
      version: const PluginVersion(major: 1, minor: 0, patch: 0),
      templateId: templateId,
      baseUrl: baseUrl,
      transport: transport,
      capabilities: capabilities ?? PluginCapability.values.toList(),
    );

PluginContext buildContext({
  PluginManifest? manifest,
  Transport? transport,
  SelectorSet? selectors,
  PluginFilters? filters,
}) =>
    PluginContext(
      plugin: manifest ?? buildManifest(),
      transport: transport ?? FakeTransport(),
      selectors: selectors,
      filters: filters,
    );
