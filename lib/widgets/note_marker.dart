import 'package:flutter/material.dart';

import '../theme/shelf_theme.dart';

class NoteMarker extends StatelessWidget {
  const NoteMarker({
    super.key,
    required this.color,
    this.focused = false,
    this.size = 16,
  });

  final Color color;
  final bool focused;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: focused ? ShelfColors.ink : Colors.white,
          width: focused ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: focused ? 0.28 : 0.16),
            blurRadius: focused ? 8 : 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}
