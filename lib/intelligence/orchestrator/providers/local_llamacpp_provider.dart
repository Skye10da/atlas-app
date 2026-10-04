import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:atlas_app/intelligence/orchestrator/providers/ai_provider.dart';

/// Local llama.cpp runner / server provider running on the host machine.
class LocalLlamaCppProvider implements AiProvider {
  LocalLlamaCppProvider({
    this.endpoint = 'http://127.0.0.1:8080',
    this.defaultModel = 'local-gguf',
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client();

  final String endpoint;
  final String defaultModel;
  final http.Client _client;

  @override
  String get id => 'local_llamacpp';

  @override
  String get name => 'Local llama.cpp (GGUF)';

  String get _normalizedEndpoint {
    var ep = endpoint.trim();
    if (ep.endsWith('/')) ep = ep.substring(0, ep.length - 1);
    return ep;
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final uri = Uri.parse('$_normalizedEndpoint/health');
      final res = await _client.get(uri).timeout(const Duration(milliseconds: 1500));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> getAvailableModels() async {
    return [defaultModel];
  }

  @override
  Future<String> complete(AiPrompt prompt) async {
    final uri = Uri.parse('$_normalizedEndpoint/v1/chat/completions');
    final res = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': prompt.model ?? defaultModel,
        'temperature': prompt.temperature,
        'max_tokens': prompt.maxTokens,
        'messages': [
          {'role': 'system', 'content': prompt.systemPrompt},
          {'role': 'user', 'content': prompt.userPrompt},
        ],
      }),
    );

    if (res.statusCode != 200) {
      throw http.ClientException('llama.cpp server error (${res.statusCode}): ${res.body}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = json['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      return '';
    }
    final firstChoice = choices.first as Map<String, dynamic>;
    final message = firstChoice['message'] as Map<String, dynamic>?;
    return message?['content'] as String? ?? '';
  }

  @override
  Stream<String> completeStream(AiPrompt prompt) async* {
    final full = await complete(prompt);
    yield full;
  }
}

