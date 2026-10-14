import 'package:drift/drift.dart';

/// Stores element fingerprints for self-healing selectors.
/// Keyed by plugin_id + role (e.g., 'chapterContent.container', 'chapterList.item').
class SelectorFingerprints extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Plugin identifier (e.g., 'noveldrama', 'royalroad')
  TextColumn get pluginId => text()();

  /// Selector role: 'chapterContent.container', 'chapterList.item', 'chapterList.container', 'metadata.title', etc.
  TextColumn get role => text()();

  /// The selector string that succeeded
  TextColumn get selectorSpec => text()();

  /// Element tag name (e.g., 'div', 'section', 'article')
  TextColumn get tag => text()();

  /// JSON-encoded attributes map (e.g., {"id": "chr-content", "class": "chr-c"})
  TextColumn get attributesJson => text()();

  /// Hash of first 200 chars of text content (xxhash64 as hex string)
  TextColumn get textHash => text().nullable()();

  /// Parent element tag name
  TextColumn get parentTag => text().nullable()();

  /// JSON array of sibling element tags (e.g., ["hr", "div", "div"])
  TextColumn get siblingTagsJson => text()();

  /// Tree depth from root
  IntColumn get depth => integer()();

  /// JSON array of tag path from root to element (e.g., ["html", "body", "div", "div", "div"])
  TextColumn get pathTagsJson => text()();

  /// Unix timestamp (ms) when fingerprint was captured
  IntColumn get capturedAt => integer()();

  /// Number of successful matches with this fingerprint
  IntColumn get successCount => integer().withDefault(const Constant(1))();

  /// Unix timestamp (ms) of last healing using this fingerprint
  IntColumn get lastHealedAt => integer().nullable()();

  /// Confidence of last healing
  RealColumn get lastHealedConfidence => real().nullable()();

  @override
  Set<Column> get primaryKey => {pluginId, role};
}

/// Records of healed selectors for review queue and analytics.
class HealingRecords extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Plugin identifier
  TextColumn get pluginId => text()();

  /// Selector role
  TextColumn get role => text()();

  /// The original selector that failed
  TextColumn get originalSelector => text()();

  /// The generated/healed selector that worked
  TextColumn get healedSelector => text()();

  /// Confidence score (0.0 - 1.0)
  RealColumn get confidence => real()();

  /// Unix timestamp (ms) when healing occurred
  IntColumn get healedAt => integer()();

  /// User confirmation status: 0=pending, 1=confirmed, -1=rejected
  IntColumn get userConfirmed => integer().withDefault(const Constant(0))();

  /// Optional: user who confirmed/rejected (for multi-user sync later)
  TextColumn get confirmedBy => text().nullable()();

  /// Optional: notes from reviewer
  TextColumn get reviewNotes => text().nullable()();
}