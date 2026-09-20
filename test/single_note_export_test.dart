import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/data/shelf_database.dart';
import 'package:shelf/data/shelf_store.dart';
import 'package:shelf/models/color_label.dart';
import 'package:shelf/models/library_document.dart';
import 'package:shelf/models/note.dart';
import 'package:shelf/models/note_selection.dart';
import 'package:shelf/screens/notes_hub_screen.dart';
import 'package:shelf/services/ai_secure_storage.dart';
import 'package:shelf/services/ai_settings_controller.dart';
import 'package:shelf/services/export_share.dart';
import 'package:shelf/services/notes_export.dart';
import 'package:shelf/services/pdf_section_resolver.dart';
import 'package:shelf/services/speech_capture.dart';
import 'package:shelf/theme/shelf_theme.dart';
import 'package:shelf/widgets/ai_scope.dart';
import 'package:shelf/widgets/ask_about_note.dart';
import 'package:shelf/widgets/note_editor.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_ai_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late ShelfDatabase db;
  late ShelfStore store;
  late MemoryAiSecureStorage storage;
  late FakeAiClient fake;
  late AiSettingsController ai;

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
    createdAt: DateTime.utc(2026, 9, 13),
    updatedAt: DateTime.utc(2026, 9, 13),
    selection: const NoteSelection(
      text: 'method',
      left: 0.2,
      top: 0.2,
      right: 0.4,
      bottom: 0.25,
    ),
  );

  Future<void> seed() async {
    await db.upsertDocument(document);
    await db.upsertNote(note);
  }

  setUp(() async {
    db = ShelfDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    await seed();
    store = ShelfStore(database: db);
    await store.init();
    storage = MemoryAiSecureStorage();
    fake = FakeAiClient();
    ai = AiSettingsController(storage: storage, client: fake);
    await ai.load();
  });

  tearDown(() async {
    ExportShare.override = null;
    ExportShare.lastSharePositionOrigin = null;
    ExportShare.lastShareAttachedOrigin = false;
    await db.close();
  });

  Future<void> pumpScoped(
    WidgetTester tester,
    Widget home, {
    Size size = const Size(400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      AiScope(
        controller: ai,
        child: MaterialApp(
          theme: ShelfTheme.light(),
          home: home,
        ),
      ),
    );
    await tester.pump();
  }

  test('exportSingleNote shares JSON with document file_name and headings',
      () async {
    final shared = <String>[];
    ExportShare.override = (paths, subject) async {
      shared
        ..clear()
        ..addAll(paths);
      expect(subject, contains('Notes on method'));
    };
    final dir = await Directory.systemTemp.createTemp('shelf-single-share-');
    addTearDown(() => dir.delete(recursive: true));
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

    await AskAboutNoteButton.exportSingleNote(
      document: document,
      note: note,
      labelById: store.labelById,
      kind: SingleNoteShareKind.noteGuide,
      directory: dir,
      outline: outline,
      sharePositionOrigin: Rect.zero,
    );

    expect(shared, hasLength(2));
    expect(shared.first, endsWith('Notes-on-method-note.json'));
    expect(shared.last, endsWith('Notes-on-method-note-schema.md'));
    expect(ExportShare.lastSharePositionOrigin, isNot(Rect.zero));
    expect(ExportShare.lastSharePositionOrigin!.width, greaterThan(0));
    final payload = jsonDecode(File(shared.first).readAsStringSync())
        as Map<String, dynamic>;
    expect(payload['schema'], NotesExport.schemaId);
    expect(
      (payload['document'] as Map<String, dynamic>)['file_name'],
      'Notes on method.pdf',
    );
    expect(
      (payload['document'] as Map<String, dynamic>)['title'],
      'Notes on method',
    );
    final row = (payload['notes'] as List<dynamic>).single as Map<String, dynamic>;
    expect(row['heading'], 'Chapter 3 Method');
    expect(row['subheading'], '3.2 Standing remark');
    expect(row['selected_text'], 'method');
  });

  test('exportSingleNote note+PDF+guide attaches three files', () async {
    final shared = <String>[];
    ExportShare.override = (paths, subject) async {
      shared
        ..clear()
        ..addAll(paths);
    };
    final dir = await Directory.systemTemp.createTemp('shelf-single-pdf-');
    addTearDown(() => dir.delete(recursive: true));

    await AskAboutNoteButton.exportSingleNote(
      document: document,
      note: note,
      labelById: store.labelById,
      kind: SingleNoteShareKind.notePdfGuide,
      directory: dir,
      pdfBytes: const [0x25, 0x50, 0x44, 0x46],
    );

    expect(shared, hasLength(3));
    expect(shared[0], endsWith('Notes-on-method-note.json'));
    expect(shared[1], endsWith('Notes-on-method-note-schema.md'));
    expect(shared[2], endsWith('Notes on method.pdf'));
  });

  testWidgets('Ask AI on an open note offers Ask and Export, then four shares',
      (tester) async {
    await pumpScoped(
      tester,
      Scaffold(
        body: NoteEditor(
          labels: ColorLabel.seedDefaults(),
          defaultLabelId: ColorLabel.orangeId,
          speech: SpeechCapture(),
          note: note,
          document: document,
          documentTitle: document.title,
          quotedText: note.selection?.text,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('ask-about-note')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('ask-with-your-ai')), findsOneWidget);
    expect(find.byKey(const Key('export-share-note')), findsOneWidget);

    await tester.tap(find.byKey(const Key('export-share-note')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Note + PDF + guide'), findsOneWidget);
    expect(find.text('Note + PDF'), findsOneWidget);
    expect(find.text('Note + guide'), findsOneWidget);
    expect(find.text('Note only'), findsOneWidget);
    expect(find.byKey(const Key('export-note-pdf-guide')), findsOneWidget);
    expect(find.byKey(const Key('export-note-pdf')), findsOneWidget);
    expect(find.byKey(const Key('export-note-guide')), findsOneWidget);
    expect(find.byKey(const Key('export-note-only')), findsOneWidget);
    expect(fake.lastAsk, isNull);
  });

  testWidgets('Notes hub Ask AI opens the same chooser', (tester) async {
    await pumpScoped(tester, NotesHubScreen(store: store));

    await tester.tap(find.byKey(const Key('ask-about-note-note-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Ask with your AI'), findsOneWidget);
    expect(find.text('Export / Share note'), findsOneWidget);
  });

  test('noteForExport keeps heading-ready fields from the open note', () {
    final exported = AskAboutNoteButton.noteForExport(
      noteText: 'Updated comment.',
      selectedText: 'method',
      note: note,
      document: document,
    );
    expect(exported.id, 'note-1');
    expect(exported.documentId, 'pdf-1');
    expect(exported.text, 'Updated comment.');
    expect(exported.page, 2);
    expect(exported.selection?.text, 'method');
    expect(exported.colorLabelId, ColorLabel.orangeId);
  });
}
