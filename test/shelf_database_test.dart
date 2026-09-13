import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/data/shelf_database.dart';
import 'package:shelf/models/color_label.dart';
import 'package:shelf/models/library_document.dart';
import 'package:shelf/models/note.dart';
import 'package:shelf/models/note_selection.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late ShelfDatabase db;

  setUp(() async {
    db = ShelfDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('seeds orange as default and persists a labelled note', () async {
    final labels = await db.loadLabels();
    expect(labels.first.id, ColorLabel.orangeId);
    expect(labels.first.isDefault, isTrue);

    final document = LibraryDocument(
      id: 'pdf-1',
      title: 'Notes on method',
      storedName: 'pdf-1.pdf',
      importedAt: DateTime.utc(2026, 9, 11),
      pageCount: 12,
    );
    await db.upsertDocument(document);

    final now = DateTime.utc(2026, 9, 11, 10);
    final note = Note(
      id: 'note-1',
      documentId: document.id,
      page: 3,
      x: 0.4,
      y: 0.6,
      text: 'Check the footnote.',
      colorLabelId: ColorLabel.orangeId,
      createdAt: now,
      updatedAt: now,
    );
    await db.upsertNote(note);

    final loaded = await db.loadNotes();
    expect(loaded, hasLength(1));
    expect(loaded.single.colorLabelId, ColorLabel.orangeId);
    expect(loaded.single.x, 0.4);
    expect(loaded.single.page, 3);
    expect(loaded.single.isSelectionAnchored, isFalse);
  });

  test('persists a selection-anchored note', () async {
    await db.upsertDocument(
      LibraryDocument(
        id: 'pdf-2',
        title: 'Selection',
        storedName: 'pdf-2.pdf',
        importedAt: DateTime.utc(2026, 9, 13),
        pageCount: 2,
      ),
    );
    final now = DateTime.utc(2026, 9, 13, 18);
    await db.upsertNote(
      Note(
        id: 'note-sel',
        documentId: 'pdf-2',
        page: 1,
        x: 0.3,
        y: 0.4,
        text: 'On this word.',
        colorLabelId: ColorLabel.orangeId,
        createdAt: now,
        updatedAt: now,
        selection: const NoteSelection(
          text: 'word',
          left: 0.2,
          top: 0.35,
          right: 0.4,
          bottom: 0.42,
        ),
      ),
    );

    final loaded = await db.loadNotes();
    expect(loaded.single.isSelectionAnchored, isTrue);
    expect(loaded.single.selection?.text, 'word');
    expect(loaded.single.selection?.left, 0.2);
    expect(loaded.single.selection?.right, 0.4);
  });

  test('upgrades a v1 notes table and keeps existing rows', () async {
    final path = p.join(
      Directory.systemTemp.createTempSync('shelf-v1-').path,
      'shelf.db',
    );
    final factory = databaseFactoryFfi;
    final v1 = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE documents (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              stored_name TEXT NOT NULL,
              imported_at INTEGER NOT NULL,
              page_count INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE color_labels (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              meaning TEXT NOT NULL,
              hex TEXT NOT NULL,
              is_default INTEGER NOT NULL DEFAULT 0,
              sort_order INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE notes (
              id TEXT PRIMARY KEY,
              document_id TEXT NOT NULL,
              page INTEGER NOT NULL,
              x REAL NOT NULL,
              y REAL NOT NULL,
              text TEXT NOT NULL,
              color_label_id TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE,
              FOREIGN KEY(color_label_id) REFERENCES color_labels(id)
            )
          ''');
          await db.insert('color_labels', ColorLabel.seedDefaults().first.toMap());
          await db.insert('documents', {
            'id': 'pdf-1',
            'title': 'Old library',
            'stored_name': 'pdf-1.pdf',
            'imported_at': 0,
            'page_count': 2,
          });
          await db.insert('notes', {
            'id': 'old-note',
            'document_id': 'pdf-1',
            'page': 1,
            'x': 0.5,
            'y': 0.5,
            'text': 'Pre-upgrade note',
            'color_label_id': ColorLabel.orangeId,
            'created_at': 0,
            'updated_at': 0,
          });
        },
      ),
    );
    await v1.close();

    final upgraded = ShelfDatabase(factory: factory, path: path);
    final loaded = await upgraded.loadNotes();
    expect(loaded, hasLength(1));
    expect(loaded.single.text, 'Pre-upgrade note');
    expect(loaded.single.isSelectionAnchored, isFalse);

    await upgraded.upsertNote(
      Note(
        id: 'new-sel',
        documentId: 'pdf-1',
        page: 1,
        x: 0.2,
        y: 0.3,
        text: 'After upgrade',
        colorLabelId: ColorLabel.orangeId,
        createdAt: DateTime.utc(2026, 9, 13),
        updatedAt: DateTime.utc(2026, 9, 13),
        selection: const NoteSelection(
          text: 'upgrade',
          left: 0.1,
          top: 0.2,
          right: 0.3,
          bottom: 0.25,
        ),
      ),
    );
    final again = await upgraded.loadNotes();
    expect(again.any((note) => note.selection?.text == 'upgrade'), isTrue);
    await upgraded.close();
  });
}
