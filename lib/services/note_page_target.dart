import '../models/note.dart';

/// Maps a stored note page onto pdfrx's 1-based viewer page number.
///
/// Shelf notes are documented as 1-based ([Note.page]). A stored `0` is
/// treated as the first page (legacy 0-based index), not as "leave the
/// viewer on whatever it opened" — [PdfViewer.file] defaults to page 1,
/// which is how every Hull note looked like it jumped to the cover.
class NotePageTarget {
  /// Convert a stored page to a pdfrx `pageNumber` / `initialPageNumber`.
  ///
  /// A stale [pageCount] of `1` (library row not yet updated, or a
  /// placeholder) must not clamp a later page down to 1.
  static int toViewerPage(int storedPage, {int? pageCount}) {
    final page = storedPage < 1 ? 1 : storedPage;
    if (pageCount != null && pageCount > 1 && page > pageCount) {
      return pageCount;
    }
    return page;
  }

  /// Notes-hub → reader: always the note's stored page. Outline dests and
  /// a fallback of 1 are not used when the note has a page.
  static int forNoteOpen({
    required Note? note,
    int? fallbackPage,
    int? pageCount,
  }) {
    final stored = note?.page ?? fallbackPage ?? 1;
    return toViewerPage(stored, pageCount: pageCount);
  }
}
