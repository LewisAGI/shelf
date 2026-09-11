import 'dart:ui';

/// Remembers the first tap of a double-tap so a note can sit there,
/// not on the second tap.
class FirstTapTracker {
  static const window = Duration(milliseconds: 350);
  static const slop = 72.0;

  Offset? _candidate;
  DateTime? _candidateAt;
  Offset? _firstOfPair;

  void recordDown(Offset globalPosition) {
    final now = DateTime.now();
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

  Offset consumeFirstOr(Offset fallback) {
    return _firstOfPair ?? fallback;
  }
}
