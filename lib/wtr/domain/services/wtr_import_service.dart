import 'package:atlas_app/wtr/domain/entities/wtr_novel_identity.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_translation_service.dart';
import 'package:atlas_app/wtr/domain/services/wtr_chapter_provider.dart';

/// Pins a WTR-Lab novel's translation service from the `?service=` query param
/// on an imported URL.
///
/// An explicit `?service=web` / `?service=webplus` (or `?service=ai`) on the
/// URL is authoritative for that novel; a missing param means the site's
/// account-dependent default applies, so nothing is persisted. The generic
/// import engine (which must not depend on WTR internals) calls this once per
/// freshly imported book.
Future<void> applyWtrServiceFromImportedUrl(
  String importUrl, {
  required String sourceId,
  required String sourceUrl,
  required String sourceName,
}) async {
  final requested = WtrTranslationService.fromQueryParam(
    Uri.tryParse(importUrl)?.queryParameters['service'],
  );
  if (requested == null) return;
  if (!isWtrLabSource(sourceUrl: sourceUrl, sourceName: sourceName)) return;
  final rawId = wtrRawIdOf(sourceId: sourceId, sourceUrl: sourceUrl);
  if (rawId == null) return;
  await WtrChapterProvider.instance.setService(rawId, requested);
}
