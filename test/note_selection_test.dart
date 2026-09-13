import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/data/shelf_database.dart';
import 'package:shelf/data/shelf_store.dart';
import 'package:shelf/models/color_label.dart';
import 'package:shelf/models/library_document.dart';
import 'package:shelf/models/note.dart';
import 'package:shelf/models/note_selection.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('NoteSelection', () {
    test('converts PDF bottom-left bounds to top-left normalised box', () {
      final selection = NoteSelection.fromPdfPageBounds(
        text: 'method',
        pdfLeft: 100,
        pdfTop: 600,
        pdfRight: 180,
        pdfBottom: 580,
        pageWidth: 400,
        pageHeight: 800,
      );

      expect(selection.text, 'method');
      expect(selection.left, closeTo(0.25, 0.0001));
      expect(selection.right, closeTo(0.45, 0.0001));
      expect(selection.top, closeTo(0.25, 0.0001));
      expect(selection.bottom, closeTo(0.275, 0.0001));
      expect(selection.anchorX, closeTo(0.35, 0.0001));
      expect(selection.anchorY, closeTo(0.2625, 0.0001));
    });

    test('round-trips through the note map with bounds and quoted text', () {
      final created = DateTime.utc(2026, 9, 13, 18);
      final note = Note(
        id: 'note-sel',
        documentId: 'pdf-1',
        page: 2,
        x: 0.35,
        y: 0.26,
        text: 'Come back to this word.',
        colorLabelId: ColorLabel.orangeId,
        createdAt: created,
        updatedAt: created,
        selection: const NoteSelection(
          text: 'method',
          left: 0.25,
          top: 0.25,
          right: 0.45,
          bottom: 0.28,
        ),
      );

      final restored = Note.fromMap(note.toMap());
      expect(restored.isSelectionAnchored, isTrue);
      expect(restored.selection?.text, 'method');
      expect(restored.selection?.left, 0.25);
      expect(restored.selection?.top, 0.25);
      expect(restored.selection?.right, 0.45);
      expect(restored.selection?.bottom, 0.28);
      expect(restored.x, 0.35);
      expect(restored.y, 0.26);
    });

    test('legacy maps without selection columns stay free-position notes', () {
      final restored = Note.fromMap({
        'id': 'note-1',
        'document_id': 'pdf-1',
        'page': 1,
        'x': 0.2,
        'y': 0.3,
        'text': 'Free marker',
        'color_label_id': ColorLabel.orangeId,
        'created_at': 0,
        'updated_at': 0,
      });
      expect(restored.isSelectionAnchored, isFalse);
      expect(restored.selection, isNull);
    });
  });

  group('selection-anchored store path', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();

    late ShelfDatabase db;
    late ShelfStore store;

    setUp(() async {
      db = ShelfDatabase(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      await db.upsertDocument(
        LibraryDocument(
          id: 'pdf-1',
          title: 'Notes on method',
          storedName: 'pdf-1.pdf',
          importedAt: DateTime.utc(2026, 9, 13),
          pageCount: 8,
        ),
      );
      store = ShelfStore(database: db);
      await store.init();
    });

    tearDown(() async {
      await db.close();
    });

    test('addNote persists quoted text and selection bounds', () async {
      const selection = NoteSelection(
        text: 'method',
        left: 0.2,
        top: 0.4,
        right: 0.35,
        bottom: 0.43,
      );
      final note = await store.addNote(
        documentId: 'pdf-1',
        page: 3,
        x: selection.anchorX,
        y: selection.anchorY,
        text: 'This word needs a comment.',
        selection: selection,
      );

      expect(note.isSelectionAnchored, isTrue);
      expect(note.selection?.text, 'method');
      expect(note.x, closeTo(selection.anchorX, 0.0001));
      expect(note.y, closeTo(selection.anchorY, 0.0001));

      final reloaded = await db.loadNotes();
      expect(reloaded, hasLength(1));
      expect(reloaded.single.selection?.text, 'method');
      expect(reloaded.single.selection?.left, 0.2);
      expect(reloaded.single.selection?.right, 0.35);
      expect(reloaded.single.page, 3);
    });

    test('search matches the quoted selection as well as the comment', () async {
      await store.addNote(
        documentId: 'pdf-1',
        page: 1,
        x: 0.2,
        y: 0.3,
        text: 'Look this up later.',
        selection: const NoteSelection(
          text: 'epistemology',
          left: 0.1,
          top: 0.2,
          right: 0.4,
          bottom: 0.25,
        ),
      );

      expect(store.searchNotes(query: 'epistemology'), hasLength(1));
      expect(store.searchNotes(query: 'Look this up'), hasLength(1));
      expect(store.searchNotes(query: 'unrelated'), isEmpty);
    });
  });
}
