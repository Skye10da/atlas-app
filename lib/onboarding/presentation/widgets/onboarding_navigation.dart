import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/library/presentation/widgets/import_url_dialog.dart';
import 'package:atlas_app/onboarding/domain/entities/onboarding_step.dart';
import 'package:atlas_app/onboarding/presentation/providers/onboarding_providers.dart';

/// Leaves onboarding for [destination]. Kept in one place because it is the
/// only spot where onboarding reaches into the library feature.
void openOnboardingDestination(
  BuildContext context,
  OnboardingDestination destination,
) {
  // Captured before navigating: the onboarding page is gone afterwards, but
  // the root navigator's context stays valid for showing the sheet.
  final rootContext = Navigator.of(context, rootNavigator: true).context;
  context.go(OnboardingRoutes.library);
  switch (destination) {
    case OnboardingDestination.library:
      break;
    case OnboardingDestination.sources:
      unawaited(context.push('/sources'));
    case OnboardingDestination.importBook:
      // The library route has to be on screen before a sheet can sit over it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!rootContext.mounted) return;
        unawaited(
          showImportUrlSheet(
            rootContext,
            mode: ImportSheetMode.combined,
            title: 'Add your first book',
          ),
        );
      });
  }
}
