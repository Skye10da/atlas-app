import 'dart:convert';

/// Avatar colour palette for local accounts. Stored by index in
/// [LocalAccountEntity.avatarColorIndex] so re-ordering this list never
/// corrupts a saved profile.
const List<int> kAvatarColors = [
  0xFF2F5D50, // Atlas green (default)
  0xFFB5532A, // terracotta
  0xFF4F46E5, // indigo
  0xFF0EA5E9, // sky
  0xFF8B5CF6, // violet
  0xFFF59E0B, // amber
  0xFF10B981, // emerald
  0xFFEF4444, // ruby
];

/// A purely local, offline account used to personalise the UI (greeting,
/// avatar). There is no authentication and nothing leaves the device.
class LocalAccountEntity {
  const LocalAccountEntity({
    this.displayName = 'Reader',
    this.avatarColorIndex = 0,
    this.createdAt,
  });

  final String displayName;

  /// Index into [kAvatarColors].
  final int avatarColorIndex;

  final DateTime? createdAt;

  /// Single uppercase letter shown in the avatar circle.
  String get avatarInitial {
    final trimmed = displayName.trim();
    return trimmed.isEmpty ? 'R' : trimmed.substring(0, 1).toUpperCase();
  }

  /// First name / short label for greetings.
  String get greetingName {
    final first = displayName.trim().split(RegExp(r'\s+')).first;
    return first.isEmpty ? 'Reader' : first;
  }

  LocalAccountEntity copyWith({
    String? displayName,
    int? avatarColorIndex,
    DateTime? createdAt,
  }) {
    return LocalAccountEntity(
      displayName: displayName ?? this.displayName,
      avatarColorIndex: avatarColorIndex ?? this.avatarColorIndex,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'displayName': displayName,
    'avatarColorIndex': avatarColorIndex,
    'createdAt': createdAt?.toIso8601String(),
  };

  static LocalAccountEntity fromJson(Map<String, dynamic> json) {
    final rawName = (json['displayName'] as String?)?.trim();
    return LocalAccountEntity(
      displayName: (rawName == null || rawName.isEmpty) ? 'Reader' : rawName,
      avatarColorIndex: (json['avatarColorIndex'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }

  String encode() => jsonEncode(toJson());

  static LocalAccountEntity decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return fromJson(decoded);
    } catch (_) {
      // Corrupt payload — fall back to the default account.
    }
    return const LocalAccountEntity();
  }
}
