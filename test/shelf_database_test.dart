import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/data/shelf_database.dart';
import 'package:shelf/models/color_label.dart';
import 'package:shelf/models/library_document.dart';
import 'package:shelf/models/note.dart';
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
  });
}
