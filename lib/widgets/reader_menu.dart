import 'package:flutter/material.dart';

import 'shelf_menu_label.dart';

/// Reader ⋮ menu: marker visibility and the chapters sheet.
class ReaderOverflowMenu extends StatelessWidget {
  const ReaderOverflowMenu({
    super.key,
    required this.showMarkers,
    required this.onToggleMarkers,
    required this.onChapters,
  });

  final bool showMarkers;
  final VoidCallback onToggleMarkers;
  final VoidCallback onChapters;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: const Key('reader-overflow-menu'),
      tooltip: 'Reader menu',
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        switch (value) {
          case 'markers':
            onToggleMarkers();
          case 'chapters':
            onChapters();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          key: const Key('reader-menu-markers'),
          value: 'markers',
          child: ShelfMenuLabel(
            icon: showMarkers
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            label: showMarkers ? 'Hide markers' : 'Show markers',
          ),
        ),
        const PopupMenuItem(
          key: Key('reader-menu-chapters'),
          value: 'chapters',
          child: ShelfMenuLabel(
            icon: Icons.list_alt_outlined,
            label: 'Chapters',
          ),
        ),
      ],
    );
  }
}
