import 'package:flutter/material.dart';

import '../theme/shelf_theme.dart';

/// Shown while pdfrx text-selection handles are active.
///
/// Icon card: Add comment and Done. No on-screen instruction.
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
      elevation: 12,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const Key('pdf-selection-add-comment'),
              tooltip: 'Add comment',
              onPressed: hasSelection ? onAddComment : null,
              icon: const Icon(Icons.add_comment_outlined),
            ),
            IconButton(
              key: const Key('pdf-selection-done'),
              tooltip: 'Done',
              color: ShelfColors.ink,
              onPressed: onDone,
              icon: const Icon(Icons.check),
            ),
          ],
        ),
      ),
    );
  }
}
