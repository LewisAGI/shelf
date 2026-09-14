import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/data/shelf_database.dart';
import 'package:shelf/data/shelf_store.dart';
import 'package:shelf/models/ai_provider.dart';
import 'package:shelf/models/color_label.dart';
import 'package:shelf/models/library_document.dart';
import 'package:shelf/models/note.dart';
import 'package:shelf/models/note_selection.dart';
import 'package:shelf/screens/settings_screen.dart';
import 'package:shelf/services/ai_secure_storage.dart';
import 'package:shelf/services/ai_settings_controller.dart';
import 'package:shelf/services/speech_capture.dart';
import 'package:shelf/theme/shelf_theme.dart';
import 'package:shelf/widgets/ai_scope.dart';
import 'package:shelf/services/pdf_section_resolver.dart';
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

  testWidgets('Ask about this note sends note + selected_text via mock client', (
    tester,
  ) async {
    await ai.saveApiKey('sk-test-not-a-real-key');
    fake.askReply = 'A mock reading of the selection.';

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

    await pumpScoped(
      tester,
      Scaffold(
        body: NoteEditor(
          labels: ColorLabel.seedDefaults(),
          defaultLabelId: ColorLabel.orangeId,
          speech: SpeechCapture(),
          note: note,
          documentTitle: 'Notes on method',
          quotedText: note.selection?.text,
        ),
      ),
    );

    expect(find.byKey(const Key('ask-about-note')), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.text('Add your own API key'), findsNothing);
    await tester.tap(find.byKey(const Key('ask-about-note')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('ask-about-note-result')), findsOneWidget);
    expect(find.text('A mock reading of the selection.'), findsOneWidget);
    expect(fake.lastAsk, isNotNull);
    expect(fake.lastAsk!.noteText, 'Come back to this diagram.');
    expect(fake.lastAsk!.selectedText, 'method');
    expect(fake.lastAsk!.documentTitle, 'Notes on method');
    expect(fake.lastAsk!.page, 2);
    expect(fake.lastAskConnection?.apiKey, 'sk-test-not-a-real-key');
  });

  testWidgets('composer hides Ask about this note when no API key is set', (
    tester,
  ) async {
    await pumpScoped(
      tester,
      Scaffold(
        body: NoteEditor(
          labels: ColorLabel.seedDefaults(),
          defaultLabelId: ColorLabel.orangeId,
          speech: SpeechCapture(),
          page: 1,
          x: 0.2,
          y: 0.3,
          documentTitle: 'Notes on method',
        ),
      ),
    );

    expect(find.byKey(const Key('note-composer-pill')), findsOneWidget);
    expect(find.byKey(const Key('ask-about-note')), findsNothing);
    expect(find.text('Ask about this note'), findsNothing);
    expect(find.textContaining('Add your own API key'), findsNothing);
    expect(fake.lastAsk, isNull);
  });

  testWidgets('Ask without a key points at Settings and does not call HTTP', (
    tester,
  ) async {
    await pumpScoped(
      tester,
      const Scaffold(
        body: AskAboutNoteButton(
          noteText: _fixedNote,
          selectedText: 'method',
          documentTitle: 'Notes on method',
          page: 1,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('ask-about-note')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Add your own API key'), findsOneWidget);
    expect(fake.lastAsk, isNull);
    expect(find.byKey(const Key('ask-about-note-result')), findsNothing);
  });

  test('Ask request includes note text, selected_text, title, and page', () {
    final request = AskAboutNoteButton.requestFor(
      noteText: 'Look this up.',
      selectedText: 'standing remark',
      documentTitle: 'Notes on method',
      page: 3,
    );
    expect(request.noteText, 'Look this up.');
    expect(request.selectedText, 'standing remark');
    expect(request.documentTitle, 'Notes on method');
    expect(request.page, 3);
    expect(request.heading, isNull);
    expect(request.subheading, isNull);
    expect(request.hasAnythingToAsk, isTrue);
  });

  test('Ask request resolves heading and subheading from a mock outline', () {
    final note = Note(
      id: 'note-1',
      documentId: 'pdf-1',
      page: 2,
      x: 0.3,
      y: 0.55,
      text: 'Look this up.',
      colorLabelId: ColorLabel.orangeId,
      createdAt: DateTime.utc(2026, 9, 14),
      updatedAt: DateTime.utc(2026, 9, 14),
    );
    final sections = PdfSectionResolver.flattenDraft(const [
      OutlineDraft(
        title: 'Chapter 3 Method',
        page: 2,
        y: 0.05,
        children: [
          OutlineDraft(title: '3.2 Standing remark', page: 2, y: 0.40),
        ],
      ),
    ]);
    final request = AskAboutNoteButton.requestFor(
      noteText: note.text,
      selectedText: 'standing remark',
      documentTitle: 'Notes on method',
      page: note.page,
      note: note,
      sections: sections,
    );
    expect(request.heading, 'Chapter 3 Method');
    expect(request.subheading, '3.2 Standing remark');
    expect(request.page, 2);
  });

  testWidgets('Ask about this note payload includes heading and subheading', (
    tester,
  ) async {
    await ai.saveApiKey('sk-test-not-a-real-key');
    final sections = PdfSectionResolver.flattenDraft(const [
      OutlineDraft(
        title: 'Chapter 3 Method',
        page: 2,
        y: 0.05,
        children: [
          OutlineDraft(title: '3.2 Standing remark', page: 2, y: 0.10),
        ],
      ),
    ]);
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

    await pumpScoped(
      tester,
      Scaffold(
        body: NoteEditor(
          labels: ColorLabel.seedDefaults(),
          defaultLabelId: ColorLabel.orangeId,
          speech: SpeechCapture(),
          note: note,
          documentTitle: 'Notes on method',
          quotedText: note.selection?.text,
          sections: sections,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('ask-about-note')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(fake.lastAsk, isNotNull);
    expect(fake.lastAsk!.heading, 'Chapter 3 Method');
    expect(fake.lastAsk!.subheading, '3.2 Standing remark');
    expect(fake.lastAsk!.selectedText, 'method');
  });

  testWidgets('Settings Test connection success and failure', (tester) async {
    await pumpScoped(tester, SettingsScreen(store: store));
    await tester.pump();

    final pageScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Connect your own AI'),
      300,
      scrollable: pageScroll,
    );
    expect(find.text('Connect your own AI'), findsOneWidget);
    expect(find.text('Connection'), findsNothing);
    expect(find.text('API / connection'), findsNothing);
    expect(find.text('Provider'), findsOneWidget);
    expect(find.text('API key'), findsOneWidget);
    expect(find.text('Save key'), findsOneWidget);
    expect(find.text('Grok (xAI)'), findsNothing);
    expect(find.text('Coming in a later release'), findsNothing);
    expect(find.byType(Slider), findsNothing);

    await tester.enterText(
      find.byKey(const Key('settings-ai-api-key')),
      'sk-test-not-a-real-key',
    );
    fake.verifyResult = const AiVerifyResult(
      ok: true,
      message: 'Connected. Provider listed 4 models.',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-ai-test-connection')),
      200,
      scrollable: pageScroll,
    );
    await tester.tap(find.byKey(const Key('settings-ai-test-connection')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Connected. Provider listed 4 models.'), findsOneWidget);
    expect(ai.hasApiKey, isTrue);
    expect(
      storage.snapshot[AiSettingsController.apiKeyStorageKey(ai.provider)],
      isNotEmpty,
    );
    expect(
      storage.snapshot[AiSettingsController.apiKeyStorageKey(ai.provider)],
      isNot(contains('sk-live')),
    );
    expect(fake.lastVerify?.apiKey, 'sk-test-not-a-real-key');

    fake.verifyResult = const AiVerifyResult(
      ok: false,
      message: 'HTTP 401: Incorrect API key provided',
    );
    await tester.tap(find.byKey(const Key('settings-ai-test-connection')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('HTTP 401'), findsOneWidget);
  });
}

String _fixedNote() => 'Come back to this diagram.';
