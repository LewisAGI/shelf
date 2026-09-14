import 'package:flutter/material.dart';

import '../theme/shelf_theme.dart';

enum AiSendScope { notesOnly, includePdf }

/// Include PDF? vs Notes only — used for a book or a single note.
class AiSendScopeDialog extends StatelessWidget {
  const AiSendScopeDialog({
    super.key,
    required this.title,
    this.message =
        'They may already have the PDF. Attach it only if the connected provider can use it.',
  });

  final String title;
  final String message;

  static Future<AiSendScope?> show(
    BuildContext context, {
    String title = 'Send to connected AI',
    String? message,
  }) {
    return showDialog<AiSendScope>(
      context: context,
      builder: (context) => AiSendScopeDialog(
        title: title,
        message: message ??
            'They may already have the PDF. Attach it only if the connected provider can use it.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('ai-send-scope-dialog'),
      backgroundColor: ShelfColors.white,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('ai-send-scope-notes-only'),
          onPressed: () => Navigator.of(context).pop(AiSendScope.notesOnly),
          child: const Text('Notes only'),
        ),
        FilledButton(
          key: const Key('ai-send-scope-include-pdf'),
          onPressed: () => Navigator.of(context).pop(AiSendScope.includePdf),
          child: const Text('Include PDF'),
        ),
      ],
    );
  }
}
