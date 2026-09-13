import 'package:flutter/material.dart';

import '../theme/shelf_theme.dart';

/// Shown while pdfrx text-selection handles are active.
class SelectionCommentBar extends StatelessWidget {
  const SelectionCommentBar({
    super.key,
    required this.hasSelection,
    required this.onAddComment,
    required this.onDone,
  });

  final bool hasSelection;
  final VoidCallback onAddComment;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('pdf-selection-comment-bar'),
      color: ShelfColors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Drag the handles to widen the word.',
                style: TextStyle(fontSize: 13, color: ShelfColors.muted),
              ),
            ),
            TextButton(
              key: const Key('pdf-selection-done'),
              onPressed: onDone,
              child: const Text('Done'),
            ),
            FilledButton(
              key: const Key('pdf-selection-add-comment'),
              onPressed: hasSelection ? onAddComment : null,
              child: const Text('Add comment'),
            ),
          ],
        ),
      ),
    );
  }
}
