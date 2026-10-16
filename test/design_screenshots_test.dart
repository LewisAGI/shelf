import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shelf/data/shelf_database.dart';
import 'package:shelf/data/shelf_store.dart';
import 'package:shelf/models/color_label.dart';
import 'package:shelf/models/library_document.dart';
import 'package:shelf/models/note.dart';
import 'package:shelf/models/note_selection.dart';
import 'package:shelf/screens/home_shell.dart';
import 'package:shelf/services/notes_export.dart';
import 'package:shelf/theme/shelf_theme.dart';
import 'package:shelf/widgets/markdown_preview_sheet.dart';
import 'package:shelf/widgets/page_jump_sheet.dart';
import 'package:shelf/widgets/page_press_menu.dart';
import 'package:shelf/widgets/reader_menu.dart';
import 'package:shelf/widgets/selection_comment_bar.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Phone screenshots with Inter (not the test Ahem font).
/// Run: SHELF_SCREENSHOTS=1 flutter test test/design_screenshots_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ShelfDatabase db;
  late ShelfStore store;

  setUpAll(() async {
    if (Platform.environment['SHELF_SCREENSHOTS'] != '1') {
      return;
    }
    mark('setup-start');
    sqfliteFfiInit();
    await loadInter().timeout(const Duration(seconds: 20));
    db = ShelfDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    const docs = [
      ('pdf-1', 'Design Language', 42),
      ('pdf-2', 'Hidden Cost', 18),
      ('pdf-3', 'Indexing Strategies', 64),
      ('pdf-4', 'Decision Notes', 12),
    ];
    for (var i = 0; i < docs.length; i++) {
      final item = docs[i];
      await db.upsertDocument(
        LibraryDocument(
          id: item.$1,
          title: item.$2,
          storedName: '${item.$1}.pdf',
          importedAt: DateTime.utc(2026, 9, 10 + i),
          pageCount: item.$3,
        ),
      );
    }
    await db.upsertNote(
      Note(
        id: 'note-1',
        documentId: 'pdf-1',
        page: 12,
        x: 0.4,
        y: 0.3,
        text: 'The flow is the unit the model should read, not the screen.',
        colorLabelId: ColorLabel.orangeId,
        createdAt: DateTime.utc(2026, 9, 13),
        updatedAt: DateTime.utc(2026, 9, 13),
        selection: const NoteSelection(
          text: 'User flows are the grammar of the product.',
          left: 0.1,
          top: 0.2,
          right: 0.8,
          bottom: 0.28,
        ),
      ),
    );
    await db.upsertNote(
      Note(
        id: 'note-2',
        documentId: 'pdf-1',
        page: 27,
        x: 0.5,
        y: 0.6,
        text: 'Come back when the outline has a name for this step.',
        colorLabelId: ColorLabel.purpleId,
        createdAt: DateTime.utc(2026, 9, 14),
        updatedAt: DateTime.utc(2026, 9, 14),
        selection: const NoteSelection(
          text: 'Inconsistency is a tax on every later decision.',
          left: 0.1,
          top: 0.4,
          right: 0.7,
          bottom: 0.48,
        ),
      ),
    );
    store = ShelfStore(database: db);
    await store.init();
    mark('setup-done');
  });

  tearDownAll(() async {
    if (Platform.environment['SHELF_SCREENSHOTS'] != '1') {
      return;
    }
    await db.close();
  });

  testWidgets(
    'capture restyle screens with Inter',
    (tester) async {
      debugDisableShadows = false;
      addTearDown(() => debugDisableShadows = true);

      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.padding = const FakeViewPadding(top: 54, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 54, bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);

      mark('view-ready');

      final theme = ShelfTheme.light(fontFamily: 'Inter');
      mark('before-pump');
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('shot'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: HomeShell(store: store),
          ),
        ),
      );
      mark('after-pump');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await shoot(tester, 'library_grid');

      await tester.tap(find.byKey(const Key('nav-notes')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await shoot(tester, 'notes_list');

      await tester.longPress(find.text('The flow is the unit the model should read, not the screen.'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await shoot(tester, 'note_long_press_menu');
      await tester.tapAt(const Offset(20, 20));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('shot'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: const Scaffold(
              backgroundColor: Color(0xFFF5F5F4),
              body: Center(child: PagePressMenu()),
            ),
          ),
        ),
      );
      await tester.pump();
      await shoot(tester, 'page_press_menu');

      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('shot'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: Scaffold(
              backgroundColor: const Color(0xFFF5F5F4),
              body: Center(
                child: SelectionCommentBar(
                  hasSelection: true,
                  onAddComment: () {},
                  onDone: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await shoot(tester, 'selection_popup');

      const outline = [
        PdfOutlineNode(
          title: 'Welcome And The Big Question',
          dest: PdfDest(1, PdfDestCommand.fit, null),
          children: [],
        ),
        PdfOutlineNode(
          title: 'Why Spaces Trigger Feelings',
          dest: PdfDest(3, PdfDestCommand.fit, null),
          children: [],
        ),
        PdfOutlineNode(
          title: 'Natural Light And Mood',
          dest: PdfDest(4, PdfDestCommand.fit, null),
          children: [],
        ),
        PdfOutlineNode(
          title: 'Nature Indoors For Calm',
          dest: PdfDest(8, PdfDestCommand.fit, null),
          children: [],
        ),
        PdfOutlineNode(
          title: 'Color Choices And Emotion',
          dest: PdfDest(11, PdfDestCommand.fit, null),
          children: [],
        ),
        PdfOutlineNode(
          title: 'Cities, Walkability, And Happiness',
          dest: PdfDest(16, PdfDestCommand.fit, null),
          children: [],
        ),
      ];
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('shot'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: Builder(
              builder: (context) {
                return Scaffold(
                  backgroundColor: const Color(0xFFF7F6F5),
                  appBar: AppBar(title: const Text('Design Language')),
                  body: Center(
                    child: FilledButton(
                      key: const Key('open-chapters'),
                      onPressed: () {
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: ShelfColors.white,
                          builder: (context) => PageJumpSheet(
                            pageCount: 48,
                            currentPage: 4,
                            outline: outline,
                            onJump: (_) {},
                          ),
                        );
                      },
                      child: const Text('Chapters'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('open-chapters')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await shoot(tester, 'chapters_sheet');

      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('shot'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: Scaffold(
              appBar: AppBar(
                title: const Text('Design Language'),
                actions: [
                  IconButton(
                    tooltip: 'Hide markers',
                    onPressed: () {},
                    icon: const Icon(Icons.visibility_outlined),
                  ),
                  ReaderOverflowMenu(
                    showMarkers: true,
                    onToggleMarkers: () {},
                    onChapters: () {},
                  ),
                ],
              ),
              body: const ColoredBox(color: Color(0xFFF7F6F5)),
            ),
          ),
        ),
      );
      await tester.pump();
      tester.state<PopupMenuButtonState<String>>(
        find.byKey(const Key('reader-overflow-menu')),
      ).showButtonMenu();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await shoot(tester, 'reader_menu');
      await tester.tapAt(const Offset(20, 700));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final schema = NotesExport.previewMarkdown(
        documentTitle: 'Design Language',
        notes: store.notes,
        labelById: store.labelById,
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('shot'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: const Scaffold(
              backgroundColor: Color(0xFFF7F6F5),
              body: SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pump();
      final context = tester.element(find.byType(Scaffold));
      MarkdownPreviewSheet.show(
        context,
        fileName: 'Design Language',
        markdown: schema,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await shoot(tester, 'markdown_preview');
      debugDisableShadows = true;
    },
    skip: Platform.environment['SHELF_SCREENSHOTS'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<void> loadInter() async {
  final loader = FontLoader('Inter');
  const files = [
    '/usr/share/fonts/truetype/macos/Inter-Regular.ttf',
    '/usr/share/fonts/truetype/macos/Inter-Medium.ttf',
    '/usr/share/fonts/truetype/macos/Inter-SemiBold.ttf',
    '/usr/share/fonts/truetype/macos/Inter-Bold.ttf',
  ];
  for (final path in files) {
    final bytes = await File(path).readAsBytes();
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

void mark(String name) {
  File('/tmp/shot-status.txt').writeAsStringSync('$name\n', mode: FileMode.append, flush: true);
}

Future<void> shoot(WidgetTester tester, String name) async {
  mark('shoot-start $name');
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('shot')),
  );
  final image = boundary.toImageSync(pixelRatio: 2);
  final data = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.png),
  );
  image.dispose();
  final file = File('/opt/cursor/artifacts/$name.png');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(data!.buffer.asUint8List());
  mark('shoot-done $name ${file.lengthSync()}');
}
