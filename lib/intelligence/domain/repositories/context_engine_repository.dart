import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/intelligence/domain/entities/context_package.dart';
import 'package:atlas_app/intelligence/domain/entities/reader_position.dart';

/// Contract for assembling layered, spoiler-free prompt context.
abstract interface class ContextEngineRepository {
  /// Builds a [ContextPackage] anchored to [position], pruned for [taskFilter],
  /// and truncated to fit within [maxTokens].
  Future<Result<ContextPackage>> buildContext({
    required ReaderPosition position,
    String? taskFilter,
    int? maxTokens,
  });
}

