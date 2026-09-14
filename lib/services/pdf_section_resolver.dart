import 'package:pdfrx/pdfrx.dart';

import '../models/note.dart';

/// One heading in a PDF outline (or a page-title fallback).
///
/// [y] is normalised 0–1 with origin top-left, matching [Note.y].
/// [headingTitle] / [subheadingTitle] are the chapter and subsection on
/// this node's ancestor chain (depth 0 and 1).
class PdfSection {
  const PdfSection({
    required this.title,
    required this.page,
    required this.depth,
    this.y,
    required this.headingTitle,
    this.subheadingTitle,
  });

  final String title;
  final int page;
  final int depth;
  final double? y;
  final String headingTitle;
  final String? subheadingTitle;
}

/// Draft tree used by tests and by the pdfrx flatten path.
class OutlineDraft {
  const OutlineDraft({
    required this.title,
    this.page,
    this.y,
    this.children = const [],
  });

  final String title;
  final int? page;
  final double? y;
  final List<OutlineDraft> children;
}

class PageLineHint {
  const PageLineHint({
    required this.page,
    required this.text,
    required this.y,
  });

  final int page;
  final String text;
  final double y;
}

class NoteHeadings {
  const NoteHeadings({this.heading, this.subheading});

  final String? heading;
  final String? subheading;

  bool get isEmpty {
    return !_has(heading) && !_has(subheading);
  }

  static bool _has(String? value) => value != null && value.trim().isNotEmpty;
}

/// Resolve the PDF heading / subheading a note sits under.
///
/// Prefer a real outline (bookmarks / TOC). Fall back to page-title lines.
/// Missing structure yields null fields — never throws.
class PdfSectionResolver {
  /// Flatten a test / in-memory outline. Children inherit a missing dest
  /// from the nearest ancestor.
  static List<PdfSection> flattenDraft(List<OutlineDraft> nodes) {
    final out = <PdfSection>[];
    void walk(
      List<OutlineDraft> nodes,
      int depth,
      int? inheritedPage,
      double? inheritedY,
      List<String> ancestors,
    ) {
      for (final node in nodes) {
        final page = node.page ?? inheritedPage;
        final y = node.y ?? inheritedY;
        final title = node.title.trim();
        final chain = [...ancestors];
        if (title.isNotEmpty && page != null && page > 0) {
          final titles = [...chain, title];
          out.add(
            PdfSection(
              title: title,
              page: page,
              depth: depth,
              y: y,
              headingTitle: titles.first,
              subheadingTitle: titles.length >= 2 ? titles[1] : null,
            ),
          );
          chain.add(title);
        }
        walk(node.children, depth + 1, page, y, chain);
      }
    }

    walk(nodes, 0, null, null, const []);
    return out;
  }

  /// Flatten pdfrx outline nodes. Named destinations are already resolved
  /// into [PdfDest] by [PdfDocument.loadOutline].
  static List<PdfSection> flattenOutline(
    List<PdfOutlineNode> nodes, {
    List<double>? pageHeights,
  }) {
    OutlineDraft convert(PdfOutlineNode node) {
      final dest = node.dest;
      return OutlineDraft(
        title: node.title,
        page: dest?.pageNumber,
        y: destY(dest, dest?.pageNumber, pageHeights),
        children: [for (final child in node.children) convert(child)],
      );
    }

    return flattenDraft([for (final node in nodes) convert(node)]);
  }

  /// XYZ / FitH dest Y → normalised top-left. Null when unknown.
  static double? destY(
    PdfDest? dest,
    int? page,
    List<double>? pageHeights,
  ) {
    if (dest == null || page == null || pageHeights == null) {
      return null;
    }
    if (page < 1 || page > pageHeights.length) {
      return null;
    }
    final height = pageHeights[page - 1];
    if (height <= 0) {
      return null;
    }
    final params = dest.params;
    if (params == null || params.isEmpty) {
      return null;
    }
    // XYZ is [left, top, zoom]; FitH is [top].
    final top = params.length >= 2 ? params[1] : params[0];
    if (top == null) {
      return null;
    }
    return Note.normalizeCoord(1 - (top / height));
  }

  /// Title-like lines become a two-level outline when the PDF has no bookmarks.
  static List<PdfSection> fromPageLines(List<PageLineHint> lines) {
    final candidates = lines.where((line) => looksLikeTitle(line.text)).toList()
      ..sort((a, b) {
        final page = a.page.compareTo(b.page);
        if (page != 0) {
          return page;
        }
        return a.y.compareTo(b.y);
      });

    final sections = <PdfSection>[];
    for (final line in candidates) {
      final onPage = sections.where((item) => item.page == line.page).length;
      if (onPage >= 2) {
        continue;
      }
      final depth = onPage == 0 ? 0 : 1;
      final heading = depth == 0
          ? line.text.trim()
          : sections.last.headingTitle;
      final subheading = depth == 0 ? null : line.text.trim();
      sections.add(
        PdfSection(
          title: line.text.trim(),
          page: line.page,
          depth: depth,
          y: line.y,
          headingTitle: heading,
          subheadingTitle: subheading,
        ),
      );
    }
    return sections;
  }

  static bool looksLikeTitle(String line) {
    final text = line.trim();
    if (text.length < 2 || text.length > 80) {
      return false;
    }
    if (RegExp(r'^[\d.\s]+$').hasMatch(text)) {
      return false;
    }
    if (RegExp(
      r'^(chapter|part|section|appendix|contents|preface|introduction)\b',
      caseSensitive: false,
    ).hasMatch(text)) {
      return true;
    }
    if (RegExp(r'^\d+(\.\d+)*\s+\S').hasMatch(text)) {
      return true;
    }
    if (text.endsWith('.') && text.length > 40) {
      return false;
    }
    final words = text.split(RegExp(r'\s+'));
    if (words.length > 12) {
      return false;
    }
    final letters = text.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (letters.isEmpty) {
      return false;
    }
    if (letters == letters.toUpperCase() && letters.length >= 2) {
      return true;
    }
    final titled = words.every((word) {
      if (word.isEmpty) {
        return true;
      }
      final lead = word[0];
      return lead.toUpperCase() == lead;
    });
    return titled && words.length <= 10;
  }

  static NoteHeadings headingsFor({
    required List<PdfSection> sections,
    required int page,
    double? y,
  }) {
    if (sections.isEmpty || page < 1) {
      return const NoteHeadings();
    }
    final noteY = y ?? 1.0;
    PdfSection? current;
    for (final section in sections) {
      if (_isAtOrBefore(section, page, noteY)) {
        current = section;
      }
    }
    if (current == null) {
      return const NoteHeadings();
    }
    return NoteHeadings(
      heading: _clean(current.headingTitle),
      subheading: _clean(current.subheadingTitle),
    );
  }

  static NoteHeadings forNote(Note note, List<PdfSection> sections) {
    return headingsFor(
      sections: sections,
      page: note.page,
      y: note.selection?.top ?? note.y,
    );
  }

  static bool _isAtOrBefore(PdfSection section, int page, double noteY) {
    if (section.page < page) {
      return true;
    }
    if (section.page > page) {
      return false;
    }
    return (section.y ?? 0) <= noteY + 0.0001;
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
