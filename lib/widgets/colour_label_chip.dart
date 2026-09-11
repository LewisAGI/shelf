import 'package:flutter/material.dart';

import '../models/color_label.dart';
import '../theme/shelf_theme.dart';

class ColourLabelChip extends StatelessWidget {
  const ColourLabelChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final ColorLabel label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      onSelected: onTap == null ? null : (_) => onTap!(),
      avatar: CircleAvatar(backgroundColor: label.color, radius: 8),
      label: Text(label.name),
      selectedColor: ShelfColors.orangeSoft,
      checkmarkColor: ShelfColors.orange,
      side: BorderSide(
        color: selected ? ShelfColors.orange : ShelfColors.hairline,
      ),
    );
  }
}

class ColourDot extends StatelessWidget {
  const ColourDot({super.key, required this.color, this.size = 12});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
      ),
    );
  }
}
