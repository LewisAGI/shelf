import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/services/select_text_handoff.dart';
import 'package:shelf/widgets/page_press_menu.dart';

void main() {
  group('SelectTextHandoff', () {
    test('preserves the long-press point through menu handoff', () {
      final handoff = SelectTextHandoff();
      const press = Offset(142, 318);

      handoff.rememberDocumentPoint(press);

      // Enabling selection / removing the overlay must not wipe the point.
      expect(handoff.hasPending, isTrue);
      expect(handoff.pendingDocumentPoint, press);

      // Select uses the same pending range — no second long-press.
      expect(handoff.pendingDocumentPoint, press);
      handoff.markApplied();
      expect(handoff.pendingDocumentPoint, press);
    });

    test('already-selected range at menu open is the Select initial range', () {
      final handoff = SelectTextHandoff();
      const alreadySelected = Offset(80, 200);

      // Whatever was selected when the menu opened is remembered as pending.
      handoff.rememberDocumentPoint(alreadySelected);
      expect(handoff.pendingDocumentPoint, alreadySelected);

      handoff.markApplied();
      expect(handoff.consumeWipeProtection(), isTrue);
      expect(handoff.pendingDocumentPoint, alreadySelected);
    });

    test('swallows the first tap after Select so pdfrx cannot clear handles', () {
      final handoff = SelectTextHandoff();
      handoff.rememberDocumentPoint(const Offset(10, 20));
      handoff.markApplied();

      expect(handoff.protectsFromWipe, isTrue);
      expect(handoff.consumeWipeProtection(), isTrue);
      expect(handoff.protectsFromWipe, isFalse);
      expect(handoff.consumeWipeProtection(), isFalse);
    });

    test('does not swallow a tap when Select never applied the range', () {
      final handoff = SelectTextHandoff();
      handoff.rememberDocumentPoint(const Offset(1, 1));

      expect(handoff.consumeWipeProtection(), isFalse);
    });

    test('clear drops pending and wipe protection', () {
      final handoff = SelectTextHandoff();
      handoff.rememberDocumentPoint(const Offset(3, 4));
      handoff.markApplied();
      handoff.clear();

      expect(handoff.hasPending, isFalse);
      expect(handoff.pendingDocumentPoint, isNull);
      expect(handoff.consumeWipeProtection(), isFalse);
    });
  });

  testWidgets(
    'Select from the long-press menu keeps the pending press range',
    (tester) async {
      final handoff = SelectTextHandoff();
      Offset? applied;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return GestureDetector(
                key: const Key('reader-long-press-target'),
                onLongPress: () async {
                  const press = Offset(96, 240);
                  handoff.rememberDocumentPoint(press);
                  final action = await PagePressMenu.show(
                    context,
                    globalPosition: press,
                  );
                  if (action != PagePressAction.selectText) {
                    handoff.clear();
                    return;
                  }
                  applied = handoff.pendingDocumentPoint;
                  handoff.markApplied();
                },
                child: const SizedBox.expand(
                  child: ColoredBox(color: Colors.white),
                ),
              );
            },
          ),
        ),
      );

      await tester.longPress(find.byKey(const Key('reader-long-press-target')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(handoff.pendingDocumentPoint, const Offset(96, 240));

      await tester.tap(find.byKey(const Key('pdf-page-action-select-text')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(applied, const Offset(96, 240));
      expect(handoff.pendingDocumentPoint, const Offset(96, 240));
      expect(handoff.protectsFromWipe, isTrue);
      expect(find.byKey(const Key('note-composer-pill')), findsNothing);
    },
  );
}
