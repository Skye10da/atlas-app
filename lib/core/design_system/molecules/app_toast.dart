// Atlas in-app notifications: one glass droplet pill at the top of the screen.
//
// Replaces every Material SnackBar in the app. A notification is a [GlassCapsule]
// pill that "falls" into place from above with the house liquid-glass spring
// (small liquid overshoot), carries an emoticon matching what the action does,
// and lifts away with a quick fade — like a droplet reversing off the glass.
//
// Built on the shared glass primitives — never hand-rolled glass
// (atlas-glass-ui skill rules).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'package:atlas_app/core/design_system/molecules/glass_surfaces.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';

/// Semantic category of a notification: picks the tone's emoticon (and tint,
/// for error/warning) so the pill explains what just happened at a glance.
enum AppToastTone {
  info('💡'),
  success('✅'),
  error('⛔'),
  warning('⚠️'),
  download('⬇️'),
  read('📖'),
  bookmark('🔖'),
  sparkle('✨'),
  search('🔍'),
  narration('🎙️'),
  backup('💾');

  const AppToastTone(this.emoji);

  final String emoji;
}

/// Optional trailing verb on a toast pill (replacement for [SnackBarAction]).
class AppToastAction {
  const AppToastAction(this.label, this.onPressed);

  final String label;
  final VoidCallback onPressed;
}

/// Root-level toast pill display, mounted on the root navigator's overlay.
///
/// Static API mirrors the [SnackBar] helper it replaces: calls from anywhere
/// (providers, after awaits) survive provider invalidations and navigation
/// because the pill lives on the root overlay, not on any screen's Scaffold.
///
/// [bind] once at startup (main.dart) with the router's root navigator key;
/// without a binding the calls are silently dropped, exactly like the old
/// null-guarded messenger path.
class AppToast {
  AppToast._();

  static GlobalKey<NavigatorState>? _rootKey;
  static OverlayEntry? _entry;
  static bool _removing = false;

  /// Point the toast host at the app's root navigator overlay.
  static void bind(GlobalKey<NavigatorState> rootNavigatorKey) {
    _rootKey = rootNavigatorKey;
  }

  /// Dimiss the current pill, if any.
  static void dismiss() {
    _removeEntry();
  }

  static void show(
    String message, {
    AppToastTone tone = AppToastTone.info,
    String? emoji,
    AppToastAction? action,
    Duration duration = const Duration(seconds: 4),
  }) {
    final overlay = _rootKey?.currentState?.overlay;
    if (overlay == null) return;

    // Old behavior parity: a rapid next message replaces the current pill
    // instead of stacking (the snackbar's hideCurrentSnackBar + show).
    _removeEntry();

    final entry = OverlayEntry(
      builder: (_) => _ToastEntry(
        message: message,
        tone: tone,
        emoji: emoji,
        action: action,
        duration: duration,
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  static void showError(
    String message, {
    String? emoji,
    AppToastAction? action,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      message,
      tone: AppToastTone.error,
      emoji: emoji,
      action: action,
      duration: duration,
    );
  }

  static void showSuccess(
    String message, {
    String? emoji,
    AppToastAction? action,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      message,
      tone: AppToastTone.success,
      emoji: emoji,
      action: action,
      duration: duration,
    );
  }

  static void _removeEntry() {
    final entry = _entry;
    if (entry == null) return;
    _entry = null;
    if (_removing) return;
    _removing = true;
    // remove() while inside another entry's builder would throw; a microtask
    // defers it safely.
    scheduleMicrotask(() {
      entry.remove();
      _removing = false;
    });
  }
}

class _ToastEntry extends StatefulWidget {
  const _ToastEntry({
    required this.message,
    required this.tone,
    this.emoji,
    this.action,
    required this.duration,
  });

  final String message;
  final AppToastTone tone;
  final String? emoji;
  final AppToastAction? action;
  final Duration duration;

  @override
  State<_ToastEntry> createState() => _ToastEntryState();
}

class _ToastEntryState extends State<_ToastEntry> with TickerProviderStateMixin {
  // The house liquid glass spring: underdamped so the droplet lands with a
  // small visible overshoot (metrology from atlas-glass-ui — do not re-tune).
  static const SpringDescription _spring = SpringDescription(
    mass: 1,
    stiffness: 220,
    damping: 18,
  );

  // Entry drops from above: 1 (fully above screen) → 0 (landed). Negative
  // values during overshoot = a slight dip below the resting point.
  late final AnimationController _entryCtrl;

  // Exit: 0 → 1 fade lift-away in 180ms.
  late final AnimationController _exitCtrl;
  Timer? _timer;
  bool _dismissing = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController.unbounded(vsync: this);
    _exitCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (MediaQuery.disableAnimationsOf(context)) {
      _entryCtrl.value = 0; // land instantly
    } else {
      _entryCtrl.value = 1;
      _entryCtrl.animateWith(SpringSimulation(_spring, 1, 0, 0));
    }
    _armTimer();
  }

  void _armTimer() {
    _timer?.cancel();
    _timer = Timer(widget.duration, _dismiss);
  }

  void _dismiss() {
    if (_dismissing) return;
    _dismissing = true;
    _timer?.cancel();

    if (MediaQuery.disableAnimationsOf(context)) {
      AppToast._removeEntry();
      return;
    }
    _exitCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) AppToast._removeEntry();
    });
    _exitCtrl.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _entryCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    final Color? fill = switch (widget.tone) {
      AppToastTone.error => cs.error.withValues(alpha: isDark ? 0.45 : 0.30),
      AppToastTone.warning => cs.error.withValues(alpha: isDark ? 0.32 : 0.22),
      _ => null, // default twin-gradient glass for the rest
    };

    final emoji = widget.emoji ?? widget.tone.emoji;

    return AnimatedBuilder(
      animation: Listenable.merge([_entryCtrl, _exitCtrl]),
      builder: (context, _) {
        final entry = _entryCtrl.value.clamp(-1.5, 3.0);
        final exit = _exitCtrl.value;

        final opacity = (1 - entry).clamp(0.0, 1.0) * (1 - exit);
        final offsetY = -entry * 72.0 - exit * 10.0;
        final scale = (1 - exit * 0.04).clamp(0.5, 2.0);

        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + AppSpacing.smMd,
              left: AppSpacing.md,
              right: AppSpacing.md,
            ),
            child: Transform.translate(
              offset: Offset(0, offsetY),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Semantics(
                    liveRegion: true,
                    child: Material(
                      type: MaterialType.transparency,
                      // Only the pill is interactive; the Align leaves the
                      // rest of the strip permanently un-hit-testable.
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _dismiss,
                        child: GlassCapsule(
                          pill: true,
                          blur: 18,
                          fill: fill,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: IntrinsicWidth(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // The emoticon pops as the droplet lands:
                                    // small while falling, full size at rest,
                                    // slight pop on the spring overshoot.
                                    Transform.scale(
                                      scale: (1 - entry * 0.25).clamp(0.4, 1.6),
                                      child: Text(
                                        emoji,
                                        style: const TextStyle(fontSize: 18),
                                        textScaler: const TextScaler.linear(1),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Flexible(
                                      child: Text(
                                        widget.message,
                                        softWrap: true,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(color: cs.onSurface),
                                      ),
                                    ),
                                    if (widget.action != null) ...[
                                      const SizedBox(width: AppSpacing.sm),
                                      TextButton(
                                        onPressed: () {
                                          _dismiss();
                                          widget.action!.onPressed();
                                        },
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          minimumSize: Size.zero,
                                        ),
                                        child: Text(widget.action!.label),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

