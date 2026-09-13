import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../theme/shelf_theme.dart';

/// Hides pdfrx's grey/black selection fill without dropping grab/widen handles.
///
/// pdfrx paints both the page highlight and its default handles from
/// [ThemeData.textSelectionTheme.selectionColor]. A transparent colour
/// removes the box; [buildHandle] redraws the default 30×30 triangles in
/// a visible colour so `selectWord` and Add comment stay usable.
class PdfSelectionChrome {
  static const Color highlightColor = Color(0x00000000);
  static const Color handleColor = ShelfColors.composerCaret;
  static const double handleSize = 30;

  static ThemeData theme(ThemeData base) {
    return base.copyWith(
      textSelectionTheme: const TextSelectionThemeData(
        selectionColor: highlightColor,
      ),
    );
  }

  static Widget wrap(Widget child) {
    return Builder(
      builder: (context) {
        return Theme(
          data: theme(Theme.of(context)),
          child: DefaultSelectionStyle(
            selectionColor: highlightColor,
            child: child,
          ),
        );
      },
    );
  }

  /// Same triangle geometry as pdfrx's default handles (2.6.1).
  static Path handlePath({
    required PdfTextDirection direction,
    required PdfTextSelectionAnchorType type,
  }) {
    switch (direction) {
      case PdfTextDirection.ltr:
        if (type == PdfTextSelectionAnchorType.a) {
          return Path()
            ..moveTo(handleSize, 0)
            ..lineTo(handleSize, handleSize)
            ..lineTo(0, handleSize)
            ..close();
        }
        return Path()
          ..moveTo(0, 0)
          ..lineTo(handleSize, 0)
          ..lineTo(0, handleSize)
          ..close();
      case PdfTextDirection.rtl:
      case PdfTextDirection.vrtl:
        if (type == PdfTextSelectionAnchorType.a) {
          return Path()
            ..moveTo(0, handleSize)
            ..lineTo(handleSize, handleSize)
            ..lineTo(0, 0)
            ..close();
        }
        return Path()
          ..moveTo(0, 0)
          ..lineTo(handleSize, 0)
          ..lineTo(handleSize, handleSize)
          ..close();
      case PdfTextDirection.unknown:
        return Path()
          ..moveTo(0, 0)
          ..lineTo(handleSize, 0)
          ..lineTo(handleSize, handleSize)
          ..lineTo(0, handleSize)
          ..close();
    }
  }

  static Widget? buildHandle(
    BuildContext context,
    PdfTextSelectionAnchor anchor,
    PdfViewerTextSelectionAnchorHandleState state,
  ) {
    return PdfSelectionHandle(
      path: handlePath(direction: anchor.direction, type: anchor.type),
      state: state,
    );
  }
}

class PdfSelectionHandle extends StatelessWidget {
  const PdfSelectionHandle({
    super.key,
    required this.path,
    required this.state,
  });

  final Path path;
  final PdfViewerTextSelectionAnchorHandleState state;

  @override
  Widget build(BuildContext context) {
    final (color, shadow) = switch (state) {
      PdfViewerTextSelectionAnchorHandleState.normal => (
        PdfSelectionChrome.handleColor.withValues(alpha: .7),
        true,
      ),
      PdfViewerTextSelectionAnchorHandleState.dragging => (
        PdfSelectionChrome.handleColor,
        false,
      ),
      PdfViewerTextSelectionAnchorHandleState.hover => (
        PdfSelectionChrome.handleColor,
        true,
      ),
    };
    return CustomPaint(
      key: const Key('pdf-selection-handle'),
      painter: _HandlePainter(path: path, color: color, shadow: shadow),
      size: const Size(
        PdfSelectionChrome.handleSize,
        PdfSelectionChrome.handleSize,
      ),
    );
  }
}

class _HandlePainter extends CustomPainter {
  const _HandlePainter({
    required this.path,
    required this.color,
    required this.shadow,
  });

  final Path path;
  final Color color;
  final bool shadow;

  @override
  void paint(Canvas canvas, Size size) {
    if (shadow) {
      canvas.drawShadow(path, Colors.black, 4, true);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _HandlePainter oldDelegate) {
    return oldDelegate.path != path ||
        oldDelegate.color != color ||
        oldDelegate.shadow != shadow;
  }

  @override
  bool? hitTest(Offset position) {
    return position.dx >= 0 &&
        position.dx <= PdfSelectionChrome.handleSize &&
        position.dy >= 0 &&
        position.dy <= PdfSelectionChrome.handleSize;
  }
}
