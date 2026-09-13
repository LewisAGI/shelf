import 'package:flutter/material.dart';

import '../data/shelf_store.dart';
import '../models/note.dart';
import '../theme/shelf_theme.dart';
import '../widgets/colour_label_chip.dart';
import 'reader_screen.dart';

class NotesHubScreen extends StatefulWidget {
  const NotesHubScreen({super.key, required this.store});

  final ShelfStore store;

  @override
  State<NotesHubScreen> createState() => _NotesHubScreenState();
}

class _NotesHubScreenState extends State<NotesHubScreen> {
  final _query = TextEditingController();
  String? _labelId;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final notes = widget.store.searchNotes(
            query: _query.text,
            colorLabelId: _labelId,
          );
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search notes, titles, labels…',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _labelId == null,
                      onSelected: (_) => setState(() => _labelId = null),
                      selectedColor: ShelfColors.orangeSoft,
                      checkmarkColor: ShelfColors.orange,
                    ),
                    const SizedBox(width: 8),
                    for (final label in widget.store.labels) ...[
                      ColourLabelChip(
                        label: label,
                        selected: _labelId == label.id,
                        onTap: () => setState(() => _labelId = label.id),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: notes.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'No notes match. Long-press a page in the reader to add one.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: ShelfColors.muted),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: notes.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return _NoteTile(
                            store: widget.store,
                            note: notes[index],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.store, required this.note});

  final ShelfStore store;
  final Note note;

  @override
  Widget build(BuildContext context) {
    final document = store.documentById(note.documentId);
    final label = store.labelById(note.colorLabelId);
    final preview = note.text.trim().isEmpty ? 'Empty note' : note.text.trim();
    return Material(
      color: ShelfColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: ShelfColors.hairline),
      ),
      child: ListTile(
        leading: ColourDot(color: label.color, size: 16),
        title: Text(
          preview,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            document?.title ?? 'Missing PDF',
            'Page ${note.page}',
            label.name,
          ].join(' · '),
        ),
        enabled: document != null,
        onTap: document == null
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReaderScreen(
                      store: store,
                      document: document,
                      initialPage: note.page,
                      focusNoteId: note.id,
                    ),
                  ),
                );
              },
      ),
    );
  }
}
