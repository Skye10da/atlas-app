import 'package:atlas_app/core/content_engine/transport/transport.dart';

/// One remote AI chat API, reduced to what translation needs: a single
/// system+user completion and a model listing.
///
/// Implementations live in `lib/wtr/infrastructure/services/`. All network
/// access goes through [Transport] so tests can fake it.
abstract interface class AiChatClient {
  /// Runs one completion with [system] as the instruction layer and
  /// [prompt] as the user turn, returning the assistant's text.
  ///
  /// Throws [TransportException] on HTTP errors (with `statusCode` /
  /// `retryAfter` where available), or a bare exception on malformed
  /// responses.
  Future<String> complete(
    Transport transport, {
    required String apiKey,
    required String model,
    required String system,
    required String prompt,
  });

  /// The model IDs the provider currently offers for chat completions.
  /// Best-effort: implementations filter obvious non-chat models but do not
  /// guarantee every returned ID is usable.
  Future<List<String>> listModels(
    Transport transport, {
    required String apiKey,
  });
}
