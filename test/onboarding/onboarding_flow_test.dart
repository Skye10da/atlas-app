import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/core/account/domain/entities/local_account_entity.dart';
import 'package:atlas_app/core/account/domain/repository_interfaces/local_account_repository_interface.dart';
import 'package:atlas_app/core/account/presentation/providers/local_account_providers.dart';
import 'package:atlas_app/discover/domain/entities/reading_analytics_entity.dart';
import 'package:atlas_app/discover/presentation/providers/reading_analytics_providers.dart';
import 'package:atlas_app/onboarding/application/onboarding_finisher.dart';
import 'package:atlas_app/onboarding/domain/entities/onboarding_draft.dart';
import 'package:atlas_app/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:atlas_app/onboarding/presentation/screens/onboarding_screen.dart';

class _RecordingFinisher implements OnboardingFinisher {
  OnboardingDraft? finishedWith;

  @override
  Future<void> finish(OnboardingDraft draft) async => finishedWith = draft;
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<_RecordingFinisher> pumpFlow(
    WidgetTester tester, {
    bool replay = false,
  }) async {
    final finisher = _RecordingFinisher();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => OnboardingScreen(replay: replay),
        ),
        GoRoute(
          path: '/library',
          builder: (_, _) => const Scaffold(body: Text('LIBRARY')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingFinisherProvider.overrideWithValue(finisher),
          if (replay)
            localAccountRepositoryProvider.overrideWithValue(
              _SavedAccountRepository(),
            ),
          if (replay)
            readingGoalProvider.overrideWith(
              (ref) async => ReadingGoalEntity.initial(),
            ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return finisher;
  }

  testWidgets('walks every step and hands the choices to the finisher', (
    tester,
  ) async {
    final finisher = await pumpFlow(tester);

    expect(find.text('Welcome to Atlas'), findsOneWidget);
    await _tap(tester, 'Get started');
    await _tap(tester, 'Next');
    await _tap(tester, 'Next');
    await _tap(tester, 'Next');

    expect(find.text('Create your profile'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Ada Lovelace');
    await tester.pump();
    await _tap(tester, 'Continue');

    expect(find.text('Make it yours'), findsOneWidget);
    await _tap(tester, 'Continue');

    expect(find.text('Set a reading rhythm'), findsOneWidget);
    await _tap(tester, '10');
    await _tap(tester, 'Continue');

    expect(find.text("You're all set, Ada"), findsOneWidget);
    await _tap(tester, 'Open my library');

    expect(find.text('LIBRARY'), findsOneWidget);
    expect(finisher.finishedWith?.displayName, 'Ada Lovelace');
    expect(finisher.finishedWith?.weeklyChapterTarget, 10);
    expect(finisher.finishedWith?.dailyMinuteTarget, isNull);
  });

  testWidgets('Skip intro jumps to profile; Skip setup finishes', (
    tester,
  ) async {
    final finisher = await pumpFlow(tester);

    await _tap(tester, 'Skip intro');
    expect(find.text('Create your profile'), findsOneWidget);

    await _tap(tester, 'Skip setup');
    expect(find.text('LIBRARY'), findsOneWidget);
    expect(finisher.finishedWith, isNotNull);
    expect(finisher.finishedWith?.displayName, isEmpty);
  });

  testWidgets('the back button returns to the previous step', (tester) async {
    await pumpFlow(tester);

    await _tap(tester, 'Get started');
    expect(find.text('Read anything, your way'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Atlas'), findsOneWidget);
  });

  testWidgets('replay seeds saved values after the initial build', (
    tester,
  ) async {
    await pumpFlow(tester, replay: true);

    await _tap(tester, 'Skip intro');
    expect(find.text('Create your profile'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsOneWidget);
  });
}

class _SavedAccountRepository implements LocalAccountRepositoryInterface {
  @override
  Future<LocalAccountEntity> load() async =>
      const LocalAccountEntity(displayName: 'Ada Lovelace');

  @override
  Future<void> save(LocalAccountEntity account) async {}
}
