import 'package:flutter/material.dart';

class AppResponsiveLayout extends StatelessWidget {
  const AppResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return _widgetForWidth(width);
      },
    );
  }

  Widget _widgetForWidth(double width) {
    if (width >= 1200) return desktop ?? tablet ?? mobile;
    if (width >= 600) return tablet ?? mobile;
    return mobile;
  }
}

class AppAdaptive extends StatelessWidget {
  const AppAdaptive({
    super.key,
    required this.builder,
  });

  final Widget Function(BuildContext context, bool isWide) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        return builder(context, isWide);
      },
    );
  }
}
