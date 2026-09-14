import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shelf/theme/shelf_theme.dart';
import 'package:shelf/widgets/pdf_selection_chrome.dart';

void main() {
  test('viewer theme restores an orange selection fill and orange handles', () {
    final themed = PdfSelectionChrome.theme(ShelfTheme.light());
    expect(
      themed.textSelectionTheme.selectionColor,
      PdfSelectionChrome.highlightColor,
    );
    expect(themed.textSelectionTheme.selectionColor, isNot(Colors.transparent));
    expect(
      themed.textSelectionTheme.selectionColor!.a,
      greaterThan(0),
    );
    expect(themed.textSelectionTheme.selectionHandleColor, ShelfColors.orange);
    expect(themed.textSelectionTheme.cursorColor, ShelfColors.orange);
    expect(PdfSelectionChrome.handleColor, ShelfColors.orange);
    expect(PdfSelectionChrome.handleColor, isNot(const Color(0xFF0A84FF)));
    expect(PdfSelectionChrome.handleVisualSize, lessThan(PdfSelectionChrome.handleHitSize));
  });

  testWidgets('wrap applies the orange DefaultSelectionStyle', (tester) async {
    late Color? inherited;
    await tester.pumpWidget(
      MaterialApp(
        theme: ShelfTheme.light(),
        home: PdfSelectionChrome.wrap(
          Builder(
            builder: (context) {
              inherited = DefaultSelectionStyle.of(context).selectionColor;
              return const SizedBox(key: Key('selection-chrome-child'));
            },
          ),
        ),
      ),
    );

    expect(inherited, PdfSelectionChrome.highlightColor);
    expect(inherited, isNot(Colors.transparent));
    expect(
      Theme.of(tester.element(find.byKey(const Key('selection-chrome-child'))))
          .textSelectionTheme
          .selectionColor,
      PdfSelectionChrome.highlightColor,
    );
    expect(
      Theme.of(tester.element(find.byKey(const Key('selection-chrome-child'))))
          .textSelectionTheme
          .selectionHandleColor,
      ShelfColors.orange,
    );
  });

  testWidgets('custom handles stay visible, hittable, and orange', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PdfSelectionHandle(
            path: Path(),
            state: PdfViewerTextSelectionAnchorHandleState.normal,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('pdf-selection-handle')), findsOneWidget);
    final handle = tester.widget<CustomPaint>(
      find.byKey(const Key('pdf-selection-handle')),
    );
    expect(handle.size, const Size(30, 30));
    final bounds = PdfSelectionChrome.handlePath(
      direction: PdfTextDirection.ltr,
      type: PdfTextSelectionAnchorType.a,
    ).getBounds();
    expect(bounds, isNot(Rect.zero));
    expect(bounds.width, lessThan(20));
    expect(bounds.height, lessThan(20));
  });

  test('context menu builder hides the empty dark callout', () {
    expect(
      PdfSelectionChrome.hideContextMenu,
      isNotNull,
    );
  });
}
