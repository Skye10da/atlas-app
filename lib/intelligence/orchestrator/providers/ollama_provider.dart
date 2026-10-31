import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:atlas_app/intelligence/orchestrator/providers/ai_provider.dart';

/// Wall-clock cap for a single local-model completion request. Generations
/// on slower hardware can legitimately take a while, so this is more
/// generous than the cloud timeout — but it must exist, or a wedged server
/// freezes the chat's `isThinking` state forever.
const Duration kLocalCompletionTimeout = Duration(seconds: 120);

/// Local or LAN Ollama provider supporting dynamic model listing and streaming.
class OllamaProvider implements AiProvider {
  OllamaProvider({
    this.endpoint = 'http://localhost:11434',
    this.defaultModel = 'llama3.2',
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client();

  final String endpoint;
  final String defaultModel;
  final http.Client _client;

  @override
  String get id => 'ollama';

  @override
  String get name => 'Ollama (Local / LAN)';

  String get _normalizedEndpoint {
    var ep = endpoint.trim();
    if (ep.endsWith('/')) ep = ep.substring(0, ep.length - 1);
    return ep;
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final uri = Uri.parse('$_normalizedEndpoint/api/tags');
      final res = await _client.get(uri).timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> getAvailableModels() async {
    try {
      final uri = Uri.parse('$_normalizedEndpoint/api/tags');
      final res = await _client.get(uri).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final models = json['models'] as List<dynamic>?;
        if (models != null) {
          return models
              .map((m) => (m as Map<String, dynamic>)['name'] as String? ?? '')
              .where((name) => name.isNotEmpty)
              .toList();
        }
      }
    } catch (_) {
      // Fallback
    }
    return [defaultModel];
  }

  @override
  Future<String> complete(AiPrompt prompt) async {
    final uri = Uri.parse('$_normalizedEndpoint/api/chat');
    final model = prompt.model ?? defaultModel;

    final res = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': model,
        'stream': false,
        'options': {
          'temperature': prompt.temperature,
          'num_predict': prompt.maxTokens,
        },
        'messages': [
          {'role': 'system', 'content': prompt.systemPrompt},
          {'role': 'user', 'content': prompt.userPrompt},
        ],
      }),
    ).timeout(kLocalCompletionTimeout);

    if (res.statusCode != 200) {
      throw http.ClientException('Ollama returned HTTP ${res.statusCode}: ${res.body}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final message = json['message'] as Map<String, dynamic>?;
    return message?['content'] as String? ?? '';
  }

  @override
  Stream<String> completeStream(AiPrompt prompt) async* {
    final uri = Uri.parse('$_normalizedEndpoint/api/chat');
    final model = prompt.model ?? defaultModel;

    final request = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'model': model,
        'stream': true,
        'options': {
          'temperature': prompt.temperature,
          'num_predict': prompt.maxTokens,
        },
        'messages': [
          {'role': 'system', 'content': prompt.systemPrompt},
          {'role': 'user', 'content': prompt.userPrompt},
        ],
      });

    final response = await _client.send(request);
    if (response.statusCode != 200) {
      throw http.ClientException('Ollama streaming error (${response.statusCode})');
    }

    yield* response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .map((line) {
          if (line.trim().isEmpty) return '';
          try {
            final json = jsonDecode(line) as Map<String, dynamic>;
            final msg = json['message'] as Map<String, dynamic>?;
            return msg?['content'] as String? ?? '';
          } catch (_) {
            return '';
          }
        })
        .where((token) => token.isNotEmpty);
  }
}

