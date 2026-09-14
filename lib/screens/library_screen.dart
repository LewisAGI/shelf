import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/shelf_store.dart';
import '../models/color_label.dart';
import '../models/library_document.dart';
import '../models/note.dart';
import '../services/export_share.dart';
import '../services/notes_export.dart';
import '../services/pdf_outline_source.dart';
import '../services/pdf_section_resolver.dart';
import '../theme/shelf_theme.dart';
import '../widgets/ask_about_note.dart';
import 'reader_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({
    super.key,
    required this.store,
    this.onViewAllComments,
  });

  final ShelfStore store;
  final ValueChanged<String>? onViewAllComments;

  Future<void> _import(BuildContext context) async {
    final document = await store.importPdf();
    if (!context.mounted) {
      return;
    }
    if (store.lastError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(store.lastError!)));
    }
    if (document != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReaderScreen(store: store, document: document),
        ),
      );
    }
  }

  static const highlightTip =
      'Highlights read more clearly on black-and-white or light-background PDFs.';

  static Future<void> exportDocumentComments({
    required LibraryDocument document,
    required List<Note> notes,
    required ColorLabel Function(String id) labelById,
    Directory? directory,
    List<PdfSection> outline = const [],
    BuildContext? shareContext,
    GlobalKey? shareKey,
    Rect? sharePositionOrigin,
  }) async {
    final origin = ShareOrigin.resolve(
      preferred: sharePositionOrigin,
      context: shareContext,
      key: shareKey,
    );
    final files = await NotesExport.writeFiles(
      document: document,
      notes: notes,
      labelById: labelById,
      directory: directory,
      outline: outline,
    );
    await ExportShare.files(
      files,
      subject: 'Shelf notes — ${document.title}',
      sharePositionOrigin: origin,
    );
  }

  Future<void> _exportComments(
    BuildContext context,
    LibraryDocument document,
  ) async {
    // Snapshot the ⋮ button before the async outline/file work. iOS share
    // rejects a zero origin; this is the menu anchor (or a safe fallback).
    final origin = ShareOrigin.resolve(context: context);
    try {
      final outline = await PdfOutlineSource.loadForDocument(
        document,
        store.pdfPath,
      );
      await exportDocumentComments(
        document: document,
        notes: store.notesForDocument(document.id),
        labelById: store.labelById,
        outline: outline,
        sharePositionOrigin: origin,
      );
    } on Object catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export comments: $error')),
      );
    }
  }

  Future<void> _sendToAi(
    BuildContext context,
    LibraryDocument document,
  ) async {
    final notes = store.notesForDocument(document.id);
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This book has no comments yet.')),
      );
      return;
    }
    await AskAboutNoteButton.open(
      context,
      noteText: 'Notes from ${document.title}',
      documentTitle: document.title,
      notesToResolve: notes,
      labelById: store.labelById,
      loadSections: () => PdfOutlineSource.loadForDocument(
        document,
        store.pdfPath,
      ),
      offerPdf: true,
      pdfFileName: '${document.title}.pdf',
      loadPdf: () async {
        try {
          final path = await store.pdfPath(document);
          return await File(path).readAsBytes();
        } on Object {
          return null;
        }
      },
    );
  }

  void _onMenu(
    BuildContext context,
    LibraryDocument document,
    String value,
  ) {
    switch (value) {
      case 'export':
        unawaited(_exportComments(context, document));
      case 'send':
        unawaited(_sendToAi(context, document));
      case 'view':
        onViewAllComments?.call(document.title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM y');
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          if (store.documents.isEmpty) {
            return _EmptyLibrary(onImport: () => _import(context));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(
                  highlightTip,
                  key: Key('library-highlight-tip'),
                  style: TextStyle(
                    color: ShelfColors.muted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: store.documents.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final document = store.documents[index];
                    final noteCount = store.notesForDocument(document.id).length;
                    return Dismissible(
                      key: ValueKey(document.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: const Color(0xFFB91C1C),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                        ),
                      ),
                      confirmDismiss: (_) async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Remove from library?'),
                            content: Text(
                              '“${document.title}” and its notes will be deleted from this phone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Keep'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Remove'),
                              ),
                            ],
                          ),
                        );
                        return confirmed ?? false;
                      },
                      onDismissed: (_) => store.removeDocument(document),
                      child: Material(
                        color: ShelfColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: ShelfColors.hairline),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: const Icon(
                            Icons.picture_as_pdf_outlined,
                            color: ShelfColors.orange,
                            size: 32,
                          ),
                          title: Text(document.title),
                          subtitle: Text(
                            [
                              'Imported ${dateFormat.format(document.importedAt)}',
                              if (document.pageCount != null)
                                '${document.pageCount} pages',
                              '$noteCount ${noteCount == 1 ? 'note' : 'notes'}',
                            ].join(' · '),
                          ),
                          trailing: Builder(
                            builder: (menuContext) {
                              return PopupMenuButton<String>(
                                key: Key('library-card-menu-${document.id}'),
                                tooltip: 'Book actions',
                                onSelected: (value) =>
                                    _onMenu(menuContext, document, value),
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    key: Key('library-card-export-comments'),
                                    value: 'export',
                                    child: Text('Export comments'),
                                  ),
                                  PopupMenuItem(
                                    key: Key('library-card-send-to-ai'),
                                    value: 'send',
                                    child: Text('Send to connected AI'),
                                  ),
                                  PopupMenuItem(
                                    key: Key('library-card-view-comments'),
                                    value: 'view',
                                    child: Text('View all comments'),
                                  ),
                                ],
                              );
                            },
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ReaderScreen(
                                  store: store,
                                  document: document,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _import(context),
        icon: const Icon(Icons.add),
        label: const Text('Import PDF'),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.menu_book_outlined,
              size: 56,
              color: ShelfColors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              'Your shelf is empty',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Import a learning PDF from Files. Notes you dictate stay on this phone.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ShelfColors.muted, height: 1.4),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.add),
              label: const Text('Import a PDF'),
            ),
          ],
        ),
      ),
    );
  }
}
