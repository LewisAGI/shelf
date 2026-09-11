import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/shelf_store.dart';
import '../theme/shelf_theme.dart';
import 'reader_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, required this.store});

  final ShelfStore store;

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
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
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
                  child: const Icon(Icons.delete_outline, color: Colors.white),
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
