import 'dart:io';

import 'package:flutter/material.dart';

import '../data/shelf_store.dart';
import '../models/note.dart';
import '../services/note_page_target.dart';
import '../services/pdf_outline_source.dart';
import '../theme/shelf_theme.dart';
import '../widgets/ask_about_note.dart';
import '../widgets/colour_label_chip.dart';
import 'reader_screen.dart';

class NotesHubScreen extends StatefulWidget {
  const NotesHubScreen({
    super.key,
    required this.store,
    this.searchController,
  });

  final ShelfStore store;
  final TextEditingController? searchController;

  @override
  State<NotesHubScreen> createState() => _NotesHubScreenState();
}

class _NotesHubScreenState extends State<NotesHubScreen> {
  late final TextEditingController _query;
  var _ownsQuery = false;
  String? _labelId;

  @override
  void initState() {
    super.initState();
    final incoming = widget.searchController;
    if (incoming != null) {
      _query = incoming;
    } else {
      _query = TextEditingController();
      _ownsQuery = true;
    }
    _query.addListener(_onQueryChanged);
  }

  void _onQueryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _query.removeListener(_onQueryChanged);
    if (_ownsQuery) {
      _query.dispose();
    }
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
                  key: const Key('notes-hub-search'),
                  controller: _query,
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
                            'No notes match. Long-press a page, then Comment or Select text.',
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
        trailing: IconButton(
          key: Key('ask-about-note-${note.id}'),
          tooltip: 'Ask about this note',
          icon: const Icon(Icons.auto_awesome_outlined),
          onPressed: () {
            AskAboutNoteButton.open(
              context,
              noteText: note.text,
              selectedText: note.selection?.text,
              documentTitle: document?.title,
              page: note.page,
              note: note,
              loadSections: document == null
                  ? null
                  : () => PdfOutlineSource.loadForDocument(
                      document,
                      store.pdfPath,
                    ),
              offerPdf: document != null,
              pdfFileName: document == null ? null : '${document.title}.pdf',
              loadPdf: document == null
                  ? null
                  : () async {
                      try {
                        final path = await store.pdfPath(document);
                        return await File(path).readAsBytes();
                      } on Object {
                        return null;
                      }
                    },
            );
          },
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
                      initialPage: NotePageTarget.forNoteOpen(note: note),
                      focusNoteId: note.id,
                    ),
                  ),
                );
              },
      ),
    );
  }
}
