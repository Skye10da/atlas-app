import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/content_engine/transport/http_transport.dart';
import 'package:atlas_app/core/design_system/tokens/breakpoints.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_ai_provider.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_ai_settings.dart';
import 'package:atlas_app/wtr/infrastructure/services/ai_chat_clients.dart';
import 'package:atlas_app/wtr/presentation/providers/wtr_providers.dart';

class AiTranslationSettingsScreen extends ConsumerStatefulWidget {
  const AiTranslationSettingsScreen({super.key});

  @override
  ConsumerState<AiTranslationSettingsScreen> createState() =>
      _AiTranslationSettingsScreenState();
}

class _AiTranslationSettingsScreenState
    extends ConsumerState<AiTranslationSettingsScreen> {
  final _keyController = TextEditingController();
  final _modelController = TextEditingController();

  var _selectedProvider = WtrAiProviderId.gemini;
  var _obscureKey = true;
  var _synced = false;

  List<String>? _fetchedModels;
  var _fetchingModels = false;
  Object? _fetchError;
  bool? _testSuccess;
  String? _testMessage;

  @override
  void dispose() {
    _keyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  void _adoptStored(WtrAiSettings settings) {
    _selectedProvider = settings.provider;
    _keyController.text = settings.apiKeyFor(settings.provider) ?? '';
    _modelController.text = settings.modelFor(settings.provider);
    _fetchedModels = null;
    _fetchError = null;
    if ((settings.apiKeyFor(settings.provider) ?? '').isNotEmpty) {
      unawaited(_fetchModels());
    }
  }

  Future<void> _fetchModels({bool force = false}) async {
    final apiKey = _keyController.text.trim();
    if (apiKey.isEmpty) return;
    if (_fetchingModels) return;
    if (!force && _fetchedModels != null) return;
    setState(() {
      _fetchingModels = true;
      _fetchError = null;
    });
    try {
      final models = await wtrAiClients[_selectedProvider]!.listModels(
        HttpTransport(),
        apiKey: apiKey,
      );
      if (!mounted) return;
      setState(() {
        _fetchedModels = models;
        _fetchingModels = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _fetchError = e;
        _fetchingModels = false;
      });
    }
  }

  Future<void> _persist(WtrAiSettings next) async {
    await ref.read(wtrAiSettingsRepositoryProvider).save(next);
    ref.invalidate(wtrAiSettingsProvider);
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Settings saved'), duration: Duration(seconds: 1)),
    );
  }

  WtrAiSettings? get _current => ref.read(wtrAiSettingsProvider).valueOrNull;

  Future<void> _saveKey() async {
    final current = _current;
    if (current == null) return;
    await _persist(
      current
          .withProvider(_selectedProvider)
          .withApiKey(_selectedProvider, _keyController.text.trim()),
    );
    await _fetchModels(force: true);
  }

  Future<void> _clearKey() async {
    final current = _current;
    if (current == null) return;
    setState(() {
      _keyController.clear();
      _fetchedModels = null;
      _fetchError = null;
      _testSuccess = null;
      _testMessage = null;
    });
    await _persist(current.withApiKey(_selectedProvider, null));
  }

  Future<void> _saveModel(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final current = _current;
    if (current == null) return;
    await _persist(
      current
          .withProvider(_selectedProvider)
          .withModel(_selectedProvider, trimmed),
    );
  }

  Future<void> _testConfiguration() async {
    final apiKey = _keyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() {
        _testSuccess = false;
        _testMessage = 'Please enter an API key first.';
      });
      return;
    }
    setState(() {
      _testSuccess = null;
      _testMessage = 'Testing connection...';
    });
    try {
      final client = wtrAiClients[_selectedProvider]!;
      final models = await client.listModels(
        HttpTransport(),
        apiKey: apiKey,
      );
      if (!mounted) return;
      setState(() {
        _testSuccess = true;
        _testMessage = 'Connected successfully! ${models.length} model(s) available.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testSuccess = false;
        _testMessage = 'Connection failed: $e';
      });
    }
  }

  List<String> _candidateModels() {
    final fetched = _fetchedModels;
    if (fetched != null && fetched.isNotEmpty) return fetched;
    return _selectedProvider.fallbackModels;
  }

  @override
  Widget build(BuildContext context) {
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
          if (!_synced) {
            _synced = true;
            _adoptStored(settings);
          }

          final storedKey = settings.apiKeyFor(_selectedProvider);

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
                      initialSelection: _selectedProvider,
                      dropdownMenuEntries: [
                        for (final provider in WtrAiProviderId.values)
                          DropdownMenuEntry(value: provider, label: provider.label),
                      ],
                      onSelected: (p) {
                        if (p == null || p == _selectedProvider) return;
                        setState(() {
                          _selectedProvider = p;
                          _fetchedModels = null;
                          _fetchError = null;
                          _testSuccess = null;
                          _testMessage = null;
                          _keyController.text = settings.apiKeyFor(p) ?? '';
                          _modelController.text = settings.modelFor(p);
                        });
                        unawaited(_persist(settings.withProvider(p)));
                        if ((settings.apiKeyFor(p) ?? '').isNotEmpty) {
                          unawaited(_fetchModels());
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 3. API Key & Model Configuration
                  _SectionCard(
                    title: '${_selectedProvider.label} Configuration',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _keyController,
                          obscureText: _obscureKey,
                          decoration: InputDecoration(
                            labelText: 'API Key',
                            hintText: '${_selectedProvider.label} API key',
                            filled: true,
                            fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.4),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              ),
                              onPressed: () => setState(() => _obscureKey = !_obscureKey),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            FilledButton.tonal(
                              onPressed: _saveKey,
                              child: const Text('Save key'),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            if (storedKey != null && storedKey.isNotEmpty)
                              OutlinedButton(
                                onPressed: _clearKey,
                                child: const Text('Clear'),
                              ),
                            const Spacer(),
                            FilledButton.icon(
                              onPressed: _testConfiguration,
                              icon: const Icon(Icons.bolt_rounded, size: 16),
                              label: const Text('Test'),
                            ),
                          ],
                        ),
                        if (_testMessage != null) ...[
                          const SizedBox(height: AppSpacing.smMd),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                            decoration: BoxDecoration(
                              color: _testSuccess == true
                                  ? colors.tertiaryContainer
                                  : (_testSuccess == false ? colors.errorContainer : colors.surfaceContainerHighest),
                              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _testSuccess == true
                                      ? Icons.check_circle_rounded
                                      : (_testSuccess == false ? Icons.error_outline_rounded : Icons.sync_rounded),
                                  size: 16,
                                  color: _testSuccess == true
                                      ? colors.onTertiaryContainer
                                      : (_testSuccess == false ? colors.onErrorContainer : colors.onSurfaceVariant),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _testMessage!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _testSuccess == true
                                          ? colors.onTertiaryContainer
                                          : (_testSuccess == false ? colors.onErrorContainer : colors.onSurfaceVariant),
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
                                controller: _modelController,
                                decoration: InputDecoration(
                                  labelText: 'Model Name',
                                  filled: true,
                                  fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.4),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
                                  ),
                                ),
                                onSubmitted: _saveModel,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.tune_rounded),
                              tooltip: 'Preset Models',
                              itemBuilder: (_) => [
                                for (final m in _candidateModels())
                                  PopupMenuItem(value: m, child: Text(m)),
                              ],
                              onSelected: (m) {
                                setState(() => _modelController.text = m);
                                _saveModel(m);
                              },
                            ),
                          ],
                        ),
                        if (_fetchError != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Could not fetch remote models: $_fetchError (showing curated fallback)',
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
