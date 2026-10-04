import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:atlas_app/intelligence/orchestrator/providers/ai_provider.dart';

enum CloudProviderType {
  gemini('gemini', 'Google Gemini', 'gemini-2.5-flash'),
  openai('openai', 'OpenAI', 'gpt-4o-mini'),
  openRouter('openrouter', 'OpenRouter', 'google/gemini-2.5-flash'),
  opencodeZen('opencodezen', 'OpenCode Zen', 'glm-5.2'),
  anthropic('anthropic', 'Anthropic Claude', 'claude-sonnet-4-5');

  const CloudProviderType(this.id, this.label, this.defaultModel);
  final String id;
  final String label;
  final String defaultModel;
}

/// Cloud Bring-Your-Own-Key (BYOK) AI provider.
class CloudByokProvider implements AiProvider {
  CloudByokProvider({
    required this.providerType,
    this.apiKey,
    this.modelOverride,
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client();

  final CloudProviderType providerType;
  final String? apiKey;
  final String? modelOverride;
  final http.Client _client;

  @override
  String get id => 'cloud_${providerType.id}';

  @override
  String get name => providerType.label;

  String get effectiveModel => modelOverride ?? providerType.defaultModel;

  @override
  Future<bool> isAvailable() async {
    return apiKey != null && apiKey!.trim().isNotEmpty;
  }

  @override
  Future<List<String>> getAvailableModels() async {
    return [providerType.defaultModel];
  }

  @override
  Future<String> complete(AiPrompt prompt) async {
    if (!await isAvailable()) {
      throw StateError('API key not configured for ${providerType.label}');
    }

    final model = prompt.model ?? effectiveModel;

    switch (providerType) {
      case CloudProviderType.gemini:
        return _completeGemini(prompt, model);
      case CloudProviderType.openai:
      case CloudProviderType.openRouter:
      case CloudProviderType.opencodeZen:
        return _completeOpenAiCompatible(prompt, model);
      case CloudProviderType.anthropic:
        return _completeAnthropic(prompt, model);
    }
  }

  @override
  Stream<String> completeStream(AiPrompt prompt) async* {
    // For cloud providers, yield the completion or stream SSE tokens
    final full = await complete(prompt);
    yield full;
  }

  Future<String> _completeGemini(AiPrompt prompt, String model) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'systemInstruction': {
          'parts': [
            {'text': prompt.systemPrompt}
          ]
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt.userPrompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': prompt.temperature,
          'maxOutputTokens': prompt.maxTokens,
        }
      }),
    );

    if (response.statusCode != 200) {
      throw http.ClientException('Gemini API error (${response.statusCode}): ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = json['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw http.ClientException('Gemini returned no candidates: ${response.body}');
    }

    final content = (candidates.first as Map<String, dynamic>)['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    final text = parts?.map((p) => (p as Map<String, dynamic>)['text'] as String? ?? '').join('') ?? '';
    return text;
  }

  Future<String> _completeOpenAiCompatible(AiPrompt prompt, String model) async {
    final root = switch (providerType) {
      CloudProviderType.openai => 'https://api.openai.com/v1',
      CloudProviderType.openRouter => 'https://openrouter.ai/api/v1',
      CloudProviderType.opencodeZen => 'https://opencode.zen/v1',
      _ => 'https://api.openai.com/v1',
    };

    final uri = Uri.parse('$root/chat/completions');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'temperature': prompt.temperature,
        'max_tokens': prompt.maxTokens,
        'messages': [
          {'role': 'system', 'content': prompt.systemPrompt},
          {'role': 'user', 'content': prompt.userPrompt},
        ]
      }),
    );

    if (response.statusCode != 200) {
      throw http.ClientException('${providerType.label} error (${response.statusCode}): ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = json['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw http.ClientException('OpenAI-compatible endpoint returned no choices: ${response.body}');
    }

    final firstChoice = choices.first as Map<String, dynamic>;
    final message = firstChoice['message'] as Map<String, dynamic>?;
    return message?['content'] as String? ?? '';
  }

  Future<String> _completeAnthropic(AiPrompt prompt, String model) async {
    final uri = Uri.parse('https://api.anthropic.com/v1/messages');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey!,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': model,
        'system': prompt.systemPrompt,
        'max_tokens': prompt.maxTokens,
        'temperature': prompt.temperature,
        'messages': [
          {'role': 'user', 'content': prompt.userPrompt}
        ]
      }),
    );

    if (response.statusCode != 200) {
      throw http.ClientException('Anthropic error (${response.statusCode}): ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final content = json['content'] as List<dynamic>?;
    if (content == null || content.isEmpty) {
      throw http.ClientException('Anthropic returned empty content');
    }

    return content.map((c) => (c as Map<String, dynamic>)['text'] as String? ?? '').join('');
  }
}

