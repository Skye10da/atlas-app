import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:atlas_app/core/theme/app_theme.dart';

void main() {
  testWidgets('App theme compiles', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
