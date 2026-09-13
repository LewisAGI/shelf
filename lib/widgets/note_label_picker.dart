import 'package:flutter/material.dart';

import '../models/color_label.dart';
import '../theme/shelf_theme.dart';

/// Clickable colour square on the composer pill.
///
/// Tap opens a vertical list of Settings labels. The square fill is the
/// currently assigned colour (orange by default).
class NoteLabelPicker extends StatelessWidget {
  const NoteLabelPicker({
    super.key,
    required this.labels,
    required this.selectedId,
    required this.onSelected,
  });

  static const double squareSize = 28;

  final List<ColorLabel> labels;
  final String selectedId;
  final ValueChanged<String> onSelected;

  ColorLabel get _selected {
    if (labels.isEmpty) {
      return ColorLabel.seedDefaults().first;
    }
    return labels.cast<ColorLabel?>().firstWhere(
          (label) => label?.id == selectedId,
          orElse: () => labels.first,
        )!;
  }

  Future<void> _openPicker(BuildContext context) async {
    if (labels.isEmpty) {
      return;
    }
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: ShelfColors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text(
                    'Colour',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                for (final label in labels)
                  ListTile(
                    key: Key('note-label-${label.id}'),
                    leading: _ColourSquare(
                      color: label.color,
                      selected: label.id == selectedId,
                      size: 22,
                    ),
                    title: Text(label.name),
                    subtitle: label.meaning.isEmpty
                        ? null
                        : Text(
                            label.meaning,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                    selected: label.id == selectedId,
                    onTap: () => Navigator.of(context).pop(label.id),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (chosen != null) {
      onSelected(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Tooltip(
      message: selected.meaning.isEmpty
          ? selected.name
          : '${selected.name}: ${selected.meaning}',
      child: Material(
        color: selected.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ),
        child: InkWell(
          key: const Key('note-composer-colour'),
          onTap: () => _openPicker(context),
          borderRadius: BorderRadius.circular(5),
          child: const SizedBox(
            width: squareSize,
            height: squareSize,
          ),
        ),
      ),
    );
  }
}

class _ColourSquare extends StatelessWidget {
  const _ColourSquare({
    required this.color,
    required this.selected,
    this.size = 22,
  });

  final Color color;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: selected ? ShelfColors.ink : Colors.black.withValues(alpha: 0.16),
          width: selected ? 2 : 1,
        ),
      ),
    );
  }
}
