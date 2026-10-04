import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas_app/core/design_system/atoms/app_button.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/intelligence/orchestrator/providers/ollama_provider.dart';

class AiProviderSettingsScreen extends HookConsumerWidget {
  const AiProviderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProviderId = useState<String>('offline');
    final geminiKeyController = useTextEditingController();
    final openaiKeyController = useTextEditingController();
    final anthropicKeyController = useTextEditingController();
    final openrouterKeyController = useTextEditingController();
    final ollamaEndpointController = useTextEditingController(text: 'http://localhost:11434');

    final ollamaModels = useState<List<String>>([]);
    final isTestingOllama = useState<bool>(false);
    final ollamaStatus = useState<String?>(null);

    // Load initial settings
    useEffect(() {
      SharedPreferences.getInstance().then((prefs) {
        activeProviderId.value = prefs.getString('atlas_intel_active_provider') ?? 'offline';
        geminiKeyController.text = prefs.getString('atlas_intel_gemini_key') ?? '';
        openaiKeyController.text = prefs.getString('atlas_intel_openai_key') ?? '';
        anthropicKeyController.text = prefs.getString('atlas_intel_anthropic_key') ?? '';
        openrouterKeyController.text = prefs.getString('atlas_intel_openrouter_key') ?? '';
        ollamaEndpointController.text = prefs.getString('atlas_intel_ollama_endpoint') ?? 'http://localhost:11434';
      });
      return null;
    }, const []);

    Future<void> saveSettings() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('atlas_intel_active_provider', activeProviderId.value);
      await prefs.setString('atlas_intel_gemini_key', geminiKeyController.text.trim());
      await prefs.setString('atlas_intel_openai_key', openaiKeyController.text.trim());
      await prefs.setString('atlas_intel_anthropic_key', anthropicKeyController.text.trim());
      await prefs.setString('atlas_intel_openrouter_key', openrouterKeyController.text.trim());
      await prefs.setString('atlas_intel_ollama_endpoint', ollamaEndpointController.text.trim());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI settings saved successfully')),
        );
      }
    }

    Future<void> testOllama() async {
      isTestingOllama.value = true;
      ollamaStatus.value = null;
      try {
        final provider = OllamaProvider(endpoint: ollamaEndpointController.text.trim());
        final isAvailable = await provider.isAvailable();
        if (isAvailable) {
          final models = await provider.getAvailableModels();
          ollamaModels.value = models;
          ollamaStatus.value = 'Connected! Found ${models.length} installed models.';
        } else {
          ollamaStatus.value = 'Could not reach Ollama at that endpoint.';
        }
      } catch (e) {
        ollamaStatus.value = 'Connection failed: $e';
      } finally {
        isTestingOllama.value = false;
      }
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI & BYOK Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save Settings',
            onPressed: saveSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'Active AI Provider',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Select which AI layer Atlas should use for conversational reasoning and deep analysis. Layer 1 & 2 story memory always works offline.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Provider selector radio list
          _ProviderOptionTile(
            title: '100% Offline Story Memory (No AI)',
            subtitle: 'Zero cloud calls, zero external models, completely private and offline.',
            value: 'offline',
            groupValue: activeProviderId.value,
            onChanged: (val) => activeProviderId.value = val!,
          ),
          _ProviderOptionTile(
            title: 'Ollama (Local / LAN Server)',
            subtitle: 'Run local open-weights models (Llama 3, Qwen, Mistral) on your machine.',
            value: 'ollama',
            groupValue: activeProviderId.value,
            onChanged: (val) => activeProviderId.value = val!,
          ),
          _ProviderOptionTile(
            title: 'Google Gemini (BYOK)',
            subtitle: 'Direct cloud inference using your Google AI Studio API key.',
            value: 'cloud_gemini',
            groupValue: activeProviderId.value,
            onChanged: (val) => activeProviderId.value = val!,
          ),
          _ProviderOptionTile(
            title: 'OpenAI (BYOK)',
            subtitle: 'Direct cloud inference using your OpenAI API key.',
            value: 'cloud_openai',
            groupValue: activeProviderId.value,
            onChanged: (val) => activeProviderId.value = val!,
          ),
          _ProviderOptionTile(
            title: 'OpenRouter (BYOK)',
            subtitle: 'Unified API key for dozens of cloud models.',
            value: 'cloud_openrouter',
            groupValue: activeProviderId.value,
            onChanged: (val) => activeProviderId.value = val!,
          ),
          _ProviderOptionTile(
            title: 'Anthropic Claude (BYOK)',
            subtitle: 'Direct cloud inference using your Anthropic API key.',
            value: 'cloud_anthropic',
            groupValue: activeProviderId.value,
            onChanged: (val) => activeProviderId.value = val!,
          ),

          const Divider(height: AppSpacing.xl),

          // Configuration forms
          Text(
            'Provider Credentials & Endpoints',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Ollama Config
          const _SectionHeader(title: 'Ollama Configuration'),
          TextField(
            controller: ollamaEndpointController,
            decoration: const InputDecoration(
              labelText: 'Ollama Endpoint URL',
              hintText: 'http://localhost:11434 or http://192.168.1.50:11434',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              AppButton.secondary(
                label: 'Test Connection',
                loading: isTestingOllama.value,
                onPressed: testOllama,
              ),
              const SizedBox(width: AppSpacing.sm),
              if (ollamaStatus.value != null)
                Expanded(
                  child: Text(
                    ollamaStatus.value!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: ollamaStatus.value!.contains('Connected')
                          ? Colors.green
                          : colors.error,
                    ),
                  ),
                ),
            ],
          ),
          if (ollamaModels.value.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: ollamaModels.value.map((m) {
                return Chip(label: Text(m, style: const TextStyle(fontSize: 11)));
              }).toList(),
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          // Cloud BYOK Keys
          const _SectionHeader(title: 'Cloud API Keys'),
          TextField(
            controller: geminiKeyController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Google Gemini API Key',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: openaiKeyController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'OpenAI API Key',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: openrouterKeyController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'OpenRouter API Key',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: anthropicKeyController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Anthropic Claude API Key',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton.primary(
            label: 'Save Configuration',
            expanded: true,
            onPressed: saveSettings,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _ProviderOptionTile extends StatelessWidget {
  const _ProviderOptionTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = value == groupValue;

    return RadioListTile<String>(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      value: value,
      // ignore: deprecated_member_use
      groupValue: groupValue,
      selected: isSelected,
      dense: true,
      contentPadding: EdgeInsets.zero,
      // ignore: deprecated_member_use
      onChanged: onChanged,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
