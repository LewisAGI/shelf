import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shelf/data/shelf_database.dart';
import 'package:shelf/data/shelf_store.dart';
import 'package:shelf/models/color_label.dart';
import 'package:shelf/models/library_document.dart';
import 'package:shelf/models/note.dart';
import 'package:shelf/models/note_selection.dart';
import 'package:shelf/screens/library_screen.dart';
import 'package:shelf/screens/notes_hub_screen.dart';
import 'package:shelf/screens/reader_screen.dart';
import 'package:shelf/services/ai_secure_storage.dart';
import 'package:shelf/services/ai_settings_controller.dart';
import 'package:shelf/services/export_share.dart';
import 'package:shelf/services/pdf_outline_source.dart';
import 'package:shelf/theme/shelf_theme.dart';
import 'package:shelf/widgets/ai_scope.dart';
import 'package:shelf/widgets/markdown_preview_sheet.dart';
import 'package:shelf/widgets/page_jump_sheet.dart';
import 'package:shelf/widgets/page_press_menu.dart';
import 'package:shelf/widgets/reader_menu.dart';
import 'package:shelf/widgets/selection_comment_bar.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_ai_client.dart';
import 'support/flush_export.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late ShelfDatabase db;
  late ShelfStore store;

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
    await db.upsertDocument(
      LibraryDocument(
        id: 'pdf-2',
        title: 'Field guide',
        storedName: 'pdf-2.pdf',
        importedAt: DateTime.utc(2026, 9, 14),
        pageCount: 24,
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
    await db.upsertNote(
      Note(
        id: 'note-2',
        documentId: 'pdf-1',
        page: 5,
        x: 0.2,
        y: 0.5,
        text: 'Check the later chapter.',
        colorLabelId: ColorLabel.purpleId,
        createdAt: DateTime.utc(2026, 9, 14),
        updatedAt: DateTime.utc(2026, 9, 14),
      ),
    );
  }

  setUp(() async {
    db = ShelfDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    await seed();
    store = ShelfStore(database: db);
    await store.init();
    PdfOutlineSource.loadForDocumentOverride = (_, _) async => const [];
  });

  tearDown(() async {
    ExportShare.override = null;
    ExportShare.lastSharePositionOrigin = null;
    PdfOutlineSource.loadForDocumentOverride = null;
    await db.close();
  });

  Future<void> pumpLibrary(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = MemoryAiSecureStorage();
    final ai = AiSettingsController(storage: storage, client: FakeAiClient());
    await ai.load();
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

  testWidgets('library is a two-column cover grid', (tester) async {
    await pumpLibrary(tester);
    expect(find.byKey(const Key('library-grid')), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    expect(find.text('Import PDF'), findsNothing);

    final first = tester.getTopLeft(find.byKey(const Key('library-card-menu-pdf-1')));
    final second = tester.getTopLeft(find.byKey(const Key('library-card-menu-pdf-2')));
    expect((second.dx - first.dx).abs(), greaterThan(40));
    expect((second.dy - first.dy).abs(), lessThan(24));
    expect(find.text('Notes on method'), findsOneWidget);
    expect(find.text('Field guide'), findsOneWidget);
  });

  testWidgets('export comments opens the markdown preview, then shares', (
    tester,
  ) async {
    final shared = <String>[];
    ExportShare.override = (paths, subject) async {
      shared
        ..clear()
        ..addAll(paths);
      expect(subject, contains('Notes on method'));
    };
    await pumpLibrary(tester);
    await tester.tap(find.byKey(const Key('library-card-menu-pdf-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('library-card-export-comments')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SnackBar), findsNothing);
    expect(find.byKey(const Key('markdown-preview-sheet')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('markdown-preview-filename'))).data,
      'Notes on method',
    );
    expect(find.text('Notes-on-method-notes-schema.md'), findsNothing);
    expect(find.textContaining('Come back to this diagram.'), findsOneWidget);
    expect(find.textContaining('Check the later chapter.'), findsOneWidget);
    expect(find.textContaining('Shelf notes export schema'), findsOneWidget);
    expect(find.byKey(const Key('markdown-preview-share')), findsOneWidget);
    expect(shared, isEmpty);

    await tester.tap(find.byKey(const Key('markdown-preview-share')));
    await flushExport(tester, () => shared.length >= 2);

    expect(shared, hasLength(2));
    expect(shared.any((path) => path.endsWith('-notes.json')), isTrue);
    expect(shared.any((path) => path.endsWith('-notes-schema.md')), isTrue);
    expect(ExportShare.lastSharePositionOrigin, isNotNull);
    expect(ExportShare.lastSharePositionOrigin, isNot(Rect.zero));
    expect(ExportShare.lastSharePositionOrigin!.width, greaterThan(0));
  });

  testWidgets('closing the markdown preview does not share', (tester) async {
    var shared = false;
    ExportShare.override = (paths, subject) async {
      shared = true;
    };
    await pumpLibrary(tester);
    await tester.tap(find.byKey(const Key('library-card-menu-pdf-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('library-card-export-comments')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('markdown-preview-close')));
    await flushExport(tester, () => shared);
    expect(shared, isFalse);
    expect(ExportShare.lastSharePositionOrigin, isNull);
    expect(find.byKey(const Key('markdown-preview-sheet')), findsNothing);
  });

  testWidgets('notes use a quote bar, comment, and page number', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ShelfTheme.light(),
        home: NotesHubScreen(store: store),
      ),
    );
    await tester.pump();

    expect(find.byType(FilterChip), findsNothing);
    expect(find.text('method'), findsOneWidget);
    expect(find.text('Come back to this diagram.'), findsOneWidget);
    expect(find.text('p. 2'), findsOneWidget);
    expect(find.text('Check the later chapter.'), findsOneWidget);
    expect(find.text('p. 5'), findsOneWidget);

    final accent = tester.widget<Container>(
      find.byKey(const Key('note-accent-note-1')),
    );
    final decoration = accent.decoration! as BoxDecoration;
    final border = decoration.border! as Border;
    expect(border.left.color, store.labelById(ColorLabel.orangeId).color);
    expect(border.left.width, 3);

    await tester.longPress(find.text('Come back to this diagram.'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Go to highlight'), findsOneWidget);
    expect(find.text('Copy highlight'), findsOneWidget);
    expect(find.text('Copy note'), findsOneWidget);
    expect(find.text('Edit note'), findsOneWidget);
    expect(find.text('Delete note'), findsOneWidget);

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<Object?, Object?>;
          copied = args['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    await tester.tap(find.byKey(const Key('note-menu-copy-note-note-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(copied, 'Come back to this diagram.');
  });

  testWidgets('copy highlight and copy note write the quote and the comment', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ShelfTheme.light(),
        home: NotesHubScreen(store: store),
      ),
    );
    await tester.pump();

    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<Object?, Object?>;
          copied.add(args['text']! as String);
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.longPress(find.text('Come back to this diagram.'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('note-menu-copy-highlight-note-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.longPress(find.text('Come back to this diagram.'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('note-menu-copy-note-note-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(copied, ['method', 'Come back to this diagram.']);
  });

  testWidgets('colour filter is a popup, not a chip row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ShelfTheme.light(),
        home: NotesHubScreen(store: store),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('notes-label-filter')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Further research'), findsWidgets);
    await tester.tap(find.text('Further research').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Check the later chapter.'), findsOneWidget);
    expect(find.text('Come back to this diagram.'), findsNothing);
  });

  testWidgets('long-press delete removes the note', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ShelfTheme.light(),
        home: NotesHubScreen(store: store),
      ),
    );
    await tester.pump();
    await tester.longPress(find.text('Check the later chapter.'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('note-menu-delete-note-2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('note-delete-confirm-note-2')));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(find.text('Check the later chapter.'), findsNothing);
    expect(store.notes.map((note) => note.id), isNot(contains('note-2')));
  });

  testWidgets('page-press menu is a vertical icon card', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ShelfTheme.light(),
        home: const Scaffold(body: Center(child: PagePressMenu())),
      ),
    );
    final comment = tester.getTopLeft(
      find.byKey(const Key('pdf-page-action-comment')),
    );
    final select = tester.getTopLeft(
      find.byKey(const Key('pdf-page-action-select-text')),
    );
    expect(select.dy, greaterThan(comment.dy + 20));
    expect((select.dx - comment.dx).abs(), lessThan(8));
  });

  testWidgets('selection popup is an icon card without help text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ShelfTheme.light(),
        home: Scaffold(
          body: SelectionCommentBar(
            hasSelection: true,
            onAddComment: () {},
            onDone: () {},
          ),
        ),
      ),
    );
    expect(find.text('Add comment'), findsNothing);
    expect(find.text('Done'), findsNothing);
    expect(find.text('Drag the handles to widen the word.'), findsNothing);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('pdf-selection-add-comment')))
          .tooltip,
      'Add comment',
    );
    expect(
      tester.widget<IconButton>(find.byKey(const Key('pdf-selection-done'))).tooltip,
      'Done',
    );
    expect(find.byIcon(Icons.add_comment_outlined), findsOneWidget);
    await tester.longPress(find.byKey(const Key('pdf-selection-add-comment')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Add comment'), findsOneWidget);
    final add = tester.getTopLeft(find.byKey(const Key('pdf-selection-add-comment')));
    final done = tester.getTopLeft(find.byKey(const Key('pdf-selection-done')));
    expect(done.dy, greaterThan(add.dy));
  });

  testWidgets('chapters sheet lists outline rows and jumps', (tester) async {
    var jumped = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ShelfTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: ShelfColors.white,
                    builder: (context) => PageJumpSheet(
                      pageCount: 12,
                      currentPage: 3,
                      outline: const [
                        PdfOutlineNode(
                          title: 'Welcome And The Big Question',
                          dest: PdfDest(1, PdfDestCommand.fit, null),
                          children: [],
                        ),
                        PdfOutlineNode(
                          title: 'Natural Light And Mood',
                          dest: PdfDest(4, PdfDestCommand.fit, null),
                          children: [],
                        ),
                      ],
                      onJump: (page) => jumped = page,
                    ),
                  );
                },
                child: const Text('Open chapters'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open chapters'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('chapters-sheet')), findsOneWidget);
    expect(find.text('Chapters'), findsOneWidget);
    expect(find.text('2 chapters'), findsOneWidget);
    expect(find.text('Welcome And The Big Question'), findsOneWidget);
    expect(find.text('p. 4'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chapter-tile-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(jumped, 4);
  });

  testWidgets('reader overflow menu lists markers and chapters', (tester) async {
    var markers = 0;
    var chapters = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ShelfTheme.light(),
        home: Scaffold(
          appBar: AppBar(
            actions: [
              ReaderOverflowMenu(
                showMarkers: true,
                onToggleMarkers: () => markers++,
                onChapters: () => chapters++,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('reader-overflow-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Hide markers'), findsOneWidget);
    expect(find.text('Chapters'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    await tester.tap(find.byKey(const Key('reader-menu-chapters')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(chapters, 1);
    expect(markers, 0);
  });

  testWidgets('reader overflow Chapters opens the chapters sheet', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final document = store.documentById('pdf-1')!;
    await tester.pumpWidget(
      MaterialApp(
        theme: ShelfTheme.light(),
        home: ReaderScreen(store: store, document: document),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('reader-overflow-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('reader-menu-chapters')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('chapters-sheet')), findsOneWidget);
    expect(find.text('Chapters'), findsWidgets);
    expect(find.text('${document.pageCount} pages'), findsOneWidget);
  });

  testWidgets('markdown body renders a heading and a bullet', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ShelfMarkdownBody(
            data: '# Week plan\n\n- Bananas × 5\n\n**Food safety**',
          ),
        ),
      ),
    );
    expect(find.textContaining('Week plan'), findsOneWidget);
    expect(find.textContaining('Bananas × 5'), findsOneWidget);
    expect(find.textContaining('Food safety'), findsOneWidget);
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.childrenDelegate, isA<SliverChildBuilderDelegate>());
  });
}
