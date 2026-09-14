import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../theme/shelf_theme.dart';

/// Visible orange selection fill + orange drag handles. No leftover callout.
///
/// pdfrx 2.6.1 has **no** `selectionColor` on [PdfTextSelectionParams]. The
/// page fill is painted in the viewer canvas from
/// [ThemeData.textSelectionTheme.selectionColor] (`_selectionColorOf`).
///
/// PR #7 set that colour to fully transparent, which removed the highlight
/// between the handles. We restore a translucent Shelf orange so the selected
/// span is visible again.
///
/// The empty dark grey/black callout under the handle was pdfrx's
/// [AdaptiveTextSelectionToolbar] (Cupertino dark bubble + caret) expanding
/// with no usable buttons. [PdfViewerParams.buildContextMenu] returns null and
/// automatic menus stay off — Shelf's [SelectionCommentBar] is the add-comment
/// chrome. The pdfrx magnifier stays disabled so it cannot paint an empty
/// loupe.
class PdfSelectionChrome {
  static const Color highlightColor = Color(0x48F15A22);
  static const Color handleColor = ShelfColors.orange;
  static const double handleHitSize = 30;
  static const double handleVisualSize = 12;

  /// Kept for tests / older call sites. Hit target stays 30; the drawn
  /// caret is [handleVisualSize].
  static const double handleSize = handleHitSize;

  static ThemeData theme(ThemeData base) {
    return base.copyWith(
      textSelectionTheme: const TextSelectionThemeData(
        selectionColor: highlightColor,
        selectionHandleColor: handleColor,
        cursorColor: handleColor,
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
            cursorColor: handleColor,
            child: child,
          ),
        );
      },
    );
  }

  /// Compact caret at the outside corner of a 30×30 hit box.
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

  static Widget? hideContextMenu(
    BuildContext context,
    PdfViewerContextMenuBuilderParams params,
  ) {
    return null;
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
