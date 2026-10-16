import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/theme/shelf_theme.dart';
import 'package:shelf/widgets/selection_comment_bar.dart';

void main() {
  testWidgets('Add comment is enabled only when a selection is active', (
    tester,
  ) async {
    var added = false;
    var done = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: ShelfTheme.light(),
        home: Scaffold(
          body: SelectionCommentBar(
            hasSelection: false,
            onAddComment: () => added = true,
            onDone: () => done = true,
          ),
        ),
      ),
    );

    expect(find.text('Add comment'), findsNothing);
    expect(find.text('Done'), findsNothing);
    final disabled = tester.widget<IconButton>(
      find.byKey(const Key('pdf-selection-add-comment')),
    );
    expect(disabled.tooltip, 'Add comment');
    expect(disabled.onPressed, isNull);
    expect(
      tester.widget<IconButton>(find.byKey(const Key('pdf-selection-done'))).tooltip,
      'Done',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ShelfTheme.light(),
        home: Scaffold(
          body: SelectionCommentBar(
            hasSelection: true,
            onAddComment: () => added = true,
            onDone: () => done = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('pdf-selection-add-comment')));
    await tester.tap(find.byKey(const Key('pdf-selection-done')));
    expect(added, isTrue);
    expect(done, isTrue);
  });
}
