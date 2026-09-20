import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/models/color_label.dart';
import 'package:shelf/models/library_document.dart';
import 'package:shelf/models/note.dart';
import 'package:shelf/models/note_selection.dart';
import 'package:shelf/services/notes_export.dart';
import 'package:shelf/services/pdf_section_resolver.dart';

void main() {
  final document = LibraryDocument(
    id: 'pdf-1',
    title: 'Notes on method',
    storedName: 'pdf-1.pdf',
    importedAt: DateTime.utc(2026, 9, 13),
    pageCount: 8,
  );

  final note = Note(
    id: 'note-1',
    documentId: 'pdf-1',
    page: 2,
    x: 0.3,
    y: 0.4,
    text: 'Come back to this diagram.',
    colorLabelId: ColorLabel.orangeId,
    createdAt: DateTime.utc(2026, 9, 13, 10),
    updatedAt: DateTime.utc(2026, 9, 13, 11),
    selection: const NoteSelection(
      text: 'method',
      left: 0.2,
      top: 0.2,
      right: 0.4,
      bottom: 0.25,
    ),
  );

  test('JSON export includes page, coordinates, selected text, labels, timestamps', () {
    final payload = NotesExport.payload(
      document: document,
      notes: [note],
      labelById: (id) => ColorLabel.seedDefaults().firstWhere((item) => item.id == id),
      exportedAt: DateTime.utc(2026, 9, 14),
    );

    expect(payload['schema'], NotesExport.schemaId);
    expect(payload['exported_at'], '2026-09-14T00:00:00.000Z');
    final doc = payload['document']! as Map<String, Object?>;
    expect(doc['id'], 'pdf-1');
    expect(doc['title'], 'Notes on method');
    expect(doc['file_name'], 'Notes on method.pdf');
    expect(doc['page_count'], 8);
    final notes = payload['notes']! as List<dynamic>;
    expect(notes, hasLength(1));
    final row = notes.single as Map<String, Object?>;
    expect(row['page'], 2);
    expect(row['x'], 0.3);
    expect(row['y'], 0.4);
    expect(row['text'], 'Come back to this diagram.');
    expect(row['selected_text'], 'method');
    expect(row['heading'], isNull);
    expect(row['subheading'], isNull);
    expect(row['created_at'], '2026-09-13T10:00:00.000Z');
    final label = row['label']! as Map<String, Object?>;
    expect(label['name'], 'General note');
    expect(jsonEncode(payload), isNot(contains('sk-')));
  });

  test('schema markdown names the JSON fields an AI should read', () {
    final md = NotesExport.schemaMarkdown(documentTitle: 'Notes on method');
    expect(md, contains(NotesExport.schemaId));
    expect(md, contains('selected_text'));
    expect(md, contains('page'));
    expect(md, contains('heading'));
    expect(md, contains('subheading'));
    expect(md, contains('resolved at export time'));
    expect(md, contains('Notes on method'));
    expect(md, contains('file_name'));
    expect(md, contains('single-note share'));
  });

  test('fileNameOf prefers imported title when stored name is the sandbox id', () {
    expect(NotesExport.fileNameOf(document), 'Notes on method.pdf');
    expect(
      NotesExport.fileNameOf(
        LibraryDocument(
          id: 'abc',
          title: 'Lecture notes',
          storedName: 'Original Lecture.pdf',
          importedAt: DateTime.utc(2026, 9, 13),
        ),
      ),
      'Original Lecture.pdf',
    );
  });

  test('JSON export and snippets include heading and subheading from outline', () {
    final outline = PdfSectionResolver.flattenDraft(const [
      OutlineDraft(
        title: 'Chapter 3 Method',
        page: 2,
        y: 0.05,
        children: [
          OutlineDraft(title: '3.2 Standing remark', page: 2, y: 0.10),
        ],
      ),
    ]);
    ColorLabel labelById(String id) =>
        ColorLabel.seedDefaults().firstWhere((item) => item.id == id);

    final payload = NotesExport.payload(
      document: document,
      notes: [note],
      labelById: labelById,
      exportedAt: DateTime.utc(2026, 9, 14),
      outline: outline,
    );
    final row = (payload['notes']! as List<dynamic>).single as Map<String, Object?>;
    expect(row['heading'], 'Chapter 3 Method');
    expect(row['subheading'], '3.2 Standing remark');

    final snippets = NotesExport.snippets(
      notes: [note],
      labelById: labelById,
      outline: outline,
    );
    expect(snippets, hasLength(1));
    expect(snippets.single.heading, 'Chapter 3 Method');
    expect(snippets.single.subheading, '3.2 Standing remark');
    expect(snippets.single.selectedText, 'method');
  });

  test('JSON export leaves heading fields null when the PDF has no outline', () {
    final payload = NotesExport.payload(
      document: document,
      notes: [note],
      labelById: (id) => ColorLabel.seedDefaults().firstWhere((item) => item.id == id),
      outline: const [],
    );
    final row = (payload['notes']! as List<dynamic>).single as Map<String, Object?>;
    expect(row.containsKey('heading'), isTrue);
    expect(row['heading'], isNull);
    expect(row['subheading'], isNull);
  });

  test('writeFiles creates JSON and markdown companions', () async {
    final dir = await Directory.systemTemp.createTemp('shelf-export-test-');
    addTearDown(() => dir.delete(recursive: true));
    final files = await NotesExport.writeFiles(
      document: document,
      notes: [note],
      labelById: (id) => ColorLabel.seedDefaults().firstWhere((item) => item.id == id),
      directory: dir,
      exportedAt: DateTime.utc(2026, 9, 14),
    );
    expect(files, hasLength(2));
    expect(files.first.path, endsWith('Notes-on-method-notes.json'));
    expect(files.last.path, endsWith('Notes-on-method-notes-schema.md'));
    expect(files.first.readAsStringSync(), contains('"selected_text": "method"'));
    expect(files.first.readAsStringSync(), contains('"heading": null'));
    expect(files.last.readAsStringSync(), contains('shelf-notes-v1'));
    expect(files.last.readAsStringSync(), contains('heading'));
    expect(files.last.readAsStringSync(), contains('subheading'));
    expect(files.first.readAsStringSync(), contains('"file_name": "Notes on method.pdf"'));
  });

  test('single-note JSON is a one-item shelf-notes-v1 envelope', () async {
    final dir = await Directory.systemTemp.createTemp('shelf-single-note-');
    addTearDown(() => dir.delete(recursive: true));
    ColorLabel labelById(String id) =>
        ColorLabel.seedDefaults().firstWhere((item) => item.id == id);
    final outline = PdfSectionResolver.flattenDraft(const [
      OutlineDraft(
        title: 'Chapter 3 Method',
        page: 2,
        y: 0.05,
        children: [
          OutlineDraft(title: '3.2 Standing remark', page: 2, y: 0.10),
        ],
      ),
    ]);
    final files = await NotesExport.writeSingleNoteFiles(
      document: document,
      note: note,
      labelById: labelById,
      kind: SingleNoteShareKind.noteOnly,
      directory: dir,
      exportedAt: DateTime.utc(2026, 9, 14),
      outline: outline,
    );
    expect(files, hasLength(1));
    expect(files.single.path, endsWith('Notes-on-method-note.json'));
    final payload = jsonDecode(files.single.readAsStringSync()) as Map<String, dynamic>;
    expect(payload['schema'], NotesExport.schemaId);
    final doc = payload['document']! as Map<String, dynamic>;
    expect(doc['id'], 'pdf-1');
    expect(doc['title'], 'Notes on method');
    expect(doc['file_name'], 'Notes on method.pdf');
    final notes = payload['notes']! as List<dynamic>;
    expect(notes, hasLength(1));
    final row = notes.single as Map<String, dynamic>;
    expect(row['text'], 'Come back to this diagram.');
    expect(row['page'], 2);
    expect(row['selected_text'], 'method');
    expect(row['heading'], 'Chapter 3 Method');
    expect(row['subheading'], '3.2 Standing remark');
    expect(row['label'], isA<Map<String, dynamic>>());
  });

  test('single-note share kinds attach PDF and guide as requested', () async {
    final dir = await Directory.systemTemp.createTemp('shelf-single-kinds-');
    addTearDown(() => dir.delete(recursive: true));
    ColorLabel labelById(String id) =>
        ColorLabel.seedDefaults().firstWhere((item) => item.id == id);
    final pdfBytes = [0x25, 0x50, 0x44, 0x46]; // %PDF

    final all = await NotesExport.writeSingleNoteFiles(
      document: document,
      note: note,
      labelById: labelById,
      kind: SingleNoteShareKind.notePdfGuide,
      directory: Directory('${dir.path}/all')..createSync(),
      pdfBytes: pdfBytes,
    );
    expect(all.map((file) => file.uri.pathSegments.last).toList(), [
      'Notes-on-method-note.json',
      'Notes-on-method-note-schema.md',
      'Notes on method.pdf',
    ]);
    expect(all.last.readAsBytesSync(), pdfBytes);
    expect(all[1].readAsStringSync(), contains('shelf-notes-v1'));

    final pdfOnly = await NotesExport.writeSingleNoteFiles(
      document: document,
      note: note,
      labelById: labelById,
      kind: SingleNoteShareKind.notePdf,
      directory: Directory('${dir.path}/pdf')..createSync(),
      pdfBytes: pdfBytes,
    );
    expect(pdfOnly, hasLength(2));
    expect(pdfOnly.last.path, endsWith('Notes on method.pdf'));

    final guide = await NotesExport.writeSingleNoteFiles(
      document: document,
      note: note,
      labelById: labelById,
      kind: SingleNoteShareKind.noteGuide,
      directory: Directory('${dir.path}/guide')..createSync(),
      pdfBytes: pdfBytes,
    );
    expect(guide, hasLength(2));
    expect(guide.last.path, endsWith('Notes-on-method-note-schema.md'));
  });
}
