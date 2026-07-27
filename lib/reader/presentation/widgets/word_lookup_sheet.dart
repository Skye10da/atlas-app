import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/services/dictionary_service.dart';
import 'package:atlas_app/core/services/platform_service_provider.dart';
import 'package:atlas_app/dictionary/domain/entities/dictionary_word_entity.dart';
import 'package:atlas_app/dictionary/presentation/providers/dictionary_providers.dart';

class WordLookupSheet extends ConsumerStatefulWidget {
  const WordLookupSheet({
    super.key,
    required this.word,
    this.initialLanguage = 'en',
  });

  final String word;
  final String initialLanguage;

  @override
  ConsumerState<WordLookupSheet> createState() => _WordLookupSheetState();
}

class _WordLookupSheetState extends ConsumerState<WordLookupSheet> {
  late String _language;
  WiktionaryResult? _result;
  bool _loading = true;
  String? _error;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _language = widget.initialLanguage;
    _checkSaved();
    _lookup();
  }

  void _checkSaved() {
    final id = '${widget.word}_$_language';
    ref.read(dictionaryRepositoryProvider).exists(id).then((exists) {
      if (mounted) setState(() => _saved = exists);
    });
  }

  Future<void> _lookup() async {
    setState(() {
      _loading = true;
      _result = null;
      _error = null;
    });
    final svc = ref.read(dictionaryServiceProvider);
    try {
      final result = await svc.lookup(widget.word, _language);
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
        if (result == null) {
          _error = 'No definition found for "${widget.word}".';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not look up "${widget.word}". Check your connection.';
      });
    }
    _checkSaved();
  }

  Future<void> _toggleSave() async {
    final result = _result;
    if (result == null) return;
    final id = '${widget.word}_$_language';
    final repo = ref.read(dictionaryRepositoryProvider);
    if (_saved) {
      await repo.delete(id);
    } else {
      final langLabel = supportedLanguages
          .firstWhere((l) => l.code == _language,
              orElse: () => const WiktionaryLanguage('en', 'English'))
          .label;
      final first = result.senses.first;
      await repo.save(DictionaryWordEntity(
        id: id,
        word: widget.word,
        language: _language,
        languageLabel: langLabel,
        phonetic: result.phonetic,
        partOfSpeech: first.partOfSpeech,
        definition: first.definition,
        fullJson: '',
        savedAt: DateTime.now(),
      ));
    }
    ref.invalidate(savedWordsProvider);
    if (mounted) setState(() => _saved = !_saved);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.word,
                    style: textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_border),
                tooltip: _saved ? 'Remove from saved' : 'Save word',
                onPressed: _result != null ? _toggleSave : null,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          if (_loading) ...[
            const SizedBox(height: AppSpacing.lg),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: textTheme.bodyMedium),
          ],
          if (_result != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: supportedLanguages.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.xs),
                itemBuilder: (ctx, i) {
                  final l = supportedLanguages[i];
                  final selected = l.code == _language;
                  return ChoiceChip(
                    label: Text(l.code.toUpperCase(),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal)),
                    selected: selected,
                    onSelected: (v) {
                      if (v && !selected) {
                        setState(() => _language = l.code);
                        _lookup();
                      }
                    },
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: SingleChildScrollView(
                child: _buildDefinitionCard(textTheme, colorScheme),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDefinitionCard(
      TextTheme textTheme, ColorScheme colorScheme) {
    final result = _result!;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(result.word,
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: AppSpacing.sm),
                if (result.phonetic != null)
                  Text(result.phonetic!,
                      style: textTheme.bodySmall
                          ?.copyWith(fontStyle: FontStyle.italic)),
                const Spacer(),
                Text(_language.toUpperCase(),
                    style: textTheme.labelSmall
                        ?.copyWith(color: colorScheme.primary)),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            ...result.senses.map((sense) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(sense.partOfSpeech,
                          style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onPrimaryContainer)),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(sense.definition,
                        style: textTheme.bodyMedium),
                    if (sense.examples.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      ...sense.examples.take(1).map((ex) => Text(
                            '"$ex"',
                            style: textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.6)),
                          )),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
