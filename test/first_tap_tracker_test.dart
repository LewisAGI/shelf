import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/services/first_tap_tracker.dart';

void main() {
  group('FirstTapTracker', () {
    late DateTime now;
    late FirstTapTracker tracker;

    setUp(() {
      now = DateTime.utc(2026, 9, 11, 8);
      tracker = FirstTapTracker(clock: () => now);
    });

    test('defaults match Flutter double-tap window and slop', () {
      final defaults = FirstTapTracker();
      expect(defaults.window, kDoubleTapTimeout);
      expect(defaults.slop, kDoubleTapSlop);
      expect(defaults.touchSlop, kTouchSlop);
      expect(defaults.window, const Duration(milliseconds: 300));
      expect(defaults.slop, 100);
    });

    test('consumeFirst returns the first tap, not the second', () {
      tracker.recordDown(const Offset(10, 20));
      now = now.add(const Duration(milliseconds: 80));
      tracker.recordDown(const Offset(18, 24));

      expect(tracker.consumeFirst(), const Offset(10, 20));
    });

    test('consumeFirst is null when the pair is missing — fail closed', () {
      tracker.recordDown(const Offset(40, 40));

      expect(tracker.consumeFirst(), isNull);
    });

    test('does not silently use the second tap as a fallback', () {
      tracker.recordDown(const Offset(5, 5));
      now = now.add(const Duration(milliseconds: 400));
      tracker.recordDown(const Offset(200, 200));

      expect(tracker.hasPairedFirst, isFalse);
      expect(tracker.consumeFirst(), isNull);
    });

    test('pairs when the second tap is just inside the slop', () {
      tracker.recordDown(Offset.zero);
      now = now.add(const Duration(milliseconds: 100));
      tracker.recordDown(Offset(tracker.slop, 0));

      expect(tracker.consumeFirst(), Offset.zero);
    });

    test('rejects a second tap just outside the slop', () {
      tracker.recordDown(Offset.zero);
      now = now.add(const Duration(milliseconds: 100));
      tracker.recordDown(Offset(tracker.slop + 0.5, 0));

      expect(tracker.consumeFirst(), isNull);
    });

    test('pairs when the second tap is just inside the window', () {
      tracker.recordDown(const Offset(1, 1));
      now = now.add(tracker.window);
      tracker.recordDown(const Offset(2, 2));

      expect(tracker.consumeFirst(), const Offset(1, 1));
    });

    test('rejects a second tap just after the window', () {
      tracker.recordDown(const Offset(1, 1));
      now = now.add(tracker.window + const Duration(milliseconds: 1));
      tracker.recordDown(const Offset(2, 2));

      expect(tracker.consumeFirst(), isNull);
    });

    test('clears on consume so a leftover pair cannot be reused', () {
      tracker.recordDown(const Offset(8, 9));
      now = now.add(const Duration(milliseconds: 50));
      tracker.recordDown(const Offset(9, 10));

      expect(tracker.consumeFirst(), const Offset(8, 9));
      expect(tracker.hasPairedFirst, isFalse);
      expect(tracker.consumeFirst(), isNull);
    });

    test('clear wipes an unused pair', () {
      tracker.recordDown(const Offset(3, 4));
      now = now.add(const Duration(milliseconds: 40));
      tracker.recordDown(const Offset(4, 5));
      tracker.clear();

      expect(tracker.consumeFirst(), isNull);
    });

    test('a dragged first down is not paired with a later tap', () {
      tracker.recordDown(const Offset(0, 0));
      tracker.recordMove(Offset(0, tracker.touchSlop + 1));
      now = now.add(const Duration(milliseconds: 80));
      tracker.recordDown(const Offset(4, 4));

      expect(tracker.consumeFirst(), isNull);
    });

    test('abortPending drops a failed or polluted pair', () {
      tracker.recordDown(const Offset(12, 12));
      now = now.add(const Duration(milliseconds: 40));
      tracker.recordDown(const Offset(13, 13));
      tracker.abortPending();

      expect(tracker.consumeFirst(), isNull);
    });
  });
}
