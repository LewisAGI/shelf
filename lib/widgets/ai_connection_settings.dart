import 'package:flutter/material.dart';

import '../models/ai_provider.dart';
import '../services/ai_settings_controller.dart';
import '../theme/shelf_theme.dart';
import 'ai_scope.dart';

/// Connection + BYO AI block. Keys go to Keychain; Shelf never spends house tokens.
class AiConnectionSettings extends StatefulWidget {
  const AiConnectionSettings({super.key});

  @override
  State<AiConnectionSettings> createState() => _AiConnectionSettingsState();
}

class _AiConnectionSettingsState extends State<AiConnectionSettings> {
  late final TextEditingController _endpoint;
  late final TextEditingController _model;
  late final TextEditingController _apiKey;
  AiSettingsController? _ai;
  var _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _endpoint = TextEditingController();
    _model = TextEditingController();
    _apiKey = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ai = AiScope.maybeOf(context);
    if (ai == _ai) {
      return;
    }
    _ai?.removeListener(_copyFromController);
    _ai = ai;
    _ai?.addListener(_copyFromController);
    _copyFromController();
  }

  @override
  void dispose() {
    _ai?.removeListener(_copyFromController);
    _endpoint.dispose();
    _model.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  void _copyFromController() {
    final ai = _ai;
    if (ai == null || !mounted) {
      return;
    }
    if (_endpoint.text != ai.baseUrl) {
      _endpoint.value = TextEditingValue(
        text: ai.baseUrl,
        selection: TextSelection.collapsed(offset: ai.baseUrl.length),
      );
    }
    if (_model.text != ai.model) {
      _model.value = TextEditingValue(
        text: ai.model,
        selection: TextSelection.collapsed(offset: ai.model.length),
      );
    }
  }

  Future<void> _pickProvider(BuildContext context) async {
    final ai = AiScope.maybeOf(context);
    if (ai == null) {
      return;
    }
    final chosen = await showModalBottomSheet<AiProvider>(
      context: context,
      backgroundColor: ShelfColors.white,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final provider in AiProvider.values)
                ListTile(
                  key: Key('settings-ai-provider-${provider.id}'),
                  title: Text(provider.label),
                  subtitle: Text(
                    provider == AiProvider.openaiCompatible
                        ? 'Any server that speaks the OpenAI API'
                        : provider.presetBaseUrl,
                  ),
                  trailing: provider == ai.provider
                      ? const Icon(Icons.check, color: ShelfColors.orange)
                      : null,
                  onTap: () => Navigator.of(context).pop(provider),
                ),
            ],
          ),
        );
      },
    );
    if (chosen != null) {
      await ai.setProvider(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ai = AiScope.maybeOf(context);
    if (ai == null) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: ai,
      builder: (context, _) {
        return _SettingsSection(
          title: 'API / connection',
          description:
              'Bring your own key. Shelf calls your provider from this iPhone — there is no house-paid AI and no shared backend spend.',
          children: [
            const _SettingsSubhead(title: 'Connection'),
            _SettingsCard(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Status'),
                    subtitle: Text(ai.connectionStatusLabel),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    title: const Text('Endpoint'),
                    subtitle: Text(ai.endpointLabel),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  const ListTile(
                    title: Text('Sync'),
                    subtitle: Text('Off — this device is the library'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _SettingsSubhead(title: 'Bring your own AI'),
            _SettingsCard(
              child: Column(
                children: [
                  ListTile(
                    key: const Key('settings-ai-provider'),
                    title: const Text('Provider'),
                    subtitle: Text(ai.provider.label),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _pickProvider(context),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  if (ai.provider.allowsCustomBaseUrl)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: TextField(
                        key: const Key('settings-ai-endpoint'),
                        controller: _endpoint,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Base URL',
                          hintText: 'https://api.example.com/v1',
                        ),
                        onChanged: (value) => ai.setBaseUrl(value),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  if (ai.provider.allowsCustomBaseUrl)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      key: const Key('settings-ai-api-key'),
                      controller: _apiKey,
                      obscureText: _obscureKey,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'API key',
                        hintText: ai.hasApiKey
                            ? 'Saved in Keychain — paste to replace'
                            : 'Paste your provider key',
                        suffixIcon: IconButton(
                          tooltip: _obscureKey ? 'Show key' : 'Hide key',
                          onPressed: () =>
                              setState(() => _obscureKey = !_obscureKey),
                          icon: Icon(
                            _obscureKey
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('settings-ai-save-key'),
                            onPressed: ai.busy
                                ? null
                                : () async {
                                    await ai.saveApiKey(_apiKey.text);
                                    _apiKey.clear();
                                  },
                            child: Text(
                              ai.hasApiKey ? 'Replace key' : 'Save key',
                            ),
                          ),
                        ),
                        if (ai.hasApiKey) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            key: const Key('settings-ai-clear-key'),
                            onPressed: ai.busy
                                ? null
                                : () async {
                                    await ai.clearApiKey();
                                    _apiKey.clear();
                                  },
                            child: const Text('Remove'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: TextField(
                      key: const Key('settings-ai-model'),
                      controller: _model,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Model',
                      ),
                      onChanged: (value) => ai.setModel(value),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('settings-ai-test-connection'),
              onPressed: ai.busy
                  ? null
                  : () async {
                      if (_apiKey.text.trim().isNotEmpty) {
                        await ai.saveApiKey(_apiKey.text);
                        _apiKey.clear();
                      }
                      if (ai.provider.allowsCustomBaseUrl) {
                        await ai.setBaseUrl(_endpoint.text);
                      }
                      await ai.setModel(_model.text);
                      await ai.verify();
                    },
              child: Text(ai.busy ? 'Testing…' : 'Test connection'),
            ),
            if (ai.status != null) ...[
              const SizedBox(height: 8),
              Text(
                key: const Key('settings-ai-status'),
                ai.status!,
                style: TextStyle(
                  color: ai.lastVerifyOk
                      ? const Color(0xFF166534)
                      : ShelfColors.muted,
                  height: 1.4,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.description,
    required this.children,
  });

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(color: ShelfColors.muted, height: 1.4),
        ),
        if (children.isNotEmpty) const SizedBox(height: 16),
        ...children,
      ],
    );
  }
}

class _SettingsSubhead extends StatelessWidget {
  const _SettingsSubhead({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: ShelfColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: ShelfColors.hairline),
      ),
      child: child,
    );
  }
}
