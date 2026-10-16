import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/models/color_label.dart';
import 'package:shelf/models/note.dart';
import 'package:shelf/models/note_selection.dart';
import 'package:shelf/services/notes_export.dart';
import 'package:shelf/widgets/markdown_preview_sheet.dart';

void main() {
  ColorLabel label(String id) {
    return ColorLabel.seedDefaults().firstWhere((item) => item.id == id);
  }

  Note sample() {
    return Note(
      id: 'note-1',
      documentId: 'pdf-1',
      page: 2,
      x: 0.2,
      y: 0.3,
      text: '# Not a heading\n- not a bullet',
      colorLabelId: ColorLabel.orangeId,
      createdAt: DateTime.utc(2026, 9, 13),
      updatedAt: DateTime.utc(2026, 9, 13),
      selection: const NoteSelection(
        text: '**not bold**\nsecond line',
        left: 0.1,
        top: 0.2,
        right: 0.4,
        bottom: 0.3,
      ),
    );
  }

  test('preview markdown escapes note text and has no empty placeholder', () {
    final md = NotesExport.previewMarkdown(
      documentTitle: 'Notes on method',
      notes: [sample()],
      labelById: label,
    );
    expect(md, isNot(contains('No notes on this book.')));
    expect(md, contains(r'\# Not a heading'));
    expect(md, contains(r'\- not a bullet'));
    expect(md, contains(r'\*\*not bold\*\*'));
    expect(md, contains('second line'));
    expect(md, contains('Shelf notes export schema'));

    final empty = NotesExport.previewMarkdown(
      documentTitle: 'Notes on method',
      notes: const [],
      labelById: label,
    );
    expect(empty, isNot(contains('No notes on this book.')));
    expect(empty, contains('# Notes on method'));
    expect(empty, contains('Shelf notes export schema'));
  });

  testWidgets('markdown-like note text renders literally', (tester) async {
    final md = NotesExport.previewMarkdown(
      documentTitle: 'Notes on method',
      notes: [sample()],
      labelById: label,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ShelfMarkdownBody(data: md)),
      ),
    );

    expect(find.textContaining('# Not a heading'), findsOneWidget);
    expect(find.textContaining('- not a bullet'), findsOneWidget);
    expect(find.textContaining('**not bold**'), findsOneWidget);
    expect(find.textContaining('second line'), findsOneWidget);

    final hash = tester.widget<Text>(
      find.byWidgetPredicate((widget) {
        return widget is Text &&
            (widget.data ?? widget.textSpan?.toPlainText() ?? '').contains(
              '# Not a heading',
            );
      }),
    );
    expect(hash.style?.fontSize, 15.5);
    expect(hash.style?.fontWeight, isNot(FontWeight.w700));

    final quote = tester.widget<Text>(
      find.byWidgetPredicate((widget) {
        return widget is Text &&
            (widget.data ?? widget.textSpan?.toPlainText() ?? '').contains(
              '**not bold**',
            );
      }),
    );
    expect(quote.textSpan?.toPlainText(), contains('**not bold**'));
    expect(
      quote.textSpan
          ?.toPlainText()
          .contains('not bold'),
      isTrue,
    );
  });
}
