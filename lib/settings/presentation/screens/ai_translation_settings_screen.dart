import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/content_engine/transport/http_transport.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_ai_provider.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_ai_settings.dart';
import 'package:atlas_app/wtr/infrastructure/services/ai_chat_clients.dart';
import 'package:atlas_app/wtr/presentation/providers/wtr_providers.dart';

/// Configures the AI providers behind the WTR-Lab "AI+" translation mode:
/// which provider is active, its API key, and the model to use.
///
/// Keys and models are stored *per provider*, so trying another provider
/// never loses the previous one's credentials. Keys live in SharedPreferences
/// on this device and are sent only to the configured provider.
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

  /// Guards the one-time adoption of persisted settings into local state.
  var _synced = false;

  /// Live `/models` results for [_selectedProvider]; null until fetched or
  /// when the fetch failed (the curated fallback is offered instead).
  List<String>? _fetchedModels;
  var _fetchingModels = false;
  Object? _fetchError;

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
      const SnackBar(content: Text('Saved'), duration: Duration(seconds: 1)),
    );
  }

  WtrAiSettings? get _current => ref.read(wtrAiSettingsProvider).valueOrNull;

  Future<void> _saveKey() async {
    final current = _current;
    if (current == null) return;
    await _persist(
      // Pin the selected provider too: the pipeline reads `provider`, and a
      // key saved for the wrong active provider would silently never be used.
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
    final model = _modelController.text.trim();
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (apiKey.isEmpty || model.isEmpty) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Enter an API key and a model first')),
      );
      return;
    }
    try {
      await wtrAiClients[_selectedProvider]!.complete(
        HttpTransport(),
        apiKey: apiKey,
        model: model,
        system: 'Reply with exactly: ok',
        prompt: 'Say ok.',
      );
      messenger?.showSnackBar(
        SnackBar(content: Text('$model answered — configuration works.')),
      );
    } on Object catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('Test failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(wtrAiSettingsProvider);

    return settingsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('AI Translation')),
        body: Center(child: Text('Could not load settings: $error')),
      ),
      data: (settings) {
        if (!_synced) {
          _synced = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _adoptStored(settings));
            }
          });
        }
        return _buildBody(context, settings);
      },
    );
  }

  Widget _buildBody(BuildContext context, WtrAiSettings settings) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final storedKey = settings.apiKeyFor(_selectedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('AI Translation')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'Used by the AI+ translation option on WTR-Lab novels. Chapters '
            'are translated with your chosen provider, guided by the '
            'novel\u2019s glossary so names stay consistent.',
            style: textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('PROVIDER', style: _sectionStyle(context, colors)),
          const SizedBox(height: AppSpacing.xs),
          DropdownMenu<WtrAiProviderId>(
            expandedInsets: EdgeInsets.zero,
            initialSelection: _selectedProvider,
            dropdownMenuEntries: [
              for (final provider in WtrAiProviderId.values)
                DropdownMenuEntry(value: provider, label: provider.label),
            ],
            onSelected: (provider) {
              if (provider == null || provider == _selectedProvider) return;
              setState(() {
                _selectedProvider = provider;
                _fetchedModels = null;
                _fetchError = null;
                _keyController.text = settings.apiKeyFor(provider) ?? '';
                _modelController.text = settings.modelFor(provider);
              });
              // The selection itself must reach storage: the translation
              // pipeline reads `settings.provider`, not this screen's state.
              unawaited(_persist(settings.withProvider(provider)));
              if ((settings.apiKeyFor(provider) ?? '').isNotEmpty) {
                unawaited(_fetchModels());
              }
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('API KEY', style: _sectionStyle(context, colors)),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _keyController,
            obscureText: _obscureKey,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: '${_selectedProvider.label} API key',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _obscureKey ? 'Show key' : 'Hide key',
                icon: Icon(
                  _obscureKey
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
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
              TextButton(
                onPressed: storedKey == null ? null : _clearKey,
                child: const Text('Clear'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _testConfiguration,
                icon: const Icon(Icons.bolt_outlined),
                label: const Text('Test'),
              ),
            ],
          ),
          if (storedKey == null || storedKey.isEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'No ${_selectedProvider.label} key yet — AI+ falls back to Web '
              'translation until one is saved.',
              style: textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text('MODEL', style: _sectionStyle(context, colors)),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _modelController,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    hintText: 'Model ID',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: _saveModel,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              PopupMenuButton<String>(
                tooltip: 'Suggested models',
                icon: const Icon(Icons.list_outlined),
                itemBuilder: (context) => [
                  for (final id in _candidateModels())
                    PopupMenuItem(value: id, child: Text(id)),
                ],
                onSelected: (id) {
                  setState(() => _modelController.text = id);
                  _saveModel(id);
                },
              ),
              IconButton(
                tooltip: 'Refresh model list',
                onPressed: _fetchingModels
                    ? null
                    : () => _fetchModels(force: true),
                icon: _fetchingModels
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _modelStatusLine(),
            style: textTheme.bodySmall?.copyWith(
              color: _fetchError == null
                  ? colors.onSurfaceVariant
                  : colors.error,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: () => _saveModel(_modelController.text),
            child: const Text('Use this model'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'API keys are stored only on this device and are sent solely to '
            'the selected provider.',
            style: textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// What the picker offers: live results when available, otherwise the
  /// curated fallback — always including whatever is currently entered so
  /// the user's own choice never disappears from the list.
  List<String> _candidateModels() {
    final current = _modelController.text.trim();
    return {
      ...(_fetchedModels ?? _selectedProvider.fallbackModels),
      _selectedProvider.defaultModel,
      if (current.isNotEmpty) current,
    }.toList()..sort();
  }

  String _modelStatusLine() {
    if (_fetchingModels) return 'Fetching available models…';
    if (_fetchError != null) {
      return 'Could not fetch the model list (${_shortError()}) — showing '
          'built-in suggestions. A custom ID can still be entered.';
    }
    if (_fetchedModels == null) {
      return 'Built-in suggestions shown; save an API key to fetch the live '
          'model list.';
    }
    return '${_fetchedModels!.length} models available.';
  }

  String _shortError() {
    final message = '$_fetchError';
    return message.length > 80 ? '${message.substring(0, 80)}…' : message;
  }

  TextStyle? _sectionStyle(BuildContext context, ColorScheme colors) =>
      Theme.of(context).textTheme.labelSmall?.copyWith(
        color: colors.onSurfaceVariant,
        letterSpacing: 1.2,
      );
}
