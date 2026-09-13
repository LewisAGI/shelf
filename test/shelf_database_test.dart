import 'package:flutter_test/flutter_test.dart';
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
}
