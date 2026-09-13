import 'package:flutter/material.dart';

import '../models/ai_provider.dart';
import '../models/note.dart';
import '../services/ai_client.dart';
import '../theme/shelf_theme.dart';
import 'ai_scope.dart';

/// One in-app action: send the current note and/or selected page text
/// to the user's provider and show the reply.
class AskAboutNoteButton extends StatelessWidget {
  const AskAboutNoteButton({
    super.key,
    required this.noteText,
    this.selectedText,
    this.documentTitle,
    this.page,
    this.compact = false,
  });

  /// Read at tap time so the composer field is current.
  final String Function() noteText;
  final String? selectedText;
  final String? documentTitle;
  final int? page;
  final bool compact;

  static AiAskRequest requestFor({
    required String noteText,
    String? selectedText,
    String? documentTitle,
    int? page,
    Note? note,
  }) {
    return AiAskRequest(
      noteText: noteText.trim().isNotEmpty
          ? noteText
          : (note?.text ?? ''),
      selectedText: selectedText ?? note?.selection?.text,
      documentTitle: documentTitle,
      page: page ?? note?.page,
    );
  }

  static Future<void> open(
    BuildContext context, {
    required String noteText,
    String? selectedText,
    String? documentTitle,
    int? page,
    Note? note,
  }) async {
    final ai = AiScope.maybeOf(context);
    if (ai == null || !ai.hasApiKey) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add your own API key in Settings. Shelf does not ship a house key.',
          ),
        ),
      );
      return;
    }
    final request = requestFor(
      noteText: noteText,
      selectedText: selectedText,
      documentTitle: documentTitle,
      page: page,
      note: note,
    );
    if (!request.hasAnythingToAsk) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write a note or select text first.')),
      );
      return;
    }
    await AskAboutNoteSheet.show(
      context,
      ask: () => ai.askAbout(request),
    );
  }

  Future<void> _ask(BuildContext context) {
    return open(
      context,
      noteText: noteText(),
      selectedText: selectedText,
      documentTitle: documentTitle,
      page: page,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return TextButton(
        key: const Key('ask-about-note'),
        onPressed: () => _ask(context),
        child: const Text(
          'Ask about this note',
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    return OutlinedButton.icon(
      key: const Key('ask-about-note'),
      onPressed: () => _ask(context),
      icon: const Icon(Icons.auto_awesome_outlined, size: 18),
      label: const Text('Ask about this note'),
    );
  }
}

class AskAboutNoteSheet extends StatefulWidget {
  const AskAboutNoteSheet({super.key, required this.ask});

  final Future<String> Function() ask;

  static Future<void> show(
    BuildContext context, {
    required Future<String> Function() ask,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: ShelfColors.white,
      builder: (context) => AskAboutNoteSheet(ask: ask),
    );
  }

  @override
  State<AskAboutNoteSheet> createState() => _AskAboutNoteSheetState();
}

class _AskAboutNoteSheetState extends State<AskAboutNoteSheet> {
  String? _reply;
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final reply = await widget.ask();
      if (!mounted) {
        return;
      }
      setState(() {
        _reply = reply;
        _loading = false;
      });
    } on AiClientException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Could not reach the provider.';
        _loading = false;
      });
    }
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
            'Ask about this note',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Text(
              key: const Key('ask-about-note-error'),
              _error!,
              style: const TextStyle(color: ShelfColors.muted, height: 1.4),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: SingleChildScrollView(
                child: Text(
                  key: const Key('ask-about-note-result'),
                  _reply ?? '',
                  style: const TextStyle(height: 1.45),
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
