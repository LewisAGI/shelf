import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/data/shelf_database.dart';
import 'package:shelf/data/shelf_store.dart';
import 'package:shelf/models/ai_provider.dart';
import 'package:shelf/screens/settings_screen.dart';
import 'package:shelf/services/ai_secure_storage.dart';
import 'package:shelf/services/ai_settings_controller.dart';
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
  late AiSettingsController ai;

  setUp(() async {
    db = ShelfDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    store = ShelfStore(database: db);
    await store.init();
    storage = MemoryAiSecureStorage();
    ai = AiSettingsController(storage: storage, client: FakeAiClient());
    await ai.load();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      AiScope(
        controller: ai,
        child: MaterialApp(
          theme: ShelfTheme.light(),
          home: SettingsScreen(store: store),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Connect your own AI has provider, key, save, model, and Grok', (
    tester,
  ) async {
    await pumpSettings(tester);
    final pageScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Connect your own AI'),
      300,
      scrollable: pageScroll,
    );

    expect(find.text('Connect your own AI'), findsOneWidget);
    expect(find.text('Connection'), findsNothing);
    expect(find.text('Status'), findsNothing);
    expect(find.text('Sync'), findsNothing);
    expect(find.text('Provider'), findsOneWidget);
    expect(find.text('API key'), findsOneWidget);
    expect(find.text('Save key'), findsOneWidget);
    expect(find.byKey(const Key('settings-ai-toggle-key')), findsOneWidget);
    expect(find.text('Model'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-ai-provider')));
    await tester.pumpAndSettle();
    expect(find.text('Grok (xAI)'), findsWidgets);
    expect(find.text('Anthropic'), findsWidgets);
    await tester.tap(find.byKey(const Key('settings-ai-provider-grok')));
    await tester.pumpAndSettle();
    expect(ai.provider, AiProvider.grok);
    expect(ai.model, 'grok-4.6');
    expect(find.text('grok-4.6'), findsWidgets);
  });

  testWidgets('provider switch keeps each saved key', (tester) async {
    await pumpSettings(tester);
    final pageScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-ai-api-key')),
      300,
      scrollable: pageScroll,
    );
    await tester.enterText(
      find.byKey(const Key('settings-ai-api-key')),
      'sk-openai-test-not-real',
    );
    await tester.tap(find.byKey(const Key('settings-ai-save-key')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('settings-ai-provider')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-ai-provider-anthropic')));
    await tester.pumpAndSettle();
    expect(ai.provider, AiProvider.anthropic);
    expect(ai.hasApiKey, isFalse);

    await tester.enterText(
      find.byKey(const Key('settings-ai-api-key')),
      'sk-ant-test-not-real',
    );
    await tester.tap(find.byKey(const Key('settings-ai-save-key')));
    await tester.pump();
    expect(ai.connection.apiKey, 'sk-ant-test-not-real');

    await tester.tap(find.byKey(const Key('settings-ai-provider')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-ai-provider-openai')));
    await tester.pumpAndSettle();
    expect(ai.connection.apiKey, 'sk-openai-test-not-real');
    expect(ai.model, 'gpt-4o-mini');
  });

  testWidgets('custom model shows a warning field', (tester) async {
    await pumpSettings(tester);
    final pageScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-ai-model')),
      400,
      scrollable: pageScroll,
    );
    await tester.tap(find.byKey(const Key('settings-ai-model')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-ai-custom-model')), findsOneWidget);
    expect(
      find.textContaining('may error if the provider does not recognise'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('settings-ai-custom-model')),
      'my-local-model',
    );
    await tester.pump();
    expect(ai.model, 'my-local-model');
    expect(ai.isCustomModel, isTrue);
  });
}
