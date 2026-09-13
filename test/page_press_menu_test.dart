import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/services/speech_capture.dart';
import 'package:shelf/theme/shelf_theme.dart';
import 'package:shelf/widgets/note_editor.dart';
import 'package:shelf/widgets/page_press_menu.dart';
import 'package:shelf/models/color_label.dart';

void main() {
  testWidgets('long-press menu shows only Comment and Select text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ShelfTheme.light(),
        home: const Scaffold(body: Center(child: PagePressMenu())),
      ),
    );

    expect(find.byKey(const Key('pdf-page-action-menu')), findsOneWidget);
    expect(find.text(PagePressMenu.commentLabel), findsOneWidget);
    expect(find.text(PagePressMenu.selectTextLabel), findsOneWidget);
    expect(find.byType(TextButton), findsNWidgets(2));
    expect(find.text('Copy'), findsNothing);
    expect(find.text('Select All'), findsNothing);
    expect(find.text('New note'), findsNothing);
  });

  testWidgets('Comment from the menu opens the Grok composer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ShelfTheme.light(),
        home: Builder(
          builder: (context) {
            return GestureDetector(
              key: const Key('reader-long-press-target'),
              onLongPress: () async {
                final action = await PagePressMenu.show(
                  context,
                  globalPosition: tester.getCenter(
                    find.byKey(const Key('reader-long-press-target')),
                  ),
                );
                if (action != PagePressAction.comment || !context.mounted) {
                  return;
                }
                await NoteEditor.show(
                  context,
                  labels: ColorLabel.seedDefaults(),
                  defaultLabelId: ColorLabel.orangeId,
                  speech: SpeechCapture(),
                  page: 3,
                  x: 0.41,
                  y: 0.63,
                );
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

    expect(find.byKey(const Key('pdf-page-action-menu')), findsOneWidget);
    expect(find.text('Comment'), findsOneWidget);
    expect(find.text('Select text'), findsOneWidget);
    expect(find.byKey(const Key('note-composer-pill')), findsNothing);

    await tester.tap(find.byKey(const Key('pdf-page-action-comment')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('note-composer-pill')), findsOneWidget);
    expect(find.byKey(const Key('note-composer-field')), findsOneWidget);
    expect(find.byKey(const Key('note-composer-mic')), findsOneWidget);
    expect(find.byKey(const Key('note-composer-colour')), findsOneWidget);
    expect(find.text('Leave a comment'), findsOneWidget);
    expect(find.text('0.41'), findsOneWidget);
    expect(find.text('0.63'), findsOneWidget);
  });

  testWidgets('Select text does not open the composer', (tester) async {
    PagePressAction? chosen;

    await tester.pumpWidget(
      MaterialApp(
        theme: ShelfTheme.light(),
        home: Builder(
          builder: (context) {
            return GestureDetector(
              key: const Key('reader-long-press-target'),
              onLongPress: () async {
                chosen = await PagePressMenu.show(
                  context,
                  globalPosition: const Offset(120, 180),
                );
              },
              child: const SizedBox.expand(child: ColoredBox(color: Colors.white)),
            );
          },
        ),
      ),
    );

    await tester.longPress(find.byKey(const Key('reader-long-press-target')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('pdf-page-action-select-text')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(chosen, PagePressAction.selectText);
    expect(find.byKey(const Key('note-composer-pill')), findsNothing);
  });
}
