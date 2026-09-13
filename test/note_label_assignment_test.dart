import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/data/shelf_database.dart';
import 'package:shelf/data/shelf_store.dart';
import 'package:shelf/models/color_label.dart';
import 'package:shelf/models/library_document.dart';
import 'package:shelf/models/note.dart';
import 'package:shelf/screens/notes_hub_screen.dart';
import 'package:shelf/screens/settings_screen.dart';
import 'package:shelf/services/speech_capture.dart';
import 'package:shelf/theme/shelf_theme.dart';
import 'package:shelf/widgets/note_editor.dart';
import 'package:shelf/widgets/note_label_picker.dart';
import 'package:shelf/widgets/note_marker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late ShelfDatabase db;
  late ShelfStore store;

  Future<void> seedDocument() async {
    await db.upsertDocument(
      LibraryDocument(
        id: 'pdf-1',
        title: 'Notes on method',
        storedName: 'pdf-1.pdf',
        importedAt: DateTime.utc(2026, 9, 13),
        pageCount: 8,
      ),
    );
  }

  setUp(() async {
    db = ShelfDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    await seedDocument();
    store = ShelfStore(database: db);
    await store.init();
  });

  tearDown(() async {
    await db.close();
  });

  group('label assignment', () {
    test('new notes use the orange default unless a label is given', () async {
      final note = await store.addNote(
        documentId: 'pdf-1',
        page: 2,
        x: 0.2,
        y: 0.3,
        text: 'A standing remark.',
      );

      expect(note.colorLabelId, ColorLabel.orangeId);
      expect(store.defaultLabel.id, ColorLabel.orangeId);
      expect(
        store.labelById(note.colorLabelId).hex,
        ShelfColors.defaultOrangeHex,
      );
    });

    test('create and edit persist a chosen colour label', () async {
      final created = await store.addNote(
        documentId: 'pdf-1',
        page: 3,
        x: 0.4,
        y: 0.5,
        text: 'Look this up.',
        colorLabelId: ColorLabel.purpleId,
      );
      expect(created.colorLabelId, ColorLabel.purpleId);

      await store.saveNote(
        created.copyWith(colorLabelId: ColorLabel.orangeId),
      );
      expect(store.notes.single.colorLabelId, ColorLabel.orangeId);

      await store.saveNote(
        store.notes.single.copyWith(colorLabelId: ColorLabel.purpleId),
      );

      final reloaded = await db.loadNotes();
      expect(reloaded, hasLength(1));
      expect(reloaded.single.colorLabelId, ColorLabel.purpleId);
      expect(
        store.labelById(reloaded.single.colorLabelId).id,
        ColorLabel.purpleId,
      );
    });
  });

  group('note composer', () {
    testWidgets('compact field, obvious mic, and label can be applied', (
      tester,
    ) async {
      final labels = ColorLabel.seedDefaults();

      await tester.pumpWidget(
        MaterialApp(
          theme: ShelfTheme.light(),
          home: Scaffold(
            body: NoteEditor(
              labels: labels,
              defaultLabelId: ColorLabel.orangeId,
              speech: SpeechCapture(),
              page: 4,
            ),
          ),
        ),
      );

      final field = tester.widget<TextField>(
        find.byKey(const Key('note-composer-field')),
      );
      expect(field.minLines, 2);
      expect(field.maxLines, 8);
      expect(find.byKey(const Key('note-composer-mic')), findsOneWidget);
      expect(find.byType(NoteLabelPicker), findsOneWidget);
      expect(find.byKey(Key('note-label-${ColorLabel.orangeId}')), findsOneWidget);
      expect(find.byKey(Key('note-label-${ColorLabel.purpleId}')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('note-composer-field')),
        'Come back to this diagram.',
      );
      await tester.tap(find.byKey(Key('note-label-${ColorLabel.purpleId}')));
      await tester.pump();

      expect(find.text('Come back to this diagram.'), findsOneWidget);
      expect(find.text('Further research'), findsWidgets);
    });

    testWidgets('saving from the sheet returns the assigned label', (
      tester,
    ) async {
      NoteEditorResult? result;

      await tester.pumpWidget(
        MaterialApp(
          theme: ShelfTheme.light(),
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  result = await NoteEditor.show(
                    context,
                    labels: ColorLabel.seedDefaults(),
                    defaultLabelId: ColorLabel.orangeId,
                    speech: SpeechCapture(),
                    page: 1,
                  );
                },
                child: const Text('Open editor'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('note-composer-field')),
        'Purple research note.',
      );
      await tester.tap(find.byKey(Key('note-label-${ColorLabel.purpleId}')));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.text, 'Purple research note.');
      expect(result!.colorLabelId, ColorLabel.purpleId);
      expect(result!.delete, isFalse);
    });

    testWidgets('existing note shows its label and can change it', (
      tester,
    ) async {
      final note = Note(
        id: 'note-1',
        documentId: 'pdf-1',
        page: 2,
        x: 0.2,
        y: 0.3,
        text: 'Already labelled.',
        colorLabelId: ColorLabel.purpleId,
        createdAt: DateTime.utc(2026, 9, 13),
        updatedAt: DateTime.utc(2026, 9, 13),
      );
      NoteEditorResult? result;

      await tester.pumpWidget(
        MaterialApp(
          theme: ShelfTheme.light(),
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  result = await NoteEditor.show(
                    context,
                    labels: ColorLabel.seedDefaults(),
                    defaultLabelId: ColorLabel.orangeId,
                    speech: SpeechCapture(),
                    note: note,
                  );
                },
                child: const Text('Open editor'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();

      expect(find.text('Further research'), findsWidgets);
      await tester.tap(find.byKey(Key('note-label-${ColorLabel.orangeId}')));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result!.colorLabelId, ColorLabel.orangeId);
      expect(result!.text, 'Already labelled.');
    });
  });

  testWidgets('notes list and marker use the assigned colour', (tester) async {
    await store.addNote(
      documentId: 'pdf-1',
      page: 1,
      x: 0.1,
      y: 0.2,
      text: 'Needs more reading.',
      colorLabelId: ColorLabel.purpleId,
    );
    final label = store.labelById(ColorLabel.purpleId);

    await tester.pumpWidget(
      MaterialApp(
        theme: ShelfTheme.light(),
        home: NotesHubScreen(store: store),
      ),
    );
    await tester.pump();

    expect(find.text('Needs more reading.'), findsOneWidget);
    expect(find.textContaining('Further research'), findsWidgets);

    await tester.pumpWidget(
      MaterialApp(
        theme: ShelfTheme.light(),
        home: Scaffold(
          body: NoteMarker(color: label.color, focused: true),
        ),
      ),
    );
    final marker = tester.widget<NoteMarker>(find.byType(NoteMarker));
    expect(marker.color, label.color);
  });

  testWidgets('Settings keeps Labels and adds an API / connection section', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ShelfTheme.light(),
        home: SettingsScreen(store: store),
      ),
    );
    await tester.pump();

    expect(find.text('Colour labels'), findsOneWidget);
    expect(find.text('General note'), findsOneWidget);
    expect(find.text('API / connection'), findsOneWidget);
    expect(find.text('Connection'), findsOneWidget);
    expect(find.text('Bring your own AI'), findsOneWidget);
    expect(find.text('API key'), findsOneWidget);
    expect(find.text('Endpoint'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
  });
}
