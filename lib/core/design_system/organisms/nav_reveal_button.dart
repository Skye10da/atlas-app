// Small frosted "bead" that stands in for hidden navigation chrome.
//
// When the nav pill/rail auto-hides while scrolling, this compact glass
// button appears in its place; tapping it reveals the bar again. It reads
// as the collapsed bar's settings bead — same liquid-glass language as the
// chrome it replaces (GlassCapsule, blur 18 per the pills-over-content
// convention).

import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/molecules/glass_surfaces.dart';

class NavRevealButton extends StatelessWidget {
  const NavRevealButton({
    super.key,
    required this.onTap,
    this.icon = Icons.tune_rounded,
    this.tooltip = 'Show navigation',
  });

  final VoidCallback onTap;
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: GlassCapsule(
          pill: true,
          blur: 18,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(icon, size: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Narration-active variant of the reveal bead: one horizontal glass pill
/// carrying the reveal bead plus mini transport controls (play/pause, stop),
/// so a scroll-hidden docked player stays controllable without being
/// revealed. Same liquid-glass language and 44px bead rhythm as
/// [NavRevealButton].
class NavRevealCluster extends StatelessWidget {
  const NavRevealCluster({
    super.key,
    required this.playing,
    required this.onReveal,
    required this.onToggle,
    required this.onStop,
  });

  /// True while narration is playing (pause icon shown); false while
  /// paused (play icon shown).
  final bool playing;
  final VoidCallback onReveal;
  final VoidCallback onToggle;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassCapsule(
      pill: true,
      blur: 18,
      child: Material(
        type: MaterialType.transparency,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _bead(
              context,
              icon: Icons.tune_rounded,
              tooltip: 'Show player',
              onTap: onReveal,
            ),
            _bead(
              context,
              icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              tooltip: playing ? 'Pause narration' : 'Resume narration',
              onTap: onToggle,
              color: colorScheme.primary,
            ),
            _bead(
              context,
              icon: Icons.stop_rounded,
              tooltip: 'Stop narration',
              onTap: onStop,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _bead(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 22, color: color),
          ),
        ),
      ),
    );
  }
}
