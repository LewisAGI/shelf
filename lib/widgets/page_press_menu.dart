import 'package:flutter/material.dart';

import '../theme/shelf_theme.dart';

/// Long-press on a PDF page offers exactly these two actions.
enum PagePressAction { comment, selectText }

/// Compact Comment | Select text menu. Long-press does not create a note.
class PagePressMenu extends StatelessWidget {
  const PagePressMenu({super.key, this.onSelected});

  final ValueChanged<PagePressAction>? onSelected;

  static const commentLabel = 'Comment';
  static const selectTextLabel = 'Select text';

  static Future<PagePressAction?> show(
    BuildContext context, {
    required Offset globalPosition,
  }) {
    final media = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    const menuWidth = 248.0;
    const menuHeight = 48.0;
    var left = globalPosition.dx - (menuWidth / 2);
    var top = globalPosition.dy - menuHeight - 12;
    left = left.clamp(
      padding.left + 8,
      media.width - menuWidth - padding.right - 8,
    );
    top = top.clamp(
      padding.top + 8,
      media.height - menuHeight - padding.bottom - 8,
    );

    return showDialog<PagePressAction>(
      context: context,
      barrierColor: Colors.black26,
      builder: (context) {
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: PagePressMenu(
                onSelected: (action) => Navigator.of(context).pop(action),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('pdf-page-action-menu'),
      color: ShelfColors.white,
      elevation: 8,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 48,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionButton(
              key: const Key('pdf-page-action-comment'),
              label: commentLabel,
              onPressed: () => onSelected?.call(PagePressAction.comment),
            ),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: ShelfColors.hairline,
            ),
            _ActionButton(
              key: const Key('pdf-page-action-select-text'),
              label: selectTextLabel,
              onPressed: () => onSelected?.call(PagePressAction.selectText),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: ShelfColors.ink,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        minimumSize: const Size(110, 48),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
