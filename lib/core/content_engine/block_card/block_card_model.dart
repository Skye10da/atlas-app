/// Core data model for novel "status window" block cards
/// (system/LitRPG status, cultivation status, quest, loot, etc).
///
/// This is presentation-agnostic — BlockCardTheme (reader presentation)
/// maps a BlockCard to actual widget decoration/typography.
library;

/// The genre/category of a detected status block. Add new values here
/// when a new template is needed; each type should have a matching
/// BlockCardTheme builder in the theme registry.
enum BlockCardType {
  system, // LitRPG-style system/status window
  cultivation, // xianxia/wuxia cultivation status
  quest, // quest/mission notification
  skillGain, // skill/ability acquired
  levelUp, // level-up notification
  inventory, // loot/item acquisition
  custom, // unrecognized but block-like text (renders as fallback)
}

/// How a single field's value should be rendered inside the card.
enum FieldDisplay {
  text, // plain "label: value" row
  bar, // progress bar, requires current/max
  tag, // pill/chip, usually grouped (skills, techniques)
  list, // multi-line bullet value
}

class BlockCardField {
  const BlockCardField({
    required this.label,
    required this.value,
    this.display = FieldDisplay.text,
    this.current,
    this.max,
  });

  factory BlockCardField.fromJson(Map<String, dynamic> json) {
    return BlockCardField(
      label: (json['label'] ?? '').toString(),
      value: (json['value'] ?? '').toString(),
      display: _displayFromString(json['display'] as String?),
      current: (json['current'] as num?)?.toDouble(),
      max: (json['max'] as num?)?.toDouble(),
    );
  }
  final String label;
  final String value;
  final FieldDisplay display;

  /// Only used when display == FieldDisplay.bar.
  final double? current;
  final double? max;

  double? get ratio => (current != null && max != null && max! > 0)
      ? (current! / max!).clamp(0, 1)
      : null;

  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    'display': display.name,
    if (current != null) 'current': current,
    if (max != null) 'max': max,
  };

  static FieldDisplay _displayFromString(String? s) {
    return FieldDisplay.values.firstWhere(
      (d) => d.name == s,
      orElse: () => FieldDisplay.text,
    );
  }
}

/// A single parsed status block, ready to be handed to a themed widget.
class BlockCard {
  const BlockCard({
    required this.type,
    required this.confidence,
    required this.rawText,
    this.title,
    this.subtitle,
    this.fields = const [],
    this.tags = const [],
    this.footnote,
  });

  /// Used when detection fired (something block-shaped was found) but
  /// no rule or AI extractor could parse it into fields.
  factory BlockCard.fallback(String rawText) =>
      BlockCard(type: BlockCardType.custom, confidence: 0, rawText: rawText);

  factory BlockCard.fromJson(
    Map<String, dynamic> json, {
    required String rawText,
  }) {
    final isBlock = json['is_block'];
    if (isBlock == false) {
      return BlockCard.fallback(rawText);
    }
    return BlockCard(
      type: _typeFromString(json['type'] as String?),
      title: json['title'] as String?,
      subtitle: json['subtitle'] as String?,
      fields: ((json['fields'] as List?) ?? const [])
          .map(
            (f) => BlockCardField.fromJson(Map<String, dynamic>.from(f as Map)),
          )
          .toList(),
      tags: ((json['tags'] as List?) ?? const [])
          .map((t) => t.toString())
          .toList(),
      footnote: json['footnote'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      rawText: rawText,
    );
  }
  final BlockCardType type;
  final String? title;
  final String? subtitle;
  final List<BlockCardField> fields;
  final List<String> tags;
  final String? footnote;

  /// 0.0–1.0. Set by the detector (regex confidence) or the local-AI
  /// extractor (self-reported confidence). Below the low-confidence
  /// threshold, the reader should render the fallback template instead
  /// of trusting the parsed fields.
  final double confidence;

  /// Original chapter text this card was parsed from — always kept so
  /// the fallback template has something to show, and so parsing bugs
  /// are recoverable/debuggable from the rendered chapter.
  final String rawText;

  static const double lowConfidenceThreshold = 0.55;

  bool get isLowConfidence => confidence < lowConfidenceThreshold;

  static BlockCardType _typeFromString(String? s) {
    return BlockCardType.values.firstWhere(
      (t) => t.name == s,
      orElse: () => BlockCardType.custom,
    );
  }
}

/// A chunk of chapter content after block-card scanning: either plain
/// prose to render normally, or a detected card to render specially.
/// Keeping order preserved lets the reader interleave cards inline
/// with surrounding paragraphs.
class ContentSpan {
  const ContentSpan.prose(this.prose) : isCard = false, card = null;

  const ContentSpan.card(this.card) : isCard = true, prose = null;
  final bool isCard;
  final String? prose;
  final BlockCard? card;
}
