import 'package:flutter/animation.dart';

abstract final class AppAnimation {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);

  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve fastOutSlowIn = Curves.fastOutSlowIn;

  static const pageTransition = PageTransition(
    curve: Curves.easeInOut,
    duration: Duration(milliseconds: 300),
  );
}

class PageTransition {
  const PageTransition({required this.curve, required this.duration});

  final Curve curve;
  final Duration duration;

  Tween<Offset> slideOffset({bool forward = true}) {
    return Tween<Offset>(
      begin: forward ? const Offset(0.1, 0) : const Offset(-0.1, 0),
      end: Offset.zero,
    );
  }
}
