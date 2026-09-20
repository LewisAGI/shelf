import 'package:flutter/material.dart';

import '../services/notes_export.dart';
import '../theme/shelf_theme.dart';

enum AskNoteAction { ask, export }

/// First tap on Ask AI: ask with a connected provider, or share the note.
class AskNoteChooserSheet extends StatelessWidget {
  const AskNoteChooserSheet({super.key});

  static Future<AskNoteAction?> show(BuildContext context) {
    return showModalBottomSheet<AskNoteAction>(
      context: context,
      backgroundColor: ShelfColors.white,
      builder: (context) => const AskNoteChooserSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Ask AI',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ListTile(
              key: const Key('ask-with-your-ai'),
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Ask with your AI'),
              onTap: () => Navigator.pop(context, AskNoteAction.ask),
            ),
            ListTile(
              key: const Key('export-share-note'),
              leading: const Icon(Icons.ios_share_outlined),
              title: const Text('Export / Share note'),
              onTap: () => Navigator.pop(context, AskNoteAction.export),
            ),
          ],
        ),
      ),
    );
  }
}

/// Four single-note share bundles — names match the share sheet contents.
class SingleNoteExportSheet extends StatelessWidget {
  const SingleNoteExportSheet({super.key});

  static Future<SingleNoteShareKind?> show(BuildContext context) {
    return showModalBottomSheet<SingleNoteShareKind>(
      context: context,
      backgroundColor: ShelfColors.white,
      builder: (context) => const SingleNoteExportSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Export / Share note',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ListTile(
              key: const Key('export-note-pdf-guide'),
              title: const Text('Note + PDF + guide'),
              onTap: () =>
                  Navigator.pop(context, SingleNoteShareKind.notePdfGuide),
            ),
            ListTile(
              key: const Key('export-note-pdf'),
              title: const Text('Note + PDF'),
              onTap: () => Navigator.pop(context, SingleNoteShareKind.notePdf),
            ),
            ListTile(
              key: const Key('export-note-guide'),
              title: const Text('Note + guide'),
              onTap: () =>
                  Navigator.pop(context, SingleNoteShareKind.noteGuide),
            ),
            ListTile(
              key: const Key('export-note-only'),
              title: const Text('Note only'),
              onTap: () => Navigator.pop(context, SingleNoteShareKind.noteOnly),
            ),
          ],
        ),
      ),
    );
  }
}
