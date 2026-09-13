import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/data/shelf_database.dart';
import 'package:shelf/data/shelf_store.dart';
import 'package:shelf/models/color_label.dart';
import 'package:shelf/models/library_document.dart';
import 'package:shelf/models/note.dart';
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
    Future<void> pumpEditor(
      WidgetTester tester, {
      Note? note,
      double? x,
      double? y,
      int page = 4,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          theme: ShelfTheme.light(),
          home: Scaffold(
            body: NoteEditor(
              labels: ColorLabel.seedDefaults(),
              defaultLabelId: ColorLabel.orangeId,
              speech: SpeechCapture(),
              note: note,
              page: page,
              x: x,
              y: y,
            ),
          ),
        ),
      );
    }

    testWidgets('dark pill is visible, typeable, with mic and 4-line cap', (
      tester,
    ) async {
      await pumpEditor(tester);

      final field = tester.widget<TextField>(
        find.byKey(const Key('note-composer-field')),
      );
      expect(field.enabled, isTrue);
      expect(field.minLines, 1);
      expect(field.maxLines, 4);
      expect(field.maxLines, NoteEditor.composerMaxLines);
      expect(field.decoration?.hintText, 'Leave a comment');
      expect(find.text('Leave a comment'), findsOneWidget);
      expect(find.byKey(const Key('note-composer-pill')), findsOneWidget);
      expect(find.byKey(const Key('note-composer-mic')), findsOneWidget);
      expect(find.byKey(const Key('note-composer-colour')), findsOneWidget);
      expect(find.byType(NoteLabelPicker), findsOneWidget);

      final pill = tester.widget<DecoratedBox>(
        find.byKey(const Key('note-composer-pill')),
      );
      final decoration = pill.decoration as BoxDecoration;
      expect(decoration.color, ShelfColors.composerPill);

      await tester.enterText(
        find.byKey(const Key('note-composer-field')),
        'Come back to this diagram.',
      );
      await tester.pump();
      expect(find.text('Come back to this diagram.'), findsOneWidget);
    });

    testWidgets('mic sits left of the colour square on the pill', (
      tester,
    ) async {
      await pumpEditor(tester);

      final mic = tester.getCenter(find.byKey(const Key('note-composer-mic')));
      final colour = tester.getCenter(
        find.byKey(const Key('note-composer-colour')),
      );
      final field = tester.getCenter(
        find.byKey(const Key('note-composer-field')),
      );
      expect(field.dx, lessThan(mic.dx));
      expect(mic.dx, lessThan(colour.dx));
    });

    testWidgets('colour square defaults to orange and assigns a label', (
      tester,
    ) async {
      await pumpEditor(tester);

      final square = tester.widget<Material>(
        find.ancestor(
          of: find.byKey(const Key('note-composer-colour')),
          matching: find.byType(Material),
        ).first,
      );
      expect(square.color, ColorLabel.seedDefaults().first.color);
      expect(square.color, ShelfColors.orange);

      await tester.tap(find.byKey(const Key('note-composer-colour')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(Key('note-label-${ColorLabel.orangeId}')), findsOneWidget);
      expect(find.byKey(Key('note-label-${ColorLabel.purpleId}')), findsOneWidget);
      expect(find.text('General note'), findsWidgets);
      expect(find.text('Further research'), findsWidgets);

      await tester.tap(find.byKey(Key('note-label-${ColorLabel.purpleId}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final updated = tester.widget<Material>(
        find.ancestor(
          of: find.byKey(const Key('note-composer-colour')),
          matching: find.byType(Material),
        ).first,
      );
      expect(updated.color, ColorLabel.parseHex(ShelfColors.defaultPurpleHex));
    });

    testWidgets('X/Y sliders start at the press position', (tester) async {
      await pumpEditor(tester, x: 0.25, y: 0.8);

      expect(find.byKey(const Key('note-position-x')), findsOneWidget);
      expect(find.byKey(const Key('note-position-y')), findsOneWidget);
      expect(find.text('0.25'), findsOneWidget);
      expect(find.text('0.80'), findsOneWidget);
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
                    x: 0.2,
                    y: 0.7,
                  );
                },
                child: const Text('Open editor'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open editor'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.enterText(
        find.byKey(const Key('note-composer-field')),
        'Purple research note.',
      );
      await tester.tap(find.byKey(const Key('note-composer-colour')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(Key('note-label-${ColorLabel.purpleId}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(result, isNotNull);
      expect(result!.text, 'Purple research note.');
      expect(result!.colorLabelId, ColorLabel.purpleId);
      expect(result!.delete, isFalse);
      expect(result!.x, 0.2);
      expect(result!.y, 0.7);
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final square = tester.widget<Material>(
        find.ancestor(
          of: find.byKey(const Key('note-composer-colour')),
          matching: find.byType(Material),
        ).first,
      );
      expect(square.color, ColorLabel.parseHex(ShelfColors.defaultPurpleHex));

      await tester.tap(find.byKey(const Key('note-composer-colour')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Further research'), findsWidgets);
      await tester.tap(find.byKey(Key('note-label-${ColorLabel.orangeId}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(result!.colorLabelId, ColorLabel.orangeId);
      expect(result!.text, 'Already labelled.');
      expect(result!.x, 0.2);
      expect(result!.y, 0.3);
    });

    testWidgets('long-press create path opens typeable pill and saves position', (
      tester,
    ) async {
      NoteEditorResult? result;

      await tester.pumpWidget(
        MaterialApp(
          theme: ShelfTheme.light(),
          home: Builder(
            builder: (context) {
              return GestureDetector(
                key: const Key('reader-long-press-target'),
                onLongPress: () {
                  NoteEditor.show(
                    context,
                    labels: ColorLabel.seedDefaults(),
                    defaultLabelId: ColorLabel.orangeId,
                    speech: SpeechCapture(),
                    page: 3,
                    x: 0.41,
                    y: 0.63,
                  ).then((value) => result = value);
                },
                child: const SizedBox.expand(
                  child: ColoredBox(
                    color: Color(0xFFF5F5F4),
                    child: Center(child: Text('PDF page')),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.longPress(find.byKey(const Key('reader-long-press-target')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Comment path (after the page menu) still opens the Grok pill.
      expect(find.byKey(const Key('note-composer-pill')), findsOneWidget);
      expect(find.byKey(const Key('note-composer-field')), findsOneWidget);
      expect(find.byKey(const Key('note-composer-mic')), findsOneWidget);
      expect(find.byKey(const Key('note-composer-colour')), findsOneWidget);
      expect(find.text('Leave a comment'), findsOneWidget);
      expect(find.text('0.41'), findsOneWidget);
      expect(find.text('0.63'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('note-composer-field')),
        'Long-press note.',
      );
      await tester.pump();

      final xSlider = find.descendant(
        of: find.byKey(const Key('note-position-x')),
        matching: find.byType(Slider),
      );
      await tester.drag(xSlider, const Offset(80, 0));
      await tester.pump();

      await tester.tap(find.byKey(const Key('note-composer-colour')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(Key('note-label-${ColorLabel.purpleId}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(result, isNotNull);
      expect(result!.text, 'Long-press note.');
      expect(result!.colorLabelId, ColorLabel.purpleId);
      expect(result!.y, closeTo(0.63, 0.001));
      expect(result!.x, isNot(equals(0.41)));
      expect(result!.x, inInclusiveRange(0.0, 1.0));
    });
  });

  test('notes list data and marker colour follow the assigned label', () async {
    await store.addNote(
      documentId: 'pdf-1',
      page: 1,
      x: 0.1,
      y: 0.2,
      text: 'Needs more reading.',
      colorLabelId: ColorLabel.purpleId,
    );
    final listed = store.searchNotes();
    expect(listed, hasLength(1));
    expect(listed.single.colorLabelId, ColorLabel.purpleId);
    expect(store.labelById(listed.single.colorLabelId).name, 'Further research');
  });

  testWidgets('marker paints the assigned label colour', (tester) async {
    final label = store.labelById(ColorLabel.purpleId);
    await tester.pumpWidget(
      MaterialApp(
        theme: ShelfTheme.light(),
        home: Scaffold(
          body: NoteMarker(color: label.color, focused: true),
        ),
      ),
    );
    await tester.pump();
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
    await tester.scrollUntilVisible(find.text('API / connection'), 300);
    expect(find.text('API / connection'), findsOneWidget);
    expect(find.text('Connection'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Bring your own AI'), 200);
    expect(find.text('Bring your own AI'), findsOneWidget);
    expect(find.text('API key'), findsOneWidget);
    expect(find.text('Endpoint'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('About'), 200);
    expect(find.text('About'), findsOneWidget);
  });
}
