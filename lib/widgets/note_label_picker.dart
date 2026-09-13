import 'package:flutter/material.dart';

import '../models/color_label.dart';
import '../theme/shelf_theme.dart';
import 'colour_label_chip.dart';

/// Compact colour-label control for the note composer.
///
/// One tap assigns an existing Settings label. The selected colour is
/// shown as a ring so it stays obvious on a small composer.
class NoteLabelPicker extends StatelessWidget {
  const NoteLabelPicker({
    super.key,
    required this.labels,
    required this.selectedId,
    required this.onSelected,
  });

  final List<ColorLabel> labels;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) {
      return const Text(
        'No colour labels yet. Add them in Settings.',
        style: TextStyle(color: ShelfColors.muted, fontSize: 13),
      );
    }

    final selected = labels.cast<ColorLabel?>().firstWhere(
      (label) => label?.id == selectedId,
      orElse: () => labels.first,
    )!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Label',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: ShelfColors.muted,
              ),
            ),
            const SizedBox(width: 8),
            ColourDot(color: selected.color, size: 10),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                selected.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: labels.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final label = labels[index];
              final isSelected = label.id == selectedId;
              return _LabelSwatch(
                key: Key('note-label-${label.id}'),
                label: label,
                selected: isSelected,
                onTap: () => onSelected(label.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LabelSwatch extends StatelessWidget {
  const _LabelSwatch({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ColorLabel label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label.meaning.isEmpty ? label.name : '${label.name}: ${label.meaning}',
      child: Material(
        color: selected ? ShelfColors.orangeSoft : ShelfColors.white,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? ShelfColors.orange : ShelfColors.hairline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ColourDot(color: label.color, size: 14),
                const SizedBox(width: 6),
                Text(
                  label.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: ShelfColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
