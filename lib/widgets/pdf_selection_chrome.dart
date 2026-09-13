import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../theme/shelf_theme.dart';

/// Hides pdfrx's grey/black selection fill without dropping grab/widen handles.
///
/// pdfrx 2.6.1 has **no** `selectionColor` on [PdfTextSelectionParams]. The
/// page fill is painted in the viewer canvas from
/// [ThemeData.textSelectionTheme.selectionColor] (`_selectionColorOf`).
/// There is no separate page-overlay fill.
///
/// A fully transparent theme colour removes that canvas fill. Remaining
/// chrome on device after PR #6 was handle geometry (30×30 filled triangles
/// + black shadows) and the touch magnifier — not a second fill API. Those
/// are thinned here: compact caret dots, no shadow, magnifier off.
///
/// If a faint box still appears, it is pdfrx canvas fill using a theme
/// context that missed this wrap (fallback `DefaultSelectionStyle.defaultColor`).
/// There is no further fill hook without forking pdfrx or covering glyphs.
class PdfSelectionChrome {
  static const Color highlightColor = Color(0x00000000);
  static const Color handleColor = ShelfColors.composerCaret;
  static const double handleHitSize = 30;
  static const double handleVisualSize = 12;

  /// Kept for tests / older call sites. Hit target stays 30; the drawn
  /// caret is [handleVisualSize].
  static const double handleSize = handleHitSize;

  static ThemeData theme(ThemeData base) {
    return base.copyWith(
      textSelectionTheme: const TextSelectionThemeData(
        selectionColor: highlightColor,
        selectionHandleColor: highlightColor,
        cursorColor: highlightColor,
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
            cursorColor: highlightColor,
            child: child,
          ),
        );
      },
    );
  }

  /// Compact caret at the outside corner of a 30×30 hit box.
  ///
  /// pdfrx's default 30×30 triangles read as a leftover selection box once
  /// the canvas fill is transparent. A 12px disc is still grabable.
  static Path handlePath({
    required PdfTextDirection direction,
    required PdfTextSelectionAnchorType type,
  }) {
    final visual = handleVisualSize;
    final hit = handleHitSize;
    final isStart = type == PdfTextSelectionAnchorType.a;
    final Offset centre;
    switch (direction) {
      case PdfTextDirection.ltr:
        centre = Offset(
          isStart ? visual / 2 : hit - visual / 2,
          hit - visual / 2,
        );
      case PdfTextDirection.rtl:
      case PdfTextDirection.vrtl:
        centre = Offset(
          isStart ? hit - visual / 2 : visual / 2,
          hit - visual / 2,
        );
      case PdfTextDirection.unknown:
        centre = Offset(hit / 2, hit / 2);
    }
    return Path()..addOval(Rect.fromCircle(center: centre, radius: visual / 2));
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
    final color = switch (state) {
      PdfViewerTextSelectionAnchorHandleState.normal =>
        PdfSelectionChrome.handleColor.withValues(alpha: .85),
      PdfViewerTextSelectionAnchorHandleState.dragging =>
        PdfSelectionChrome.handleColor,
      PdfViewerTextSelectionAnchorHandleState.hover =>
        PdfSelectionChrome.handleColor,
    };
    return CustomPaint(
      key: const Key('pdf-selection-handle'),
      painter: _HandlePainter(path: path, color: color),
      size: const Size(
        PdfSelectionChrome.handleHitSize,
        PdfSelectionChrome.handleHitSize,
      ),
    );
  }
}

class _HandlePainter extends CustomPainter {
  const _HandlePainter({required this.path, required this.color});

  final Path path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _HandlePainter oldDelegate) {
    return oldDelegate.path != path || oldDelegate.color != color;
  }

  @override
  bool? hitTest(Offset position) {
    return position.dx >= 0 &&
        position.dx <= PdfSelectionChrome.handleHitSize &&
        position.dy >= 0 &&
        position.dy <= PdfSelectionChrome.handleHitSize;
  }
}
