import 'dart:convert';

import 'package:html/dom.dart';
import 'package:drift/drift.dart';

import 'package:atlas_app/core/database/database.dart';

/// Helper to create drift Variables with explicit type
Variable<String> _v(String value) => Variable<String>(value);

/// Fingerprint of an element used for self-healing selector matching.
class ElementFingerprint {
  const ElementFingerprint({
    required this.tag,
    required this.attributes,
    this.textHash,
    this.parentTag,
    this.siblingTags = const [],
    this.depth = 0,
    this.pathTags = const [],
  });

  final String tag;
  final Map<String, String> attributes;
  final String? textHash;
  final String? parentTag;
  final List<String> siblingTags;
  final int depth;
  final List<String> pathTags;

  /// Creates a fingerprint from a live DOM element.
  static ElementFingerprint fromElement(Element element) {
    final attributes = element.attributes
        .map((key, value) => MapEntry(key.toString(), value.toString()));

    final parent = element.parent;

    final siblings = <String>[];
    if (parent is Element) {
      for (final node in parent.nodes) {
        if (node is Element && node != element) {
          siblings.add(node.localName!);
        }
      }
    }

    final path = <String>[];
    int depth = 0;
    Element? current = element;
    while (current != null) {
      path.insert(0, current.localName!);
      depth++;
      current = current.parent;
    }

    return ElementFingerprint(
      tag: element.localName!,
      attributes: attributes,
      textHash: _hashText(element.text),
      parentTag: parent is Element ? parent.localName! : null,
      siblingTags: siblings,
      depth: depth - 1,
      pathTags: path,
    );
  }

  /// Computes similarity score against a candidate element (0.0 - 1.0).
  /// Based on Scrapling's approach: tag match + attribute Jaccard + parent/sibling + depth + text hash.
  double scoreAgainst(Element candidate) {
    double score = 0.0;
    int factors = 0;

    // 1. Tag match (weight: 0.30)
    final candTag = candidate.localName!;
    if (candTag.toLowerCase() == tag.toLowerCase()) {
      score += 0.30;
    }
    factors++;

    // 2. Attributes Jaccard similarity (weight: 0.25)
    final candAttrs = candidate.attributes.map((key, value) => MapEntry(key as String, value.toString()));
    if (attributes.isNotEmpty || candAttrs.isNotEmpty) {
      final intersection = attributes.keys.where(candAttrs.containsKey).length;
      final union = attributes.keys.toSet().union(candAttrs.keys.toSet()).length;
      if (union > 0) {
        score += 0.25 * (intersection / union);
      }
    }
    factors++;

    // 3. Parent tag match (weight: 0.15)
    final candParent = candidate.parent;
    if (parentTag != null && candParent is Element) {
      if (candParent.localName!.toLowerCase() == parentTag!.toLowerCase()) {
        score += 0.15;
      }
    }
    factors++;

    // 4. Sibling tags overlap (weight: 0.15)
    if (siblingTags.isNotEmpty) {
      final candSiblings = <String>[];
      if (candParent is Element) {
        for (final node in candParent.nodes) {
          if (node is Element && node != candidate) {
            candSiblings.add(node.localName!);
          }
        }
      }
      final overlap = siblingTags.where(candSiblings.contains).length;
      final total = siblingTags.toSet().union(candSiblings.toSet()).length;
      if (total > 0) {
        score += 0.15 * (overlap / total);
      }
    }
    factors++;

    // 5. Depth delta (weight: 0.10) - closer is better
    final candDepth = _computeDepth(candidate);
    final depthDelta = (depth - candDepth).abs();
    if (depthDelta <= 2) {
      score += 0.10 * (1.0 - depthDelta / 3.0);
    }
    factors++;

    // 6. Text hash match (weight: 0.05) - only if both have text
    if (textHash != null) {
      final candHash = _hashText(candidate.text);
      if (candHash == textHash) {
        score += 0.05;
      }
    }
    factors++;

    return score / factors;
  }

  int _computeDepth(Element element) {
    int depth = 0;
    Element? current = element;
    while (current != null) {
      depth++;
      current = current.parent;
    }
    return depth - 1;
  }

  static String? _hashText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    // Use first 200 chars for hash
    final sample = trimmed.length > 200 ? trimmed.substring(0, 200) : trimmed;
    // Simple xxhash-like hash
    int hash = 5381;
    for (int i = 0; i < sample.length; i++) {
      hash = ((hash << 5) + hash) + sample.codeUnitAt(i);
    }
    return hash.toRadixString(16);
  }

  /// Serializes to JSON for storage.
  Map<String, Object?> toJson() => {
    'tag': tag,
    'attributes': attributes,
    'textHash': textHash,
    'parentTag': parentTag,
    'siblingTags': siblingTags,
    'depth': depth,
    'pathTags': pathTags,
  };

  static ElementFingerprint fromJson(Map<String, Object?> json) => ElementFingerprint(
    tag: json['tag'] as String,
    attributes: (json['attributes'] as Map<String, Object?>)
        .map((k, v) => MapEntry(k, v as String)),
    textHash: json['textHash'] as String?,
    parentTag: json['parentTag'] as String?,
    siblingTags: (json['siblingTags'] as List).cast<String>(),
    depth: json['depth'] as int,
    pathTags: (json['pathTags'] as List).cast<String>(),
  );
}

/// Result of a healing attempt.
class HealingResult {

  factory HealingResult.failure() => const HealingResult(
    element: null,
    confidence: 0.0,
    healed: false,
  );

  factory HealingResult.success({
    required Element element,
    required double confidence,
    required String generatedSelector,
    required ElementFingerprint fingerprint,
  }) => HealingResult(
    element: element,
    confidence: confidence,
    healed: true,
    generatedSelector: generatedSelector,
    fingerprint: fingerprint,
  );
  const HealingResult({
    this.element,
    required this.confidence,
    required this.healed,
    this.generatedSelector,
    this.fingerprint,
  });

  final Element? element;
  final double confidence;
  final bool healed;
  final String? generatedSelector;
  final ElementFingerprint? fingerprint;
}

/// Healing engine for self-healing selectors.
/// Uses raw SQL queries to avoid requiring drift generated code.
class HealingEngine {
  HealingEngine(this.db);

  final AppDatabase db;
  static const double healThreshold = 0.85;
  static const int minTextLength = 200;
  static const double minParagraphRatio = 0.3;
  static const double maxLinkDensity = 0.5;

  /// Attempts to heal a selector miss by finding the best matching element.
  Future<HealingResult> tryHeal(
    Document doc,
    String pluginId,
    String role,
    String selectorSpec,
  ) async {
    // 1. Try exact selector first
    final exact = doc.querySelector(selectorSpec);
    if (exact != null) {
      await _updateFingerprint(pluginId, role, selectorSpec, exact);
      return HealingResult.success(
        element: exact,
        confidence: 1.0,
        generatedSelector: selectorSpec,
        fingerprint: ElementFingerprint.fromElement(exact),
      );
    }

    // 2. Load stored fingerprint
    final fp = await _getFingerprint(pluginId, role);
    if (fp == null) {
      return HealingResult.failure();
    }

    // 3. Score all candidate elements
    final candidates = _scoreAllCandidates(doc, fp);
    final best = candidates.firstWhereOrNull((c) => c.score >= HealingEngine.healThreshold);

    if (best != null && _passesSanityChecks(best.element)) {
      final generated = _generateSelector(best.element);
      await _recordHealing(pluginId, role, selectorSpec, generated, best.score, best.element);
      return HealingResult.success(
        element: best.element,
        confidence: best.score,
        generatedSelector: generated,
        fingerprint: fp,
      );
    }

    return HealingResult.failure();
  }

  List<_ScoredCandidate> _scoreAllCandidates(Document doc, ElementFingerprint fingerprint) {
    final candidates = <_ScoredCandidate>[];
    final allElements = doc.querySelectorAll('*');
    
    for (final el in allElements) {
      final score = fingerprint.scoreAgainst(el);
      if (score > 0.3) { // Only consider reasonably similar elements
        candidates.add(_ScoredCandidate(element: el, score: score));
      }
    }
    
    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates;
  }

  bool _passesSanityChecks(Element el) {
    final text = el.text.trim();
    if (text.length < HealingEngine.minTextLength) return false;

    final paraCount = el.querySelectorAll('p').length;
    final nodeCount = el.querySelectorAll('*').length + 1;
    if (paraCount / nodeCount < HealingEngine.minParagraphRatio) return false;

    final linkText = el.querySelectorAll('a').fold<int>(0, (sum, a) => sum + a.text.length);
    if (linkText / text.length > HealingEngine.maxLinkDensity) return false;

    return true;
  }

  String _generateSelector(Element el) {
    // Generate a robust CSS selector for the healed element
    final parts = <String>[];
    Element? current = el;

    while (current != null) {
      String part = current.localName!;

      // Add ID if present
      final id = current.id;
      if (id.isNotEmpty) {
        part = '#$id';
        parts.insert(0, part);
        break;
      }

      // Add classes
      final classes = current.classes.where((c) => c.isNotEmpty).toList();
      if (classes.isNotEmpty) {
        part = '.${classes.first}';
      }

      // Add nth-child if needed for uniqueness
      final parent = current.parent;
      if (parent is Element) {
        final siblings = parent.children
            .where((c) => c.localName == current?.localName)
            .toList();
        if (siblings.length > 1) {
          final index = siblings.indexOf(current) + 1;
          part += ':nth-of-type($index)';
        }
      }

      parts.insert(0, part);
      current = parent;
    }

    return parts.join(' > ');
  }

  Future<ElementFingerprint?> _getFingerprint(String pluginId, String role) async {
    final rows = await db.customSelect(
      'SELECT * FROM selector_fingerprints WHERE plugin_id = ? AND role = ?',
      variables: [_v(pluginId), _v(role)],
    ).get();
    
    if (rows.isEmpty) return null;
    
    final row = rows.first.data;
    return ElementFingerprint(
      tag: row['tag'] as String,
      attributes: jsonDecode(row['attributes_json'] as String) as Map<String, String>,
      textHash: row['text_hash'] as String?,
      parentTag: row['parent_tag'] as String?,
      siblingTags: jsonDecode(row['sibling_tags_json'] as String) as List<String>,
      depth: row['depth'] as int,
      pathTags: jsonDecode(row['path_tags_json'] as String) as List<String>,
    );
  }

  Future<void> _updateFingerprint(
    String pluginId,
    String role,
    String selectorSpec,
    Element element,
  ) async {
    final fingerprint = ElementFingerprint.fromElement(element);
    
    await db.customStatement(
      '''
      INSERT OR REPLACE INTO selector_fingerprints (
        plugin_id, role, selector_spec, tag, attributes_json, text_hash,
        parent_tag, sibling_tags_json, depth, path_tags_json,
        captured_at, success_count
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 
        COALESCE((SELECT success_count FROM selector_fingerprints WHERE plugin_id = ? AND role = ?), 0) + 1)
      ''',
      [
        pluginId,
        role,
        selectorSpec,
        fingerprint.tag,
        jsonEncode(fingerprint.attributes),
        fingerprint.textHash,
        fingerprint.parentTag,
        jsonEncode(fingerprint.siblingTags),
        fingerprint.depth,
        jsonEncode(fingerprint.pathTags),
        DateTime.now().millisecondsSinceEpoch,
        pluginId,
        role,
      ],
    );
  }

  Future<void> _recordHealing(
    String pluginId,
    String role,
    String originalSelector,
    String healedSelector,
    double confidence,
    Element element,
  ) async {
    await db.customStatement(
      '''
      INSERT INTO healing_records (
        plugin_id, role, original_selector, healed_selector, confidence, healed_at
      ) VALUES (?, ?, ?, ?, ?, ?)
      ''',
      [
        pluginId,
        role,
        originalSelector,
        healedSelector,
        confidence,
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }
}

class _ScoredCandidate {
  const _ScoredCandidate({required this.element, required this.score});
  final Element element;
  final double score;
}

/// Extension to add firstWhereOrNull to List
extension _ListExtensions<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}