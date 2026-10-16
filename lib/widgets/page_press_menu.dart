import 'package:flutter/material.dart';

import 'icon_menu_card.dart';

/// Long-press on a PDF page offers exactly these two actions.
enum PagePressAction { comment, selectText }

/// Comment | Select text as an icon card. Long-press does not create a note.
class PagePressMenu extends StatelessWidget {
  const PagePressMenu({super.key, this.onSelected});

  final ValueChanged<PagePressAction>? onSelected;

  static const commentLabel = 'Comment';
  static const selectTextLabel = 'Select text';

  static const entries = <IconMenuEntry<PagePressAction>>[
    IconMenuEntry(
      value: PagePressAction.comment,
      entryKey: Key('pdf-page-action-comment'),
      icon: Icons.mode_comment_outlined,
      label: commentLabel,
    ),
    IconMenuEntry(
      value: PagePressAction.selectText,
      entryKey: Key('pdf-page-action-select-text'),
      icon: Icons.text_fields,
      label: selectTextLabel,
    ),
  ];

  static Future<PagePressAction?> show(
    BuildContext context, {
    required Offset globalPosition,
  }) {
    return IconMenuCard.show<PagePressAction>(
      context,
      globalPosition: globalPosition,
      menuKey: const Key('pdf-page-action-menu'),
      entries: entries,
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconMenuCard<PagePressAction>(
      menuKey: const Key('pdf-page-action-menu'),
      entries: entries,
      onSelected: onSelected,
    );
  }
}
