import 'dart:ui';

import '../models/note.dart';

/// Opens a notes-hub row without a fixed delay.
///
/// Order: viewer ready → go to the note's page → wait until that page is
/// current → bring the marker into view → open the editor.
class NoteOpenSequence {
  /// Runs the notes-hub → reader hand-off.
  ///
  /// Each step is skipped once [isActive] is false (widget unmounted).
  /// There is no wall-clock sleep; readiness and page changes are awaited
  /// through the injected callbacks.
  static Future<void> run({
    required Future<void> Function() waitUntilReady,
    required int page,
    required Future<void> Function(int page) goToPage,
    Future<void> Function()? waitUntilPageCurrent,
    Future<void> Function()? ensureMarkerVisible,
    required Future<void> Function() openNote,
    bool Function()? isActive,
  }) async {
    bool active() => isActive?.call() ?? true;

    await waitUntilReady();
    if (!active()) {
      return;
    }
    await goToPage(page);
    if (!active()) {
      return;
    }
    if (waitUntilPageCurrent != null) {
      await waitUntilPageCurrent();
      if (!active()) {
        return;
      }
    }
    if (ensureMarkerVisible != null) {
      await ensureMarkerVisible();
      if (!active()) {
        return;
      }
    }
    await openNote();
  }
}

/// Whether [normalisedTap] (origin top-left, 0–1) lands on [note]'s
/// square marker, using the page size in view pixels.
bool noteMarkerContains({
  required Note note,
  required Offset normalisedTap,
  required Size pageSizeInView,
  double radius = 16,
}) {
  final dx = (normalisedTap.dx - note.x).abs() * pageSizeInView.width;
  final dy = (normalisedTap.dy - note.y).abs() * pageSizeInView.height;
  return dx <= radius && dy <= radius;
}

/// PDF-space rectangle around a marker. Origin is bottom-left; [top] is
/// greater than [bottom], matching [PdfRect].
({double left, double top, double right, double bottom}) markerPdfBounds({
  required Note note,
  required double pageWidth,
  required double pageHeight,
  double pad = 24,
}) {
  final pdfX = note.x * pageWidth;
  final pdfY = (1 - note.y) * pageHeight;
  return (
    left: pdfX - pad,
    top: pdfY + pad,
    right: pdfX + pad,
    bottom: pdfY - pad,
  );
}
