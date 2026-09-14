import 'dart:math' as math;

import 'package:pdfrx/pdfrx.dart';

import '../models/library_document.dart';
import '../models/note.dart';
import 'pdf_section_resolver.dart';

/// Load heading structure from a PDF at export / Ask / Send time.
///
/// Headings are **not** stored on the note. They reflect the current PDF
/// outline (bookmarks / TOC). Named destinations are resolved by pdfrx
/// into [PdfDest] on [PdfDocument.loadOutline]. If the outline is empty,
/// Shelf tries title-like lines from page text. Failures yield an empty
/// list — callers emit null heading fields.
class PdfOutlineSource {
  /// Opens [path], reads structure, disposes the document.
  static Future<List<PdfSection>> loadFromPath(String path) async {
    try {
      final document = await PdfDocument.openFile(path);
      try {
        return await loadFromDocument(document);
      } finally {
        await document.dispose();
      }
    } on Object {
      return const [];
    }
  }

  static Future<List<PdfSection>> loadForDocument(
    LibraryDocument document,
    Future<String> Function(LibraryDocument) pdfPath,
  ) async {
    try {
      final path = await pdfPath(document);
      return await loadFromPath(path);
    } on Object {
      return const [];
    }
  }

  static Future<List<PdfSection>> loadFromDocument(PdfDocument document) async {
    try {
      final outline = await document.loadOutline();
      final heights = [for (final page in document.pages) page.height];
      final sections = PdfSectionResolver.flattenOutline(
        outline,
        pageHeights: heights,
      );
      if (sections.isNotEmpty) {
        return sections;
      }
      return await pageTitleFallback(document);
    } on Object {
      return const [];
    }
  }

  /// Nearest section titles from page text when the PDF has no outline.
  static Future<List<PdfSection>> pageTitleFallback(PdfDocument document) async {
    try {
      final lines = <PageLineHint>[];
      for (final page in document.pages) {
        final raw = await page.loadText();
        if (raw == null || raw.fullText.trim().isEmpty) {
          continue;
        }
        lines.addAll(
          _linesFromPageText(
            pageNumber: page.pageNumber,
            pageHeight: page.height,
            fullText: raw.fullText,
            charRects: raw.charRects,
          ),
        );
      }
      return PdfSectionResolver.fromPageLines(lines);
    } on Object {
      return const [];
    }
  }

  static List<PageLineHint> _linesFromPageText({
    required int pageNumber,
    required double pageHeight,
    required String fullText,
    required List<PdfRect> charRects,
  }) {
    final lines = <PageLineHint>[];
    var start = 0;
    for (var i = 0; i <= fullText.length; i++) {
      final atEnd = i == fullText.length;
      if (!atEnd && fullText.codeUnitAt(i) != 10) {
        continue;
      }
      final raw = fullText.substring(start, i).replaceAll('\r', '').trim();
      if (raw.isNotEmpty) {
        final y = _lineY(
          start: start,
          end: i,
          pageHeight: pageHeight,
          charRects: charRects,
          fallbackIndex: lines.length,
        );
        lines.add(PageLineHint(page: pageNumber, text: raw, y: y));
      }
      start = i + 1;
    }
    return lines;
  }

  static double _lineY({
    required int start,
    required int end,
    required double pageHeight,
    required List<PdfRect> charRects,
    required int fallbackIndex,
  }) {
    if (pageHeight > 0 && start < charRects.length) {
      final last = math.min(end, charRects.length);
      if (last > start) {
        var pdfTop = charRects[start].top;
        for (var i = start; i < last; i++) {
          final rect = charRects[i];
          pdfTop = math.max(pdfTop, math.max(rect.top, rect.bottom));
        }
        return Note.normalizeCoord(1 - (pdfTop / pageHeight));
      }
    }
    return Note.normalizeCoord(fallbackIndex * 0.02);
  }
}
