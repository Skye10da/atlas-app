import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/content_engine/transport/http_transport.dart';
import 'package:atlas_app/core/design_system/tokens/breakpoints.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_ai_provider.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_ai_settings.dart';
import 'package:atlas_app/wtr/infrastructure/services/ai_chat_clients.dart';
import 'package:atlas_app/wtr/presentation/providers/wtr_providers.dart';

class AiTranslationSettingsScreen extends HookConsumerWidget {
  const AiTranslationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyController = useTextEditingController();
    final modelController = useTextEditingController();

    final selectedProvider = useState(WtrAiProviderId.gemini);
    final obscureKey = useState(true);
    final synced = useRef(false);

    final fetchedModels = useState<List<String>?>(null);
    final fetchingModels = useState(false);
    final fetchError = useState<Object?>(null);
    final testSuccess = useState<bool?>(null);
    final testMessage = useState<String?>(null);

    WtrAiSettings? current() => ref.read(wtrAiSettingsProvider).valueOrNull;

    Future<void> persist(WtrAiSettings next) async {
      await ref.read(wtrAiSettingsRepositoryProvider).save(next);
      ref.invalidate(wtrAiSettingsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Settings saved'), duration: Duration(seconds: 1)),
      );
    }

    Future<void> fetchModels({bool force = false}) async {
      final apiKey = keyController.text.trim();
      if (apiKey.isEmpty) return;
      if (fetchingModels.value) return;
      if (!force && fetchedModels.value != null) return;
      fetchingModels.value = true;
      fetchError.value = null;
      try {
        final models = await wtrAiClients[selectedProvider.value]!.listModels(
          HttpTransport(),
          apiKey: apiKey,
        );
        if (!context.mounted) return;
        fetchedModels.value = models;
        fetchingModels.value = false;
      } on Object catch (e) {
        if (!context.mounted) return;
        fetchError.value = e;
        fetchingModels.value = false;
      }
    }

    void adoptStored(WtrAiSettings settings) {
      selectedProvider.value = settings.provider;
      keyController.text = settings.apiKeyFor(settings.provider) ?? '';
      modelController.text = settings.modelFor(settings.provider);
      fetchedModels.value = null;
      fetchError.value = null;
      if ((settings.apiKeyFor(settings.provider) ?? '').isNotEmpty) {
        unawaited(fetchModels());
      }
    }

    Future<void> saveKey() async {
      final curr = current();
      if (curr == null) return;
      await persist(
        curr
            .withProvider(selectedProvider.value)
            .withApiKey(selectedProvider.value, keyController.text.trim()),
      );
      await fetchModels(force: true);
    }

    Future<void> clearKey() async {
      final curr = current();
      if (curr == null) return;
      keyController.clear();
      fetchedModels.value = null;
      fetchError.value = null;
      testSuccess.value = null;
      testMessage.value = null;
      await persist(curr.withApiKey(selectedProvider.value, null));
    }

    Future<void> saveModel(String value) async {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      final curr = current();
      if (curr == null) return;
      await persist(
        curr
            .withProvider(selectedProvider.value)
            .withModel(selectedProvider.value, trimmed),
      );
    }

    Future<void> testConfiguration() async {
      final apiKey = keyController.text.trim();
      if (apiKey.isEmpty) {
        testSuccess.value = false;
        testMessage.value = 'Please enter an API key first.';
        return;
      }
      testSuccess.value = null;
      testMessage.value = 'Testing connection...';
      try {
        final client = wtrAiClients[selectedProvider.value]!;
        final models = await client.listModels(
          HttpTransport(),
          apiKey: apiKey,
        );
        if (!context.mounted) return;
        testSuccess.value = true;
        testMessage.value = 'Connected successfully! ${models.length} model(s) available.';
      } catch (e) {
        if (!context.mounted) return;
        testSuccess.value = false;
        testMessage.value = 'Connection failed: $e';
      }
    }

    List<String> candidateModels() {
      final fetched = fetchedModels.value;
      if (fetched != null && fetched.isNotEmpty) return fetched;
      return selectedProvider.value.fallbackModels;
    }

    final settingsAsync = ref.watch(wtrAiSettingsProvider);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Translation ✨',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load settings: $e')),
        data: (settings) {
          if (!synced.value) {
            synced.value = true;
            adoptStored(settings);
          }

          final storedKey = settings.apiKeyFor(selectedProvider.value);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppBreakpoints.formContentMaxWidth,
              ),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                children: [
                  // 1. Branded Info Banner
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: colors.primary, size: 22),
                        const SizedBox(width: AppSpacing.smMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI+ Translation Engine',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Translates chapters with high fidelity, maintaining character name glossaries. Keys are stored locally on your device.',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 2. Provider Selection
                  _SectionCard(
                    title: 'Active Provider',
                    child: DropdownMenu<WtrAiProviderId>(
                      expandedInsets: EdgeInsets.zero,
                      initialSelection: selectedProvider.value,
                      dropdownMenuEntries: [
                        for (final provider in WtrAiProviderId.values)
                          DropdownMenuEntry(value: provider, label: provider.label),
                      ],
                      onSelected: (p) {
                        if (p == null || p == selectedProvider.value) return;
                        selectedProvider.value = p;
                        fetchedModels.value = null;
                        fetchError.value = null;
                        testSuccess.value = null;
                        testMessage.value = null;
                        keyController.text = settings.apiKeyFor(p) ?? '';
                        modelController.text = settings.modelFor(p);
                        unawaited(persist(settings.withProvider(p)));
                        if ((settings.apiKeyFor(p) ?? '').isNotEmpty) {
                          unawaited(fetchModels());
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 3. API Key & Model Configuration
                  _SectionCard(
                    title: '${selectedProvider.value.label} Configuration',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: keyController,
                          obscureText: obscureKey.value,
                          decoration: InputDecoration(
                            labelText: 'API Key',
                            hintText: '${selectedProvider.value.label} API key',
                            filled: true,
                            fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.4),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscureKey.value ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              ),
                              onPressed: () => obscureKey.value = !obscureKey.value,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            FilledButton.tonal(
                              onPressed: saveKey,
                              child: const Text('Save key'),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            if (storedKey != null && storedKey.isNotEmpty)
                              OutlinedButton(
                                onPressed: clearKey,
                                child: const Text('Clear'),
                              ),
                            const Spacer(),
                            FilledButton.icon(
                              onPressed: testConfiguration,
                              icon: const Icon(Icons.bolt_rounded, size: 16),
                              label: const Text('Test'),
                            ),
                          ],
                        ),
                        if (testMessage.value != null) ...[
                          const SizedBox(height: AppSpacing.smMd),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                            decoration: BoxDecoration(
                              color: testSuccess.value == true
                                  ? colors.tertiaryContainer
                                  : (testSuccess.value == false ? colors.errorContainer : colors.surfaceContainerHighest),
                              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  testSuccess.value == true
                                      ? Icons.check_circle_rounded
                                      : (testSuccess.value == false ? Icons.error_outline_rounded : Icons.sync_rounded),
                                  size: 16,
                                  color: testSuccess.value == true
                                      ? colors.onTertiaryContainer
                                      : (testSuccess.value == false ? colors.onErrorContainer : colors.onSurfaceVariant),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    testMessage.value!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: testSuccess.value == true
                                          ? colors.onTertiaryContainer
                                          : (testSuccess.value == false ? colors.onErrorContainer : colors.onSurfaceVariant),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        const Divider(),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: modelController,
                                decoration: InputDecoration(
                                  labelText: 'Model Name',
                                  filled: true,
                                  fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.4),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
                                  ),
                                ),
                                onSubmitted: saveModel,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.tune_rounded),
                              tooltip: 'Preset Models',
                              itemBuilder: (_) => [
                                for (final m in candidateModels())
                                  PopupMenuItem(value: m, child: Text(m)),
                              ],
                              onSelected: (m) {
                                modelController.text = m;
                                saveModel(m);
                              },
                            ),
                          ],
                        ),
                        if (fetchError.value != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Could not fetch remote models: ${fetchError.value} (showing curated fallback)',
                            style: TextStyle(fontSize: 11, color: colors.error),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 4. Getting an API Key Guide
                  _SectionCard(
                    title: 'How to get a key',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1. Visit the provider console (e.g. Google AI Studio, OpenAI Platform).\n'
                          '2. Generate a personal API key.\n'
                          '3. Paste the key above and tap "Save Key" followed by "Test".',
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}
