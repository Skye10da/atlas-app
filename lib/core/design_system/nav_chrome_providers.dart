import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which navigation chrome the shell renders.
enum NavChromeStyle {
  /// Liquid-glass capsule barra / dock (new default).
  glass,

  /// Pre-v3 Material chrome (solid bottom bar / rail / sidebar).
  classic,
}

extension NavChromeStyleX on NavChromeStyle {
  String get key => switch (this) {
        NavChromeStyle.glass => 'glass',
        NavChromeStyle.classic => 'classic',
      };

  static NavChromeStyle fromKey(String? key) =>
      key == 'classic' ? NavChromeStyle.classic : NavChromeStyle.glass;
}

/// Persisted navigation-chrome preference.
///
/// Loads through [SharedPreferences.getInstance] — already warm before the
/// first frame on a cold start (main.dart pre-warms it lazily), so the
/// mirrored [valueOrNull ?? default] pattern of the reading settings applies:
/// the glass capsule is the initial value for one frame at most.
class NavChromeNotifier extends Notifier<NavChromeStyle> {
  static const _prefKey = 'nav_chrome_style';

  @override
  NavChromeStyle build() {
    _load();
    return NavChromeStyle.glass;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = NavChromeStyleX.fromKey(prefs.getString(_prefKey));
    if (loaded != state) state = loaded;
  }

  Future<void> set(NavChromeStyle style) async {
    state = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, style.key);
  }
}

final navChromeProvider =
    NotifierProvider<NavChromeNotifier, NavChromeStyle>(NavChromeNotifier.new);
