import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/core/design_system/tokens/breakpoints.dart';

void main() {
  group('AppBreakpoints constants', () {
    test('standard breakpoint thresholds are well-formed', () {
      expect(AppBreakpoints.mobile, equals(600));
      expect(AppBreakpoints.tablet, equals(900));
      expect(AppBreakpoints.desktop, equals(900));
      expect(AppBreakpoints.largeDesktop, equals(1200));

      expect(AppBreakpoints.readerContentMaxWidth, equals(840.0));
      expect(AppBreakpoints.formContentMaxWidth, equals(760.0));
      expect(AppBreakpoints.sheetMaxWidth, equals(640.0));
    });
  });

  group('AppBreakpoints window queries', () {
    Future<void> pumpWithSize(
      WidgetTester tester,
      Size size,
      void Function(BuildContext context) callback,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                callback(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    }

    testWidgets('compact phone size (< 600dp)', (tester) async {
      await pumpWithSize(tester, const Size(400, 800), (context) {
        expect(AppBreakpoints.isCompact(context), isTrue);
        expect(AppBreakpoints.isMobile(context), isTrue);
        expect(AppBreakpoints.isMedium(context), isFalse);
        expect(AppBreakpoints.isTablet(context), isFalse);
        expect(AppBreakpoints.isExpanded(context), isFalse);
        expect(AppBreakpoints.isDesktop(context), isFalse);
        expect(AppBreakpoints.isLarge(context), isFalse);
        expect(AppBreakpoints.isWide(context), isFalse);
      });
    });

    testWidgets('medium tablet size (600dp - 899dp)', (tester) async {
      await pumpWithSize(tester, const Size(768, 1024), (context) {
        expect(AppBreakpoints.isCompact(context), isFalse);
        expect(AppBreakpoints.isMobile(context), isFalse);
        expect(AppBreakpoints.isMedium(context), isTrue);
        expect(AppBreakpoints.isTablet(context), isTrue);
        expect(AppBreakpoints.isExpanded(context), isFalse);
        expect(AppBreakpoints.isDesktop(context), isFalse);
        expect(AppBreakpoints.isLarge(context), isFalse);
        expect(AppBreakpoints.isWide(context), isFalse);
      });
    });

    testWidgets('expanded desktop size (900dp - 1199dp)', (tester) async {
      await pumpWithSize(tester, const Size(1000, 800), (context) {
        expect(AppBreakpoints.isCompact(context), isFalse);
        expect(AppBreakpoints.isMobile(context), isFalse);
        expect(AppBreakpoints.isMedium(context), isFalse);
        expect(AppBreakpoints.isTablet(context), isFalse);
        expect(AppBreakpoints.isExpanded(context), isTrue);
        expect(AppBreakpoints.isDesktop(context), isTrue);
        expect(AppBreakpoints.isLarge(context), isFalse);
        expect(AppBreakpoints.isWide(context), isTrue);
      });
    });

    testWidgets('large ultrawide size (>= 1200dp)', (tester) async {
      await pumpWithSize(tester, const Size(1920, 1080), (context) {
        expect(AppBreakpoints.isCompact(context), isFalse);
        expect(AppBreakpoints.isMobile(context), isFalse);
        expect(AppBreakpoints.isMedium(context), isFalse);
        expect(AppBreakpoints.isTablet(context), isFalse);
        expect(AppBreakpoints.isExpanded(context), isFalse);
        expect(AppBreakpoints.isDesktop(context), isTrue);
        expect(AppBreakpoints.isLarge(context), isTrue);
        expect(AppBreakpoints.isWide(context), isTrue);
      });
    });
  });
}
