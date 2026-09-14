import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/models/color_label.dart';
import 'package:shelf/models/library_document.dart';
import 'package:shelf/models/note.dart';
import 'package:shelf/models/note_selection.dart';
import 'package:shelf/services/notes_export.dart';

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
    expect(doc['title'], 'Notes on method');
    expect(doc['page_count'], 8);
    final notes = payload['notes']! as List<dynamic>;
    expect(notes, hasLength(1));
    final row = notes.single as Map<String, Object?>;
    expect(row['page'], 2);
    expect(row['x'], 0.3);
    expect(row['y'], 0.4);
    expect(row['text'], 'Come back to this diagram.');
    expect(row['selected_text'], 'method');
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
    expect(md, contains('Notes on method'));
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
    expect(files.last.readAsStringSync(), contains('shelf-notes-v1'));
  });
}
