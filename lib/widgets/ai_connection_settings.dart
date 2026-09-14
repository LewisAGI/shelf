import 'package:flutter/material.dart';

import '../models/ai_provider.dart';
import '../services/ai_settings_controller.dart';
import '../theme/shelf_theme.dart';
import 'ai_scope.dart';

const _customModelValue = '__shelf_custom_model__';

/// BYO AI block. Keys go to Keychain / Android Keystore per provider; Shelf never spends house tokens.
class AiConnectionSettings extends StatefulWidget {
  const AiConnectionSettings({super.key});

  @override
  State<AiConnectionSettings> createState() => _AiConnectionSettingsState();
}

class _AiConnectionSettingsState extends State<AiConnectionSettings> {
  late final TextEditingController _endpoint;
  late final TextEditingController _customModel;
  late final TextEditingController _apiKey;
  AiSettingsController? _ai;
  var _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _endpoint = TextEditingController();
    _customModel = TextEditingController();
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
    _customModel.dispose();
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
    if (ai.isCustomModel && _customModel.text != ai.model) {
      _customModel.value = TextEditingValue(
        text: ai.model,
        selection: TextSelection.collapsed(offset: ai.model.length),
      );
    }
  }

  Future<void> _commitPending(AiSettingsController ai) async {
    if (_apiKey.text.trim().isNotEmpty) {
      await ai.saveApiKey(_apiKey.text);
      _apiKey.clear();
    }
    if (ai.provider.allowsCustomBaseUrl) {
      await ai.setBaseUrl(_endpoint.text);
    }
    if (ai.isCustomModel) {
      await ai.setModel(_customModel.text);
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
        final known = ai.provider.knownModels;
        final modelValue = known.contains(ai.model) ? ai.model : _customModelValue;
        return _SettingsSection(
          title: 'Connect your own AI',
          description:
              'Bring your own key. Shelf calls your provider from this phone — there is no house-paid AI and no shared backend spend. Switching provider keeps each key and model.',
          children: [
            _SettingsCard(
              child: Column(
                children: [
                  Padding(
                    key: const Key('settings-ai-provider'),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: DropdownButtonFormField<AiProvider>(
                      key: ValueKey('settings-ai-provider-field-${ai.provider.id}'),
                      initialValue: ai.provider,
                      decoration: const InputDecoration(
                        labelText: 'Provider',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                      ),
                      items: [
                        for (final provider in AiProvider.values)
                          DropdownMenuItem(
                            key: Key('settings-ai-provider-${provider.id}'),
                            value: provider,
                            child: Text(provider.label),
                          ),
                      ],
                      onChanged: ai.busy
                          ? null
                          : (value) async {
                              if (value != null) {
                                await ai.setProvider(value);
                              }
                            },
                    ),
                  ),
                  if (ai.provider.allowsCustomBaseUrl) ...[
                    const Divider(height: 1, indent: 16, endIndent: 16),
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
                    ),
                  ],
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
                            ? 'Saved in secure storage — paste to replace'
                            : 'Paste your provider key',
                        suffixIcon: IconButton(
                          key: const Key('settings-ai-toggle-key'),
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
                            child: const Text('Save key'),
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
                    key: const Key('settings-ai-model'),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(
                        'settings-ai-model-field-${ai.provider.id}-$modelValue',
                      ),
                      initialValue: modelValue,
                      decoration: const InputDecoration(
                        labelText: 'Model',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                      ),
                      items: [
                        for (final model in known)
                          DropdownMenuItem(value: model, child: Text(model)),
                        const DropdownMenuItem(
                          value: _customModelValue,
                          child: Text('Custom'),
                        ),
                      ],
                      onChanged: ai.busy
                          ? null
                          : (value) async {
                              if (value == null) {
                                return;
                              }
                              if (value == _customModelValue) {
                                final current = ai.isCustomModel
                                    ? ai.model
                                    : '';
                                _customModel.text = current;
                                await ai.setModel(
                                  current.isEmpty ? 'custom-model' : current,
                                );
                              } else {
                                await ai.setModel(value);
                              }
                            },
                    ),
                  ),
                  if (ai.isCustomModel)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: TextField(
                        key: const Key('settings-ai-custom-model'),
                        controller: _customModel,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Custom model',
                          hintText: 'provider-model-id',
                          helperText:
                              'A custom name may error if the provider does not recognise it.',
                          helperMaxLines: 3,
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
                      await _commitPending(ai);
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
