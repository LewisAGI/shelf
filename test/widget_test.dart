import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/theme/shelf_theme.dart';

void main() {
  testWidgets('white and orange theme paints a Shelf chrome label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ShelfTheme.light(),
        home: Scaffold(
          appBar: AppBar(title: const Text('Shelf')),
          floatingActionButton: FloatingActionButton(
            onPressed: () {},
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );

    expect(find.text('Shelf'), findsOneWidget);
    final fab = tester.widget<Material>(
      find.descendant(
        of: find.byType(FloatingActionButton),
        matching: find.byType(Material),
      ),
    );
    expect(fab.color, ShelfColors.orange);
  });
}
