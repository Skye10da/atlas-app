import 'dart:async';

import 'package:atlas_app/core/content_engine/transport/transport.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_glossary_term.dart';
import 'package:atlas_app/wtr/domain/services/ai_chat_client.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_ai_provider.dart';
import 'package:atlas_app/wtr/infrastructure/repositories/shared_prefs_wtr_ai_settings_repository.dart';
import 'package:atlas_app/wtr/infrastructure/services/ai_chat_clients.dart';

/// Why the AI+ path failed, in the vocabulary the UI needs.
enum WtrAiFailureReason {
  /// No API key / model configured yet.
  notConfigured,

  /// The provider rejected the key (401/403) — retrying cannot help.
  auth,

  /// HTTP 429 or a server-side outage that persisted through retries.
  rateLimited,

  /// Network failure or timeout that persisted through retries.
  transient,

  /// The provider answered, but unusably (unparseable shape, wrong paragraph
  /// count, empty text).
  badResponse,
}

class WtrAiTranslateException implements Exception {
  const WtrAiTranslateException(this.reason, this.message, [this.cause]);

  final WtrAiFailureReason reason;
  final String message;
  final Object? cause;

  @override
  String toString() => 'WtrAiTranslateException(${reason.name}): $message';
}

/// Translates chapter paragraphs with the user's own AI provider.
///
/// The pipeline mirrors `WtrWebTranslateService` where it can: paragraphs are
/// grouped into bounded chunks and translated one chunk at a time. Unlike
/// the free Google endpoint, an AI call costs the user money and is rate
/// limited, so the policy here is deliberate:
///
/// * Chunks are numbered (`<1>…`) so output can be validated against input —
///   a model dropping or merging paragraphs fails loudly instead of
///   silently corrupting a chapter.
/// * Rate limits (429), server errors (5xx) and timeouts are retried up to
///   [_maxAttempts] attempts per chunk, honoring the provider's
///   `Retry-After` hint (clamped so reading never stalls long).
/// * Auth failures fail immediately; there is nothing to gain from retrying.
/// * Any exhausted chunk aborts the *whole* translation — callers fall back
///   to Google for the entire chapter rather than mixing two translators.
class WtrAiTranslateService {
  WtrAiTranslateService({
    SharedPrefsWtrAiSettingsRepository? settingsRepository,
    Map<WtrAiProviderId, AiChatClient>? clients,
    int maxAttempts = _maxAttempts,
    Duration requestTimeout = _defaultRequestTimeout,
    Future<void> Function(Duration delay)? delay,
  }) : _settingsRepository =
           settingsRepository ?? const SharedPrefsWtrAiSettingsRepository(),
       _clients = clients ?? wtrAiClients,
       maxAttempts = maxAttempts < 1 ? 1 : maxAttempts,
       _requestTimeout = requestTimeout,
       _delay = delay;

  static const _maxAttempts = 3;
  static const _defaultRequestTimeout = Duration(seconds: 60);

  /// Never wait longer than this for a provider-declared cooldown; beyond it
  /// the reader would stall unacceptably before degrading to Google.
  static const _maxRetryAfter = Duration(seconds: 30);
  static const _baseBackoff = Duration(seconds: 2);

  final SharedPrefsWtrAiSettingsRepository _settingsRepository;
  final Map<WtrAiProviderId, AiChatClient> _clients;
  final int maxAttempts;
  final Duration _requestTimeout;

  /// Injectable sleeper so tests run without real wall-clock delays.
  final Future<void> Function(Duration delay)? _delay;

  /// Translates every paragraph from source language into the language tag
  /// [to] (e.g. `en`), applying [terms] as hard naming rules.
  ///
  /// Throws [WtrAiTranslateException] when translation cannot be completed;
  /// see the class docs for the retry/fallback policy.
  Future<List<String>> translateParagraphs(
    Transport transport, {
    required List<String> paragraphs,
    List<WtrGlossaryTerm> terms = const [],
    String to = 'en',
  }) async {
    final settings = await _settingsRepository.load();
    final apiKey = settings.activeApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw const WtrAiTranslateException(
        WtrAiFailureReason.notConfigured,
        'No AI-provider API key configured.',
      );
    }
    final client = _clients[settings.provider];
    if (client == null) {
      throw WtrAiTranslateException(
        WtrAiFailureReason.notConfigured,
        'No client registered for ${settings.provider.label}.',
      );
    }
    final model = settings.activeModel;

    final out = List<String>.filled(paragraphs.length, '');
    for (final chunk in chunk(paragraphs)) {
      final translated = await _translateChunk(
        transport,
        client: client,
        apiKey: apiKey,
        model: model,
        terms: terms,
        to: to,
        chunk: chunk,
      );
      for (var i = 0; i < chunk.paragraphs.length; i++) {
        out[chunk.offset + i] = translated[i];
      }
    }
    return out;
  }

  Future<List<String>> _translateChunk(
    Transport transport, {
    required AiChatClient client,
    required String apiKey,
    required String model,
    required List<WtrGlossaryTerm> terms,
    required String to,
    required NumberedChunk chunk,
  }) async {
    final system = _systemPrompt(terms, to);
    final prompt = _numbered(chunk.paragraphs, chunk.offset);

    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final raw = await client
            .complete(
              transport,
              apiKey: apiKey,
              model: model,
              system: system,
              prompt: prompt,
            )
            .timeout(_requestTimeout);
        return _parseNumbered(raw, expectedCount: chunk.paragraphs.length, offset: chunk.offset);
      } on TransportException catch (e) {
        lastError = e;
        if (_isAuthFailure(e)) {
          throw WtrAiTranslateException(
            WtrAiFailureReason.auth,
            '${_providerLabel(client)} rejected the API key '
            '(HTTP ${e.statusCode ?? 'auth'}).',
            e,
          );
        }
        if (!_isRetryable(e) || attempt == maxAttempts) {
          throw WtrAiTranslateException(_classifyHttp(e), _describe(e), e);
        }
        await _sleep(_waitBeforeRetry(e, attempt));
      } on TimeoutException catch (e) {
        lastError = e;
        if (attempt == maxAttempts) {
          throw WtrAiTranslateException(
            WtrAiFailureReason.transient,
            'AI provider did not answer in time.',
            e,
          );
        }
        await _sleep(_backoffFor(attempt));
      }
    }
    // Unreachable: every branch above either returns or throws.
    throw WtrAiTranslateException(
      WtrAiFailureReason.transient,
      'AI translation failed after $maxAttempts attempts.',
      lastError,
    );
  }

  /// Groups paragraphs into chunks under [budgetChars] without ever
  /// splitting a paragraph across chunks (a lone oversized paragraph forms
  /// its own chunk). Returns chunks with their global paragraph offset so
  /// numbering stays unique across the entire chapter.
  List<NumberedChunk> chunk(List<String> paragraphs, {int budgetChars = 2500}) {
    final chunks = <NumberedChunk>[];
    var current = <String>[];
    var length = 0;
    var offset = 0;
    for (final p in paragraphs) {
      if (current.isNotEmpty && length + p.length > budgetChars) {
        chunks.add(NumberedChunk(offset: offset, paragraphs: current));
        offset += current.length;
        current = <String>[];
        length = 0;
      }
      current.add(p);
      length += p.length;
    }
    if (current.isNotEmpty) {
      chunks.add(NumberedChunk(offset: offset, paragraphs: current));
    }
    return chunks;
  }

  /// The instruction layer shared by all providers. Glossary rules are
  /// absolute so character/place names stay consistent with the site's own
  /// rendering and the rest of Atlas's glossary passes.
  String buildSystemPrompt(List<WtrGlossaryTerm> terms, String to) =>
      _systemPrompt(terms, to);

  String _systemPrompt(List<WtrGlossaryTerm> terms, String to) {
    final buffer = StringBuffer()
      ..writeln(
        'You are a professional literary translator specializing in '
        'Chinese web novels. Translate the user\'s numbered paragraphs '
        'into ${_languageName(to)}.',
      )
      ..writeln('Rules:')
      ..writeln(
        '- Output ONLY the translated paragraphs, each on its own line, '
        'prefixed with its original number tag like <1>. Keep every tag.',
      )
      ..writeln(
        '- Translate each paragraph separately: never merge, split, drop '
        'or reorder paragraphs.',
      )
      ..writeln('- Preserve meaning, tone and narrative voice.')
      ..writeln(
        '- Dialogue should read as natural spoken ${_languageName(to)}, '
        'matching the speaker\'s personality and the scene\'s tone '
        '(casual banter, teasing, slang). Prioritize how a native '
        'speaker would actually say the line over a literal rendering '
        'of the source phrasing.',
      )
      ..writeln(
        '- If a line is a joke, pun, or slangy exaggeration in the '
        'source, render it as an equivalently natural and funny line '
        'in the target language rather than a literal or '
        'clinical-sounding translation.',
      )
      ..writeln('- Glossary terms are mandatory renderings, not suggestions:');
    if (terms.isEmpty) {
      buffer.writeln('(none)');
    } else {
      for (final term in terms) {
        buffer.writeln('- ${term.zh} = ${term.en}');
      }
    }
    return buffer.toString().trimRight();
  }

  String _numbered(List<String> paragraphs, [int offset = 0]) => [
    for (var i = 0; i < paragraphs.length; i++) '<${offset + i + 1}>${paragraphs[i]}',
  ].join('\n');

  static final _tagLine = RegExp(r'^\s*<(\d+)>\s?(.*)$');

  /// Reverses [_numbered]. Fails unless exactly the expected tags come back,
  /// which is what makes silent corruption detectable.
  List<String> parseNumbered(String raw, {required int expectedCount, int offset = 0}) =>
      _parseNumbered(raw, expectedCount: expectedCount, offset: offset);

  List<String> _parseNumbered(String raw, {required int expectedCount, int offset = 0}) {
    final byIndex = <int, String>{};
    for (final line in raw.split('\n')) {
      final match = _tagLine.firstMatch(line.trim());
      if (match == null) continue;
      final index = int.tryParse(match.group(1)!);
      if (index == null || index < offset + 1 || index > offset + expectedCount) continue;
      byIndex[index - 1] = match.group(2)!.trim();
    }
    // Tags are unique and bounded to [offset+1, offset+count], so a full map
    // means every paragraph came back exactly once.
    if (byIndex.length != expectedCount) {
      throw WtrAiTranslateException(
        WtrAiFailureReason.badResponse,
        'AI returned ${byIndex.length} of $expectedCount paragraphs.',
      );
    }
    return [for (var i = 0; i < expectedCount; i++) byIndex[offset + i]!];
  }

  Future<void> _sleep(Duration duration) async {
    final delay = _delay;
    if (delay != null) {
      await delay(duration);
    } else {
      await Future<void>.delayed(duration);
    }
  }

  Duration _backoffFor(int attempt) => _baseBackoff * attempt;

  /// Honors a provider-declared `Retry-After` when it is short enough not to
  /// stall reading; otherwise (or when absent) falls back to linear backoff.
  Duration _waitBeforeRetry(TransportException e, int attempt) {
    final hinted = e.retryAfter;
    if (hinted != null && hinted <= _maxRetryAfter) return hinted;
    return _backoffFor(attempt);
  }

  static bool _isAuthFailure(TransportException e) =>
      e.statusCode == 401 || e.statusCode == 403;

  static bool _isRetryable(TransportException e) {
    final status = e.statusCode;
    // No status → network-level failure (DNS, socket, …): worth one more try.
    return status == null || status == 429 || status >= 500;
  }

  static WtrAiFailureReason _classifyHttp(TransportException e) {
    final status = e.statusCode;
    if (status == 429) return WtrAiFailureReason.rateLimited;
    if (status != null && status >= 500) return WtrAiFailureReason.rateLimited;
    if (status == null) return WtrAiFailureReason.transient;
    return WtrAiFailureReason.badResponse;
  }

  static String _describe(TransportException e) {
    final status = e.statusCode;
    if (status == 429) {
      final wait = e.retryAfter;
      return 'Rate limited by the AI provider'
          '${wait == null ? '' : ' (retry after ${wait.inSeconds}s)'}.';
    }
    if (status != null && status >= 500) {
      return 'AI provider error (HTTP $status).';
    }
    return e.message;
  }

  /// Best-effort display name for log lines; the exact provider is not worth
  /// threading through the whole call stack.
  static String _providerLabel(AiChatClient client) => switch (client) {
    GeminiAiClient() => 'Gemini',
    AnthropicAiClient() => 'Anthropic',
    _ => 'The AI provider',
  };

  static String _languageName(String tag) => switch (tag) {
    'en' => 'English',
    'es' => 'Spanish',
    'pt' => 'Portuguese',
    'fr' => 'French',
    'de' => 'German',
    'id' => 'Indonesian',
    'vi' => 'Vietnamese',
    'ru' => 'Russian',
    'tr' => 'Turkish',
    _ => tag,
  };
}

class NumberedChunk {
  const NumberedChunk({required this.offset, required this.paragraphs});

  final int offset;
  final List<String> paragraphs;
}