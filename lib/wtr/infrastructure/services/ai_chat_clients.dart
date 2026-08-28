import 'package:atlas_app/core/content_engine/transport/transport.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_ai_provider.dart';
import 'package:atlas_app/wtr/domain/services/ai_chat_client.dart';

/// The three client shapes behind [WtrAiProviderId]:
///
/// * [GeminiAiClient] — Google's native `generateContent` API.
/// * [OpenAiCompatibleClient] — the OpenAI `chat/completions` shape, shared
///   by OpenAI, OpenRouter and OpenCode Zen.
/// * [AnthropicAiClient] — Anthropic's Messages API.

class GeminiAiClient implements AiChatClient {
  const GeminiAiClient();

  /// Versioned API root; endpoints are appended by string so the version
  /// segment survives (Uri.resolve would treat `/v1beta` as a file segment).
  static const _root = 'https://generativelanguage.googleapis.com/v1beta';

  @override
  Future<String> complete(
    Transport transport, {
    required String apiKey,
    required String model,
    required String system,
    required String prompt,
  }) async {
    final value = await transport.fetchJsonPost(
      Uri.parse('$_root/$model:generateContent'),
      headers: {'x-goog-api-key': apiKey},
      jsonBody: {
        'systemInstruction': {
          'parts': [
            {'text': system},
          ],
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {'temperature': 0.2},
      },
    );
    return _extractText(value);
  }

  /// Walks `candidates[0].content.parts[*].text`, joining the text parts.
  String _extractText(Object? value) {
    final candidates = _field(value, 'candidates');
    if (candidates is! List || candidates.isEmpty) {
      throw const TransportException('Gemini: response has no candidates');
    }
    final content = _field(candidates.first, 'content');
    final parts = _field(content, 'parts');
    if (parts is! List || parts.isEmpty) {
      throw const TransportException('Gemini: candidate has no parts');
    }
    final buffer = StringBuffer();
    for (final part in parts) {
      final text = _field(part, 'text');
      if (text is String) buffer.write(text);
    }
    final out = buffer.toString();
    if (out.isEmpty) {
      throw const TransportException('Gemini: empty completion');
    }
    return out;
  }

  @override
  Future<List<String>> listModels(
    Transport transport, {
    required String apiKey,
  }) async {
    final value = await transport.fetchJson(
      Uri.parse('$_root/models'),
      headers: {'x-goog-api-key': apiKey},
    );
    final models = _field(value, 'models');
    if (models is! List) return const [];
    return models
        .whereType<Map>()
        .where(
          (m) => (_field(m, 'supportedGenerationMethods') as List? ?? const [])
              .contains('generateContent'),
        )
        .map((m) => '${_field(m, 'name')}')
        .map((name) => name.replaceFirst(RegExp(r'^models/'), ''))
        .where((id) => id.isNotEmpty)
        .toList()
      ..sort();
  }

  static Object? _field(Object? parent, String key) =>
      parent is Map ? parent[key] : null;
}

/// One class for every OpenAI-shaped API: [baseUrl] points at the versioned
/// root (`…/v1`) and both endpoints are appended to it.
class OpenAiCompatibleClient implements AiChatClient {
  const OpenAiCompatibleClient(this.baseUrl, {this.extraHeaders = const {}});

  /// Versioned API root, e.g. `https://api.openai.com/v1`. Endpoints are
  /// appended by string so the version segment survives.
  final Uri baseUrl;

  String get _root => baseUrl.toString().replaceFirst(RegExp(r'/+$'), '');

  /// Provider-specific headers merged into every call (OpenRouter asks for
  /// attribution headers; harmless elsewhere).
  final Map<String, String> extraHeaders;

  @override
  Future<String> complete(
    Transport transport, {
    required String apiKey,
    required String model,
    required String system,
    required String prompt,
  }) async {
    final value = await transport.fetchJsonPost(
      Uri.parse('$_root/chat/completions'),
      headers: {...extraHeaders, 'Authorization': 'Bearer $apiKey'},
      jsonBody: {
        'model': model,
        'temperature': 0.2,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': prompt},
        ],
      },
    );
    final choices = _field(value, 'choices');
    if (choices is! List || choices.isEmpty) {
      throw const TransportException('OpenAI-compatible: no choices');
    }
    final message = _field(choices.first, 'message');
    final content = _field(message, 'content');
    if (content is! String || content.isEmpty) {
      throw const TransportException('OpenAI-compatible: empty completion');
    }
    return content;
  }

  @override
  Future<List<String>> listModels(
    Transport transport, {
    required String apiKey,
  }) async {
    final value = await transport.fetchJson(
      Uri.parse('$_root/models'),
      headers: {...extraHeaders, 'Authorization': 'Bearer $apiKey'},
    );
    final data = _field(value, 'data');
    if (data is! List) return const [];
    return data
        .map(_modelId)
        .whereType<String>()
        .where(_looksLikeChatModel)
        .toList()
      ..sort();
  }

  static Object? _modelId(Object? entry) => entry is Map ? entry['id'] : null;

  /// Drops obviously non-chat endpoints so the picker stays usable. The
  /// free-text override in Settings remains the escape hatch either way.
  static bool _looksLikeChatModel(Object? id) {
    if (id is! String || id.isEmpty) return false;
    final lower = id.toLowerCase();
    return !lower.contains('embedding') &&
        !lower.contains('whisper') &&
        !lower.contains('tts') &&
        !lower.contains('dall-e') &&
        !lower.contains('moderation') &&
        !lower.contains('rerank');
  }

  static Object? _field(Object? parent, String key) =>
      parent is Map ? parent[key] : null;
}

class AnthropicAiClient implements AiChatClient {
  const AnthropicAiClient();

  /// Versioned API root; endpoints are appended by string.
  static const _root = 'https://api.anthropic.com/v1';

  @override
  Future<String> complete(
    Transport transport, {
    required String apiKey,
    required String model,
    required String system,
    required String prompt,
  }) async {
    final value = await transport.fetchJsonPost(
      Uri.parse('$_root/messages'),
      headers: {'x-api-key': apiKey, 'anthropic-version': '2023-06-01'},
      jsonBody: {
        'model': model,
        // Required by the Messages API. Generous enough for a full chunk of
        // translated paragraphs without being wasteful.
        'max_tokens': 8192,
        'temperature': 0.2,
        'system': system,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      },
    );
    final contentBlocks = _field(value, 'content');
    if (contentBlocks is! List || contentBlocks.isEmpty) {
      throw const TransportException('Anthropic: response has no content');
    }
    final buffer = StringBuffer();
    for (final block in contentBlocks) {
      if (block is Map && block['type'] == 'text') {
        buffer.write(block['text']);
      }
    }
    final out = buffer.toString();
    if (out.isEmpty) {
      throw const TransportException('Anthropic: empty completion');
    }
    return out;
  }

  @override
  Future<List<String>> listModels(
    Transport transport, {
    required String apiKey,
  }) async {
    final value = await transport.fetchJson(
      Uri.parse('$_root/models'),
      headers: {'x-api-key': apiKey, 'anthropic-version': '2023-06-01'},
    );
    final data = _field(value, 'data');
    if (data is! List) return const [];
    return [
      for (final entry in data)
        if (entry is Map && entry['id'] is String) entry['id'] as String,
    ]..sort();
  }

  static Object? _field(Object? parent, String key) =>
      parent is Map ? parent[key] : null;
}

/// The client instances backing each provider.
final wtrAiClients = <WtrAiProviderId, AiChatClient>{
  WtrAiProviderId.gemini: const GeminiAiClient(),
  WtrAiProviderId.openai: OpenAiCompatibleClient(
    Uri.parse('https://api.openai.com/v1'),
  ),
  WtrAiProviderId.openRouter: OpenAiCompatibleClient(
    Uri.parse('https://openrouter.ai/api/v1'),
    extraHeaders: {
      'HTTP-Referer': 'https://atlasreader.app',
      'X-Title': 'Atlas Reader',
    },
  ),
  WtrAiProviderId.opencodeZen: OpenAiCompatibleClient(
    Uri.parse('https://opencode.ai/zen/v1'),
  ),
  WtrAiProviderId.anthropic: const AnthropicAiClient(),
};
