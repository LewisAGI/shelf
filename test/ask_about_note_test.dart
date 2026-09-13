import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/data/shelf_database.dart';
import 'package:shelf/data/shelf_store.dart';
import 'package:shelf/models/ai_provider.dart';
import 'package:shelf/models/color_label.dart';
import 'package:shelf/models/library_document.dart';
import 'package:shelf/models/note.dart';
import 'package:shelf/models/note_selection.dart';
import 'package:shelf/screens/notes_hub_screen.dart';
import 'package:shelf/screens/settings_screen.dart';
import 'package:shelf/services/ai_secure_storage.dart';
import 'package:shelf/services/ai_settings_controller.dart';
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
    await tester.pumpWidget(
      AiScope(
        controller: ai,
        child: MaterialApp(
          theme: ShelfTheme.light(),
          home: home,
        ),
      ),
    );
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
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

  testWidgets('Notes hub Ask uses the row note and selected_text', (
    tester,
  ) async {
    await ai.saveApiKey('sk-test-not-a-real-key');
    await store.addNote(
      documentId: 'pdf-1',
      page: 3,
      x: 0.2,
      y: 0.3,
      text: 'Look this up.',
      selection: const NoteSelection(
        text: 'standing remark',
        left: 0.1,
        top: 0.1,
        right: 0.3,
        bottom: 0.15,
      ),
    );

    await pumpScoped(tester, NotesHubScreen(store: store));
    final noteId = store.notes.single.id;
    await tester.tap(find.byKey(Key('ask-about-note-$noteId')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('ask-about-note-result')), findsOneWidget);
    expect(fake.lastAsk!.noteText, 'Look this up.');
    expect(fake.lastAsk!.selectedText, 'standing remark');
    expect(fake.lastAsk!.documentTitle, 'Notes on method');
    expect(fake.lastAsk!.page, 3);
  });

  testWidgets('Settings Test connection success and failure', (tester) async {
    await pumpScoped(tester, SettingsScreen(store: store));
    await tester.pump();

    await tester.scrollUntilVisible(find.text('Bring your own AI'), 300);
    expect(find.text('API / connection'), findsOneWidget);
    expect(find.text('Connection'), findsOneWidget);
    expect(find.text('Provider'), findsOneWidget);
    expect(find.text('API key'), findsOneWidget);
    expect(find.text('Endpoint'), findsOneWidget);
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
    );
    await tester.tap(find.byKey(const Key('settings-ai-test-connection')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Connected. Provider listed 4 models.'), findsOneWidget);
    expect(ai.hasApiKey, isTrue);
    expect(storage.snapshot[AiSettingsController.apiKeyKey], isNotEmpty);
    expect(
      storage.snapshot[AiSettingsController.apiKeyKey],
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
