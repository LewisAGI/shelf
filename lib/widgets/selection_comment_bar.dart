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
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 232, maxWidth: 280),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                key: const Key('pdf-selection-add-comment'),
                onPressed: hasSelection ? onAddComment : null,
                icon: const Icon(Icons.add_comment_outlined, size: 20),
                label: const Text('Add comment'),
                style: FilledButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  minimumSize: const Size(216, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              TextButton.icon(
                key: const Key('pdf-selection-done'),
                onPressed: onDone,
                icon: const Icon(Icons.check, size: 20),
                label: const Text('Done'),
                style: TextButton.styleFrom(
                  foregroundColor: ShelfColors.ink,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  minimumSize: const Size(216, 48),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
