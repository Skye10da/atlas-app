import 'package:flutter/material.dart';

extension SemanticsX on Widget {
  Widget withLabel(String label) {
    return Semantics(label: label, child: this);
  }

  Widget withButtonRole(String label) {
    return Semantics(label: label, button: true, enabled: true, child: this);
  }

  Widget withHeaderRole(String label) {
    return Semantics(label: label, header: true, child: this);
  }

  Widget withImageRole(String label) {
    return Semantics(label: label, image: true, child: this);
  }

  Widget withLiveRegion(String label) {
    return Semantics(label: label, liveRegion: true, child: this);
  }

  Widget excludeSemantics() {
    return Semantics(explicitChildNodes: true, child: this);
  }
}

extension KeyboardNavigationX on Widget {
  Widget withFocus(String label, {VoidCallback? onTap}) {
    return Focus(child: withLabel(label));
  }
}
