import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/data/shelf_database.dart';
import 'package:shelf/data/shelf_store.dart';
import 'package:shelf/models/color_label.dart';
import 'package:shelf/models/library_document.dart';
import 'package:shelf/models/note.dart';
import 'package:shelf/models/note_selection.dart';
import 'package:shelf/screens/home_shell.dart';
import 'package:shelf/screens/library_screen.dart';
import 'package:shelf/services/ai_secure_storage.dart';
import 'package:shelf/services/ai_settings_controller.dart';
import 'package:shelf/services/export_share.dart';
import 'package:shelf/services/notes_export.dart';
import 'package:shelf/services/pdf_outline_source.dart';
import 'package:shelf/services/pdf_section_resolver.dart';
import 'package:shelf/theme/shelf_theme.dart';
import 'package:shelf/widgets/ai_scope.dart';
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

  Future<void> seed() async {
    await db.upsertDocument(
      LibraryDocument(
        id: 'pdf-1',
        title: 'Notes on method',
        storedName: 'pdf-1.pdf',
        importedAt: DateTime.utc(2026, 9, 13),
        pageCount: 8,
      ),
    );
    await db.upsertNote(
      Note(
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
      ),
    );
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
    await ai.saveApiKey('sk-test-not-a-real-key');
    PdfOutlineSource.loadForDocumentOverride = (_, _) async => const [];
  });

  tearDown(() async {
    ExportShare.override = null;
    ExportShare.lastSharePositionOrigin = null;
    ExportShare.lastShareAttachedOrigin = false;
    PdfOutlineSource.loadForDocumentOverride = null;
    await db.close();
  });

  Future<void> pumpLibrary(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      AiScope(
        controller: ai,
        child: MaterialApp(
          theme: ShelfTheme.light(),
          home: LibraryScreen(store: store),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('library card menu lists export, send, and view', (tester) async {
    await pumpLibrary(tester);
    expect(find.byKey(const Key('library-highlight-tip')), findsOneWidget);
    expect(
      find.text(LibraryScreen.highlightTip),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('library-card-menu-pdf-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Export comments'), findsOneWidget);
    expect(find.text('Send to connected AI'), findsOneWidget);
    expect(find.text('View all comments'), findsOneWidget);
  });

  testWidgets('library ⋮ button box is a usable non-zero share origin', (
    tester,
  ) async {
    await pumpLibrary(tester);
    final button = find.byKey(const Key('library-card-menu-pdf-1'));
    expect(button, findsOneWidget);
    final box = tester.renderObject<RenderBox>(button);
    expect(box.hasSize, isTrue);
    expect(box.size.width, greaterThan(0));
    expect(box.size.height, greaterThan(0));
    final fromBox = box.localToGlobal(Offset.zero) & box.size;
    const view = Size(400, 900);
    expect(ShareOrigin.isUsable(fromBox, view), isTrue);
    expect(
      ShareOrigin.resolve(preferred: fromBox, viewSize: view),
      fromBox,
    );
  });

  test('Export comments writes JSON and schema then shares them', () async {
    final shared = <String>[];
    ExportShare.override = (paths, subject) async {
      shared
        ..clear()
        ..addAll(paths);
      expect(subject, contains('Notes on method'));
    };
    addTearDown(() => ExportShare.override = null);

    final dir = await Directory.systemTemp.createTemp('shelf-export-widget-');
    addTearDown(() => dir.delete(recursive: true));
    await LibraryScreen.exportDocumentComments(
      document: store.documents.single,
      notes: store.notesForDocument('pdf-1'),
      labelById: store.labelById,
      directory: dir,
    );

    expect(shared, hasLength(2));
    expect(shared.first, endsWith('Notes-on-method-notes.json'));
    expect(shared.last, endsWith('Notes-on-method-notes-schema.md'));
    expect(ExportShare.lastSharePositionOrigin, isNot(Rect.zero));
    expect(ExportShare.lastSharePositionOrigin!.width, greaterThan(0));
    expect(
      File(shared.first).readAsStringSync(),
      contains('Come back to this diagram.'),
    );
    expect(File(shared.last).readAsStringSync(), contains('selected_text'));
    expect(File(shared.last).readAsStringSync(), contains('heading'));
    expect(File(shared.last).readAsStringSync(), contains('subheading'));
  });

  test('Export comments JSON includes heading fields from a mock outline', () async {
    final shared = <String>[];
    ExportShare.override = (paths, subject) async {
      shared
        ..clear()
        ..addAll(paths);
    };
    addTearDown(() => ExportShare.override = null);

    final dir = await Directory.systemTemp.createTemp('shelf-export-headings-');
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
    await LibraryScreen.exportDocumentComments(
      document: store.documents.single,
      notes: store.notesForDocument('pdf-1'),
      labelById: store.labelById,
      directory: dir,
      outline: outline,
    );

    final json = File(shared.first).readAsStringSync();
    expect(json, contains('"heading": "Chapter 3 Method"'));
    expect(json, contains('"subheading": "3.2 Standing remark"'));
    expect(File(shared.last).readAsStringSync(), contains('heading'));
  });

  test('Send-to-AI snippets include heading and subheading from outline', () {
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
    final snippets = NotesExport.snippets(
      notes: store.notesForDocument('pdf-1'),
      labelById: store.labelById,
      outline: outline,
    );
    expect(snippets, hasLength(1));
    expect(snippets.single.heading, 'Chapter 3 Method');
    expect(snippets.single.subheading, '3.2 Standing remark');
    expect(snippets.single.text, 'Come back to this diagram.');
  });

  testWidgets('Send to connected AI offers Include PDF vs Notes only', (
    tester,
  ) async {
    await pumpLibrary(tester);
    await tester.tap(find.byKey(const Key('library-card-menu-pdf-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-card-send-to-ai')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai-send-scope-dialog')), findsOneWidget);
    expect(find.text('Notes only'), findsOneWidget);
    expect(find.text('Include PDF'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ai-send-scope-notes-only')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(fake.lastAsk, isNotNull);
    expect(fake.lastAsk!.documentTitle, 'Notes on method');
    expect(fake.lastAsk!.notes, hasLength(1));
    expect(fake.lastAsk!.notes.single.text, 'Come back to this diagram.');
    expect(fake.lastAsk!.hasPdf, isFalse);
    expect(find.byKey(const Key('ask-about-note-result')), findsOneWidget);
  });

  testWidgets('View all comments jumps to Notes with the book title', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      AiScope(
        controller: ai,
        child: MaterialApp(
          theme: ShelfTheme.light(),
          home: HomeShell(store: store),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('library-card-menu-pdf-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-card-view-comments')));
    await tester.pumpAndSettle();

    expect(find.text('Notes'), findsWidgets);
    final field = tester.widget<TextField>(
      find.byKey(const Key('notes-hub-search')),
    );
    expect(field.controller?.text, 'Notes on method');
    expect(find.text('Come back to this diagram.'), findsOneWidget);
  });
}
