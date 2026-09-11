import 'dart:ui';

import 'package:flutter/gestures.dart';

/// Remembers the first tap of a double-tap so a note sits there,
/// not on the second tap.
///
/// Pairing uses Flutter's [kDoubleTapTimeout] and [kDoubleTapSlop] so a
/// pair that [DoubleTapGestureRecognizer] accepts is also accepted here.
///
/// Fail closed: [consumeFirst] returns the first tap of a known pair, then
/// clears. If the first tap is unknown (no pair, stale, aborted, or a
/// marker / cancelled pointer was ignored), it returns null. Callers must
/// not place a note on the second tap — skip and let the user double-tap
/// again.
class FirstTapTracker {
  FirstTapTracker({
    this.window = kDoubleTapTimeout,
    this.slop = kDoubleTapSlop,
    this.touchSlop = kTouchSlop,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Same window as Flutter's double-tap recogniser (300 ms).
  final Duration window;

  /// Same pairing slop as Flutter's double-tap recogniser (100 logical px).
  final double slop;

  /// Movement that turns a down into a pan, matching [kTouchSlop].
  final double touchSlop;

  final DateTime Function() _clock;

  Offset? _candidate;
  DateTime? _candidateAt;
  Offset? _firstOfPair;

  /// Last completed first-of-pair, if any. Tests and callers may inspect
  /// this without consuming.
  Offset? get firstOfPair => _firstOfPair;

  bool get hasPairedFirst => _firstOfPair != null;

  void recordDown(Offset globalPosition) {
    final now = _clock();
    final previous = _candidate;
    final previousAt = _candidateAt;
    if (previous != null &&
        previousAt != null &&
        now.difference(previousAt) <= window &&
        (globalPosition - previous).distance <= slop) {
      _firstOfPair = previous;
    } else {
      _firstOfPair = null;
    }
    _candidate = globalPosition;
    _candidateAt = now;
  }

  /// Drop the current unmatched down if the pointer is dragged (pan) or
  /// otherwise no longer a tap. A locked first-of-pair is left intact.
  void recordMove(Offset globalPosition) {
    if (_firstOfPair != null) {
      return;
    }
    final candidate = _candidate;
    if (candidate != null &&
        (globalPosition - candidate).distance > touchSlop) {
      _candidate = null;
      _candidateAt = null;
    }
  }

  /// Pointer cancelled or a non-page hit (marker / chrome). Do not keep
  /// that down as a pairing candidate.
  void abortPending() {
    _candidate = null;
    _candidateAt = null;
    _firstOfPair = null;
  }

  /// Wipe every remembered tap. Call after a note is created, or when
  /// a marker tap / failed pair must not leak into the next gesture.
  void clear() {
    _candidate = null;
    _candidateAt = null;
    _firstOfPair = null;
  }

  /// First tap of the current pair, or null if unknown. Always clears.
  Offset? consumeFirst() {
    final first = _firstOfPair;
    clear();
    return first;
  }
}
