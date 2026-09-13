import 'package:pdfrx/pdfrx.dart';

import '../models/note_selection.dart';

/// Build a persisted selection anchor from pdfrx ranges + quoted text.
NoteSelection? noteSelectionFromRanges({
  required List<PdfPageTextRange> ranges,
  required String selectedText,
  required double pageWidth,
  required double pageHeight,
}) {
  if (ranges.isEmpty || pageWidth <= 0 || pageHeight <= 0) {
    return null;
  }
  final first = ranges.first;
  final quoted = selectedText.trim().isEmpty ? first.text : selectedText;
  return NoteSelection.fromPdfPageBounds(
    text: quoted.trim(),
    pdfLeft: first.bounds.left,
    pdfTop: first.bounds.top,
    pdfRight: first.bounds.right,
    pdfBottom: first.bounds.bottom,
    pageWidth: pageWidth,
    pageHeight: pageHeight,
  );
}
