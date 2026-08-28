import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_engine/transport/transport.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_ai_provider.dart';
import 'package:atlas_app/wtr/infrastructure/services/ai_chat_clients.dart';

class _FakeTransport implements Transport {
  Object? jsonGetResponse;
  Object? jsonPostResponse;

  Uri? lastGetUrl;
  Map<String, String>? lastGetHeaders;
  Uri? lastPostUrl;
  Map<String, String>? lastPostHeaders;
  Object? lastPostBody;

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) async {
    lastGetUrl = url;
    lastGetHeaders = headers;
    return jsonGetResponse;
  }

  @override
  Future<Object?> fetchJsonPost(
    Uri url, {
    Map<String, String>? headers,
    Object? jsonBody,
  }) async {
    lastPostUrl = url;
    lastPostHeaders = headers;
    lastPostBody = jsonBody;
    return jsonPostResponse;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('GeminiAiClient', () {
    test(
      'complete posts the generateContent shape and extracts text',
      () async {
        final transport = _FakeTransport()
          ..jsonPostResponse = {
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Hello '},
                    {'text': 'world'},
                  ],
                },
              },
            ],
          };

        final out = await const GeminiAiClient().complete(
          transport,
          apiKey: 'k1',
          model: 'gemini-2.5-flash',
          system: 'sys',
          prompt: 'usr',
        );

        expect(out, 'Hello world');
        expect(
          transport.lastPostUrl!.path,
          endsWith('gemini-2.5-flash:generateContent'),
        );
        expect(transport.lastPostHeaders, {'x-goog-api-key': 'k1'});
        final body = transport.lastPostBody! as Map;
        expect(body['systemInstruction'], {
          'parts': [
            {'text': 'sys'},
          ],
        });
        expect((body['contents']! as List).single, {
          'role': 'user',
          'parts': [
            {'text': 'usr'},
          ],
        });
      },
    );

    test(
      'listModels keeps generateContent-capable ids without prefix',
      () async {
        final transport = _FakeTransport()
          ..jsonGetResponse = {
            'models': [
              {
                'name': 'models/gemini-2.5-flash',
                'supportedGenerationMethods': ['generateContent'],
              },
              {
                'name': 'models/text-embedding-004',
                'supportedGenerationMethods': ['embedContent'],
              },
            ],
          };

        final models = await const GeminiAiClient().listModels(
          transport,
          apiKey: 'k1',
        );

        expect(models, ['gemini-2.5-flash']);
        expect(transport.lastGetUrl!.path, endsWith('/v1beta/models'));
        expect(transport.lastGetHeaders, {'x-goog-api-key': 'k1'});
      },
    );
  });

  group('OpenAiCompatibleClient', () {
    test('complete posts chat/completions and extracts the reply', () async {
      final transport = _FakeTransport()
        ..jsonPostResponse = {
          'choices': [
            {
              'message': {'role': 'assistant', 'content': 'translated!'},
            },
          ],
        };
      final client = OpenAiCompatibleClient(
        Uri.parse('https://api.openai.com/v1'),
      );

      final out = await client.complete(
        transport,
        apiKey: 'sk',
        model: 'gpt-5-mini',
        system: 'sys',
        prompt: 'usr',
      );

      expect(out, 'translated!');
      expect(
        transport.lastPostUrl,
        Uri.parse('https://api.openai.com/v1/chat/completions'),
      );
      expect(transport.lastPostHeaders, {'Authorization': 'Bearer sk'});
      final body = transport.lastPostBody! as Map;
      expect(body['model'], 'gpt-5-mini');
      expect(body['messages'], [
        {'role': 'system', 'content': 'sys'},
        {'role': 'user', 'content': 'usr'},
      ]);
    });

    test('merges provider attribution headers (OpenRouter)', () async {
      final transport = _FakeTransport()
        ..jsonPostResponse = {
          'choices': [
            {
              'message': {'content': 'ok'},
            },
          ],
        };
      final client =
          wtrAiClients[WtrAiProviderId.openRouter]! as OpenAiCompatibleClient;

      await client.complete(
        transport,
        apiKey: 'or',
        model: 'm',
        system: 's',
        prompt: 'u',
      );

      expect(transport.lastPostHeaders, {
        'HTTP-Referer': 'https://atlasreader.app',
        'X-Title': 'Atlas Reader',
        'Authorization': 'Bearer or',
      });
      expect(
        transport.lastPostUrl,
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      );
    });

    test('listModels drops non-chat endpoints', () async {
      final transport = _FakeTransport()
        ..jsonGetResponse = {
          'data': [
            {'id': 'gpt-5-mini'},
            {'id': 'text-embedding-3-large'},
            {'id': 'whisper-1'},
            {'id': 'dall-e-3'},
          ],
        };
      final client = OpenAiCompatibleClient(
        Uri.parse('https://api.openai.com/v1'),
      );

      expect(await client.listModels(transport, apiKey: 'sk'), ['gpt-5-mini']);
      expect(
        transport.lastGetUrl,
        Uri.parse('https://api.openai.com/v1/models'),
      );
    });
  });

  group('AnthropicAiClient', () {
    test(
      'complete posts Messages API requirements and joins text blocks',
      () async {
        final transport = _FakeTransport()
          ..jsonPostResponse = {
            'content': [
              {'type': 'text', 'text': 'part one '},
              {'type': 'tool_use', 'id': 't'},
              {'type': 'text', 'text': 'part two'},
            ],
          };

        final out = await const AnthropicAiClient().complete(
          transport,
          apiKey: 'ak',
          model: 'claude-sonnet-4-6',
          system: 'sys',
          prompt: 'usr',
        );

        expect(out, 'part one part two');
        expect(
          transport.lastPostUrl,
          Uri.parse('https://api.anthropic.com/v1/messages'),
        );
        expect(transport.lastPostHeaders, {
          'x-api-key': 'ak',
          'anthropic-version': '2023-06-01',
        });
        final body = transport.lastPostBody! as Map;
        expect(body['max_tokens'], 8192);
        expect(body['system'], 'sys');
        expect(body['messages'], [
          {'role': 'user', 'content': 'usr'},
        ]);
      },
    );

    test('listModels reads data[].id', () async {
      final transport = _FakeTransport()
        ..jsonGetResponse = {
          'data': [
            {'id': 'claude-sonnet-4-6'},
            {'id': 'claude-haiku-4-5'},
          ],
        };

      final models = await const AnthropicAiClient().listModels(
        transport,
        apiKey: 'ak',
      );

      expect(models, ['claude-haiku-4-5', 'claude-sonnet-4-6']);
      expect(
        transport.lastGetUrl,
        Uri.parse('https://api.anthropic.com/v1/models'),
      );
    });
  });

  group('wtrAiClients registry', () {
    test('covers every provider with the right client shapes', () {
      expect(wtrAiClients.keys.toSet(), WtrAiProviderId.values.toSet());
      expect(wtrAiClients[WtrAiProviderId.gemini], isA<GeminiAiClient>());
      expect(wtrAiClients[WtrAiProviderId.anthropic], isA<AnthropicAiClient>());
      for (final id in [
        WtrAiProviderId.openai,
        WtrAiProviderId.openRouter,
        WtrAiProviderId.opencodeZen,
      ]) {
        expect(wtrAiClients[id], isA<OpenAiCompatibleClient>());
      }
      expect(
        (wtrAiClients[WtrAiProviderId.opencodeZen]! as OpenAiCompatibleClient)
            .baseUrl
            .toString(),
        'https://opencode.ai/zen/v1',
      );
    });
  });
}
