import 'package:flutter/material.dart';

import '../data/shelf_database.dart';
import '../data/shelf_store.dart';
import '../models/color_label.dart';
import '../theme/shelf_theme.dart';
import '../widgets/ai_connection_settings.dart';
import '../widgets/colour_label_chip.dart';

const _palette = <String>[
  ShelfColors.defaultOrangeHex,
  ShelfColors.defaultPurpleHex,
  '#0F766E',
  '#1D4ED8',
  '#B45309',
  '#BE123C',
  '#365314',
  '#334155',
];

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.store});

  final ShelfStore store;

  Future<void> _edit(BuildContext context, {ColorLabel? label}) async {
    final created = await showModalBottomSheet<ColorLabel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ShelfColors.white,
      builder: (context) => _LabelEditor(
        label: label,
        nextSort: store.labels.length,
        makeDefault: label == null && store.labels.isEmpty,
      ),
    );
    if (created != null) {
      await store.saveLabel(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _SettingsSection(
                title: 'Colour labels',
                description:
                    'Markers on the page use these colours. New notes start on the default — orange, unless you change it.',
                children: [
                  for (final label in store.labels)
                    _SettingsCard(
                      child: ListTile(
                        leading: ColourDot(color: label.color, size: 18),
                        title: Text(label.name),
                        subtitle: Text(
                          [
                            label.meaning,
                            if (label.isDefault) 'Default for new notes',
                          ].join('\n'),
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') {
                              await _edit(context, label: label);
                            } else if (value == 'default') {
                              await store.saveLabel(
                                label.copyWith(isDefault: true),
                              );
                            } else if (value == 'delete') {
                              await store.deleteLabel(label);
                              if (context.mounted && store.lastError != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(store.lastError!)),
                                );
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            if (!label.isDefault)
                              const PopupMenuItem(
                                value: 'default',
                                child: Text('Make default'),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                        onTap: () => _edit(context, label: label),
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _edit(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add a colour label'),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const AiConnectionSettings(),
              const SizedBox(height: 28),
              _SettingsSection(
                title: 'About',
                description:
                    'Shelf keeps PDFs and notes on this iPhone only. No cloud sync and no accounts in this version.',
                children: const [],
              ),
            ],
          );
        },
      ),
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

class _LabelEditor extends StatefulWidget {
  const _LabelEditor({
    required this.label,
    required this.nextSort,
    required this.makeDefault,
  });

  final ColorLabel? label;
  final int nextSort;
  final bool makeDefault;

  @override
  State<_LabelEditor> createState() => _LabelEditorState();
}

class _LabelEditorState extends State<_LabelEditor> {
  late final TextEditingController _name;
  late final TextEditingController _meaning;
  late String _hex;
  late bool _isDefault;

  @override
  void initState() {
    super.initState();
    final label = widget.label;
    _name = TextEditingController(text: label?.name ?? '');
    _meaning = TextEditingController(text: label?.meaning ?? '');
    _hex = label?.hex ?? ShelfColors.defaultOrangeHex;
    _isDefault = label?.isDefault ?? widget.makeDefault;
  }

  @override
  void dispose() {
    _name.dispose();
    _meaning.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.label == null ? 'New colour label' : 'Edit colour label',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _meaning,
            decoration: const InputDecoration(
              labelText: 'Meaning',
              hintText: 'What this colour stands for',
            ),
          ),
          const SizedBox(height: 16),
          const Text('Colour'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final hex in _palette)
                GestureDetector(
                  onTap: () => setState(() => _hex = hex),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: ColorLabel.parseHex(hex),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _hex.toUpperCase() == hex.toUpperCase()
                            ? ShelfColors.ink
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Default for new notes'),
            value: _isDefault,
            activeThumbColor: ShelfColors.orange,
            onChanged: (value) => setState(() => _isDefault = value),
          ),
          FilledButton(
            onPressed: () {
              final name = _name.text.trim();
              if (name.isEmpty) {
                return;
              }
              Navigator.of(context).pop(
                ColorLabel(
                  id: widget.label?.id ?? ShelfDatabase.newId(),
                  name: name,
                  meaning: _meaning.text.trim(),
                  hex: _hex,
                  isDefault: _isDefault,
                  sortOrder: widget.label?.sortOrder ?? widget.nextSort,
                ),
              );
            },
            child: const Text('Save label'),
          ),
        ],
      ),
    );
  }
}
