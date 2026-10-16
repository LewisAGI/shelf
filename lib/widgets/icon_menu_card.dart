import 'package:flutter/material.dart';

import '../theme/shelf_theme.dart';

/// One row in a Shelf icon menu (Perplexity / Matter card, Shelf colours).
class IconMenuEntry<T> {
  const IconMenuEntry({
    required this.value,
    required this.icon,
    required this.label,
    this.entryKey,
    this.dividerBefore = false,
    this.destructive = false,
  });

  final T value;
  final IconData icon;
  final String label;
  final Key? entryKey;
  final bool dividerBefore;
  final bool destructive;
}

/// White rounded card of icon + label rows. Anchored near a press point.
class IconMenuCard<T> extends StatelessWidget {
  const IconMenuCard({
    super.key,
    required this.entries,
    required this.onSelected,
    this.menuKey,
  });

  final List<IconMenuEntry<T>> entries;
  final ValueChanged<T>? onSelected;
  final Key? menuKey;

  static const double width = 248;

  static Future<T?> show<T>(
    BuildContext context, {
    required Offset globalPosition,
    required List<IconMenuEntry<T>> entries,
    Key? menuKey,
  }) {
    final media = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final dividers = entries.where((entry) => entry.dividerBefore).length;
    final menuHeight = 12.0 + (entries.length * 48) + (dividers * 9);
    var left = globalPosition.dx - 24;
    var top = globalPosition.dy - menuHeight - 8;
    left = left.clamp(
      padding.left + 8,
      media.width - width - padding.right - 8,
    );
    top = top.clamp(
      padding.top + 8,
      media.height - menuHeight - padding.bottom - 8,
    );

    return showDialog<T>(
      context: context,
      barrierColor: Colors.black26,
      builder: (context) {
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: IconMenuCard<T>(
                menuKey: menuKey,
                entries: entries,
                onSelected: (value) => Navigator.of(context).pop(value),
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
      key: menuKey,
      color: ShelfColors.white,
      elevation: 12,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: width, maxWidth: width),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final entry in entries) ...[
                if (entry.dividerBefore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Divider(height: 1, thickness: 1, color: ShelfColors.hairline),
                  ),
                TextButton(
                  key: entry.entryKey,
                  onPressed: onSelected == null
                      ? null
                      : () => onSelected!(entry.value),
                  style: TextButton.styleFrom(
                    foregroundColor: entry.destructive
                        ? const Color(0xFFB91C1C)
                        : ShelfColors.ink,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minimumSize: const Size(width, 48),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: const RoundedRectangleBorder(),
                  ),
                  child: Row(
                    children: [
                      Icon(entry.icon, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
