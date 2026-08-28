import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/settings/presentation/screens/ai_translation_settings_screen.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_ai_settings.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_auth_state.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_translation_service.dart';
import 'package:atlas_app/wtr/domain/services/wtr_ai_status_tracker.dart';
import 'package:atlas_app/wtr/domain/services/wtr_ai_translate_service.dart';
import 'package:atlas_app/wtr/presentation/providers/wtr_providers.dart';
import 'package:atlas_app/wtr/presentation/screens/wtr_login_screen.dart';

/// Selects the translation service (Web / WebPlus / AI / AI+) a WTR-Lab novel
/// uses when its chapters are fetched.
///
/// The AI service is account-gated: selecting it never auto-signs-in, but the
/// card explains the requirement and offers the one-tap login. The reader
/// (via `WtrChapterProvider.resolveTranslate`) throws when AI is selected
/// without a valid session, so an unattended AI selection surfaces a clear
/// message instead of silently falling back to another service.
///
/// AI+ is Atlas-side and needs an AI-provider API key; its row links to
/// Settings → AI Translation while unconfigured, shows the active provider +
/// model once set up, and surfaces the tracker's fallback notice when a rate
/// limit or bad key degraded the latest chapter to Web translation — so a
/// silent downgrade never masquerades as working AI+ output.
///
/// [onServiceChanged] fires only when the selection actually changes — not on
/// re-tapping the already-selected service — so hosts can drop stale chapter
/// downloads (text fetched under the previous service) before the next read.
class WtrTranslationSelector extends ConsumerWidget {
  const WtrTranslationSelector({
    super.key,
    required this.rawId,
    this.onServiceChanged,
  });

  /// Numeric id this novel carries in the WTR reader API.
  final int rawId;

  /// Invoked when the user switches to a *different* translation service.
  final FutureOr<void> Function()? onServiceChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(wtrAuthManagerProvider);
    final serviceAsync = ref.watch(wtrTranslationServiceProvider(rawId));
    final aiSettingsAsync = ref.watch(wtrAiSettingsProvider);

    return ValueListenableBuilder<WtrAuthState>(
      valueListenable: auth.state,
      builder: (context, authState, _) {
        return ValueListenableBuilder<Map<int, WtrAiChapterOutcome>>(
          valueListenable: WtrAiStatusTracker.instance.outcomes,
          builder: (context, outcomes, _) {
            return serviceAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (service) => _SelectorCard(
                service: service,
                authState: authState,
                aiSettings: aiSettingsAsync.valueOrNull,
                aiOutcome: outcomes[rawId],
                onSelect: (selected) => _select(ref, selected, service),
                onSignIn: () => _signIn(context, ref),
                onChangeAccount: () => _changeAccount(context, ref),
                onConfigureAi: () => _openAiSettings(context),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openAiSettings(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AiTranslationSettingsScreen(),
      ),
    );
  }

  Future<void> _select(
    WidgetRef ref,
    WtrTranslationService service,
    WtrTranslationService current,
  ) async {
    final runtime = await ref.read(wtrRuntimeProvider.future);
    await runtime.setService(rawId, service);
    ref.invalidate(wtrTranslationServiceProvider(rawId));
    if (service != current) {
      await onServiceChanged?.call();
    }
  }

  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const WtrLoginScreen()));
  }

  Future<void> _changeAccount(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(wtrAuthManagerProvider);
    await auth.clearSession();
    if (!context.mounted) return;
    await _signIn(context, ref);
  }
}

class _SelectorCard extends StatelessWidget {
  const _SelectorCard({
    required this.service,
    required this.authState,
    required this.onSelect,
    required this.onSignIn,
    required this.onChangeAccount,
    required this.onConfigureAi,
    this.aiSettings,
    this.aiOutcome,
  });

  final WtrTranslationService service;
  final WtrAuthState authState;

  /// The user's AI-translation configuration, null while loading. Drives the
  /// AI+ context row (set-up prompt vs. active provider/model).
  final WtrAiSettings? aiSettings;

  /// What the AI+ path last did for this novel in the current session, used
  /// to surface a fallback notice instead of a silent downgrade.
  final WtrAiChapterOutcome? aiOutcome;

  final void Function(WtrTranslationService service) onSelect;
  final VoidCallback onSignIn;
  final VoidCallback onChangeAccount;
  final VoidCallback onConfigureAi;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Translation',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (final option in WtrTranslationService.values) ...[
                if (option != WtrTranslationService.values.first)
                  const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: ChoiceChip(
                    label: Text(option.label),
                    selected: service == option,
                    onSelected: (_) => onSelect(option),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _contextRow(context),
        ],
      ),
    );
  }

  Widget _contextRow(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (service == WtrTranslationService.aiPlus) {
      return _aiPlusContextRow(context);
    }

    if (service != WtrTranslationService.ai) {
      return Text(
        service == WtrTranslationService.web
            ? 'Source-language text (Chinese for Chinese-origin novels), '
                  'fetched without an account.'
            : 'Source-language text, fetched without an account.',
        style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
      );
    }

    switch (authState) {
      case WtrAuthState.notAuthenticated:
        return _ActionRow(
          text: 'AI translation requires signing in to WTR-Lab.',
          action: FilledButton.tonal(
            onPressed: onSignIn,
            child: const Text('Sign in to WTR-Lab'),
          ),
        );
      case WtrAuthState.authenticating:
        return Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Opening WTR-Lab sign-in…',
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        );
      case WtrAuthState.authenticated:
        return _ActionRow(
          text: 'Signed in to WTR-Lab — AI translation is active.',
          action: TextButton(
            onPressed: onChangeAccount,
            child: const Text('Change account'),
          ),
        );
      case WtrAuthState.sessionExpired:
        return _ActionRow(
          text: 'Your WTR-Lab session expired. Sign in again to use AI.',
          action: FilledButton.tonal(
            onPressed: onSignIn,
            child: const Text('Sign in again'),
          ),
        );
      case WtrAuthState.authenticationFailed:
        return _ActionRow(
          text: 'Sign-in did not complete. Try again when you are ready.',
          action: FilledButton.tonal(
            onPressed: onSignIn,
            child: const Text('Try again'),
          ),
        );
    }
  }

  /// Status line for the AI+ option: a set-up prompt while unconfigured, the
  /// active provider + model once set up, and the tracker's fallback notice
  /// when the latest chapter degraded to Web translation.
  Widget _aiPlusContextRow(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (aiSettings == null || !aiSettings!.isConfigured) {
      return _ActionRow(
        text:
            'AI+ translates with your own AI-provider key — no WTR-Lab '
            'account needed.',
        action: FilledButton.tonal(
          onPressed: onConfigureAi,
          child: const Text('Set up AI+'),
        ),
      );
    }

    if (aiOutcome != null && aiOutcome!.fellBack) {
      return _ActionRow(
        text:
            'AI+ could not translate this chapter '
            '(${_reasonText(aiOutcome!.reason)}) — Web translation was used '
            'instead.',
        action: TextButton(
          onPressed: onConfigureAi,
          child: const Text('Check setup'),
        ),
      );
    }

    return Text(
      '${aiSettings!.provider.label} · ${aiSettings!.modelFor(aiSettings!.provider)}',
      style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
    );
  }

  String _reasonText(WtrAiFailureReason? reason) {
    switch (reason) {
      case WtrAiFailureReason.notConfigured:
        return 'no API key';
      case WtrAiFailureReason.auth:
        return 'API key rejected';
      case WtrAiFailureReason.rateLimited:
        return 'rate limit';
      case WtrAiFailureReason.transient:
        return 'network problem';
      case WtrAiFailureReason.badResponse:
      case null:
        return 'unexpected reply';
    }
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.text, required this.action});

  final String text;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        action,
      ],
    );
  }
}
