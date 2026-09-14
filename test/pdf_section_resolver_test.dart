import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/models/color_label.dart';
import 'package:shelf/models/note.dart';
import 'package:shelf/models/note_selection.dart';
import 'package:shelf/services/pdf_section_resolver.dart';

void main() {
  final chapter = const OutlineDraft(
    title: 'Chapter 3 Method',
    page: 2,
    y: 0.05,
    children: [
      OutlineDraft(
        title: '3.2 Standing remark',
        page: 2,
        y: 0.40,
        children: [
          OutlineDraft(
            title: 'A nested aside',
            page: 3,
            y: 0.10,
          ),
        ],
      ),
      OutlineDraft(title: '3.3 Later section', page: 4, y: 0.0),
    ],
  );

  final outline = PdfSectionResolver.flattenDraft([chapter]);

  Note noteOn({required int page, required double y}) {
    return Note(
      id: 'n',
      documentId: 'pdf-1',
      page: page,
      x: 0.3,
      y: y,
      text: 'Look this up.',
      colorLabelId: ColorLabel.orangeId,
      createdAt: DateTime.utc(2026, 9, 14),
      updatedAt: DateTime.utc(2026, 9, 14),
    );
  }

  test('flatten inherits a missing dest from the parent', () {
    final sections = PdfSectionResolver.flattenDraft([
      const OutlineDraft(
        title: 'Part I',
        page: 1,
        children: [OutlineDraft(title: 'Child without dest')],
      ),
    ]);
    expect(sections, hasLength(2));
    expect(sections.last.title, 'Child without dest');
    expect(sections.last.page, 1);
    expect(sections.last.headingTitle, 'Part I');
    expect(sections.last.subheadingTitle, 'Child without dest');
  });

  test('note under a subsection gets heading and subheading', () {
    final headings = PdfSectionResolver.forNote(
      noteOn(page: 2, y: 0.55),
      outline,
    );
    expect(headings.heading, 'Chapter 3 Method');
    expect(headings.subheading, '3.2 Standing remark');
  });

  test('note above the subsection stays on the chapter only', () {
    final headings = PdfSectionResolver.forNote(
      noteOn(page: 2, y: 0.20),
      outline,
    );
    expect(headings.heading, 'Chapter 3 Method');
    expect(headings.subheading, isNull);
  });

  test('deeper outline node still reports chapter + first subsection', () {
    final headings = PdfSectionResolver.forNote(
      noteOn(page: 3, y: 0.50),
      outline,
    );
    expect(headings.heading, 'Chapter 3 Method');
    expect(headings.subheading, '3.2 Standing remark');
  });

  test('note before any outline entry has null fields', () {
    final headings = PdfSectionResolver.forNote(
      noteOn(page: 1, y: 0.5),
      outline,
    );
    expect(headings.heading, isNull);
    expect(headings.subheading, isNull);
  });

  test('empty outline does not throw and yields null fields', () {
    final headings = PdfSectionResolver.forNote(noteOn(page: 2, y: 0.4), const []);
    expect(headings.isEmpty, isTrue);
    expect(headings.heading, isNull);
    expect(headings.subheading, isNull);
  });

  test('selection top is used when the note is selection-anchored', () {
    final note = Note(
      id: 'n',
      documentId: 'pdf-1',
      page: 2,
      x: 0.3,
      y: 0.9,
      text: 'Look this up.',
      colorLabelId: ColorLabel.orangeId,
      createdAt: DateTime.utc(2026, 9, 14),
      updatedAt: DateTime.utc(2026, 9, 14),
      selection: const NoteSelection(
        text: 'method',
        left: 0.2,
        top: 0.18,
        right: 0.4,
        bottom: 0.22,
      ),
    );
    final headings = PdfSectionResolver.forNote(note, outline);
    expect(headings.heading, 'Chapter 3 Method');
    expect(headings.subheading, isNull);
  });

  test('page-title fallback builds a two-level outline', () {
    final sections = PdfSectionResolver.fromPageLines(const [
      PageLineHint(page: 2, text: 'Chapter 3 Method', y: 0.05),
      PageLineHint(page: 2, text: '3.2 Standing remark', y: 0.40),
      PageLineHint(
        page: 2,
        text: 'This is a long body sentence that should not become a heading because it ends with a period and is quite long.',
        y: 0.50,
      ),
    ]);
    expect(sections, hasLength(2));
    final headings = PdfSectionResolver.headingsFor(
      sections: sections,
      page: 2,
      y: 0.55,
    );
    expect(headings.heading, 'Chapter 3 Method');
    expect(headings.subheading, '3.2 Standing remark');
  });

  test('looksLikeTitle accepts numbered and chapter lines', () {
    expect(PdfSectionResolver.looksLikeTitle('Chapter 3 Method'), isTrue);
    expect(PdfSectionResolver.looksLikeTitle('3.2 Standing remark'), isTrue);
    expect(PdfSectionResolver.looksLikeTitle('METHOD'), isTrue);
    expect(PdfSectionResolver.looksLikeTitle('12'), isFalse);
    expect(
      PdfSectionResolver.looksLikeTitle(
        'This is a long body sentence that should not become a heading because it ends with a period and is quite long.',
      ),
      isFalse,
    );
  });
}
