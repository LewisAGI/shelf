import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shelf/theme/shelf_theme.dart';
import 'package:shelf/widgets/pdf_selection_chrome.dart';

void main() {
  test('viewer theme hides the selection fill', () {
    final themed = PdfSelectionChrome.theme(ShelfTheme.light());
    expect(
      themed.textSelectionTheme.selectionColor,
      PdfSelectionChrome.highlightColor,
    );
    expect(themed.textSelectionTheme.selectionColor, Colors.transparent);
    expect(themed.textSelectionTheme.selectionHandleColor, Colors.transparent);
    expect(themed.textSelectionTheme.cursorColor, Colors.transparent);
    expect(PdfSelectionChrome.handleColor.a, greaterThan(0));
    expect(PdfSelectionChrome.handleColor, isNot(Colors.transparent));
    expect(PdfSelectionChrome.handleVisualSize, lessThan(PdfSelectionChrome.handleHitSize));
  });

  testWidgets('wrap applies a transparent DefaultSelectionStyle', (
    tester,
  ) async {
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

    expect(inherited, Colors.transparent);
    expect(
      Theme.of(tester.element(find.byKey(const Key('selection-chrome-child'))))
          .textSelectionTheme
          .selectionColor,
      Colors.transparent,
    );
  });

  testWidgets('custom handles stay visible and hittable', (tester) async {
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
}
