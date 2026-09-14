import 'package:flutter/painting.dart';

/// Holds the long-press word (document point) across the Comment | Select
/// menu so enabling selection / removing the overlay cannot wipe it.
///
/// pdfrx clears the current range on a general tap. The tap that dismisses
/// the menu (or the pointer that lands when the full-page overlay is
/// removed) would otherwise run after [selectWord] and drop the handles.
class SelectTextHandoff {
  Offset? _documentPoint;
  bool _protectFromWipe = false;

  bool get hasPending => _documentPoint != null;

  bool get protectsFromWipe => _protectFromWipe;

  /// Document-layout point captured at long-press. Survives menu handoff
  /// and the selection-mode rebuild; not cleared until wipe-protection
  /// is consumed or [clear] is called.
  Offset? get pendingDocumentPoint => _documentPoint;

  /// Call at long-press, before the menu overlay or `enabled: true`.
  void rememberDocumentPoint(Offset documentPoint) {
    _documentPoint = documentPoint;
    _protectFromWipe = false;
  }

  /// After a successful [selectWord] (or restore). The next viewer tap
  /// is swallowed so pdfrx does not [clearTextSelection].
  void markApplied() {
    if (_documentPoint == null) {
      return;
    }
    _protectFromWipe = true;
  }

  /// True once after [markApplied]. A later tap can clear the range.
  bool consumeWipeProtection() {
    if (!_protectFromWipe) {
      return false;
    }
    _protectFromWipe = false;
    return true;
  }

  void clear() {
    _documentPoint = null;
    _protectFromWipe = false;
  }
}
