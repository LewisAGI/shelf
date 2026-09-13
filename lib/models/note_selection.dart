import 'note.dart';

/// Quoted PDF text and its page-local bounds for a selection-anchored note.
///
/// Coordinates are normalised 0–1 with origin top-left, matching [Note.x]/[Note.y].
/// Bounds come from the PDF selection (not only the free marker sliders).
class NoteSelection {
  const NoteSelection({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  /// Marker sits on the selection centre unless the composer sliders move it.
  double get anchorX => Note.normalizeCoord((left + right) / 2);

  double get anchorY => Note.normalizeCoord((top + bottom) / 2);

  bool get hasText => text.trim().isNotEmpty;

  /// Convert a PDF-page rectangle (origin bottom-left, [pdfTop] ≥ [pdfBottom])
  /// into Shelf's top-left normalised box.
  factory NoteSelection.fromPdfPageBounds({
    required String text,
    required double pdfLeft,
    required double pdfTop,
    required double pdfRight,
    required double pdfBottom,
    required double pageWidth,
    required double pageHeight,
  }) {
    if (pageWidth <= 0 || pageHeight <= 0) {
      return NoteSelection(
        text: text,
        left: 0,
        top: 0,
        right: 0,
        bottom: 0,
      );
    }
    final left = Note.normalizeCoord(pdfLeft / pageWidth);
    final right = Note.normalizeCoord(pdfRight / pageWidth);
    final top = Note.normalizeCoord(1 - (pdfTop / pageHeight));
    final bottom = Note.normalizeCoord(1 - (pdfBottom / pageHeight));
    return NoteSelection(
      text: text,
      left: left <= right ? left : right,
      top: top <= bottom ? top : bottom,
      right: left <= right ? right : left,
      bottom: top <= bottom ? bottom : top,
    );
  }

  NoteSelection copyWith({
    String? text,
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) {
    return NoteSelection(
      text: text ?? this.text,
      left: left ?? this.left,
      top: top ?? this.top,
      right: right ?? this.right,
      bottom: bottom ?? this.bottom,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'selected_text': text,
      'selection_left': left,
      'selection_top': top,
      'selection_right': right,
      'selection_bottom': bottom,
    };
  }

  static NoteSelection? fromMap(Map<String, Object?> map) {
    final text = map['selected_text'] as String?;
    final left = (map['selection_left'] as num?)?.toDouble();
    final top = (map['selection_top'] as num?)?.toDouble();
    final right = (map['selection_right'] as num?)?.toDouble();
    final bottom = (map['selection_bottom'] as num?)?.toDouble();
    if (text == null &&
        left == null &&
        top == null &&
        right == null &&
        bottom == null) {
      return null;
    }
    if (left == null || top == null || right == null || bottom == null) {
      if (text == null || text.isEmpty) {
        return null;
      }
      return NoteSelection(
        text: text,
        left: Note.normalizeCoord(left ?? 0),
        top: Note.normalizeCoord(top ?? 0),
        right: Note.normalizeCoord(right ?? left ?? 0),
        bottom: Note.normalizeCoord(bottom ?? top ?? 0),
      );
    }
    return NoteSelection(
      text: text ?? '',
      left: Note.normalizeCoord(left),
      top: Note.normalizeCoord(top),
      right: Note.normalizeCoord(right),
      bottom: Note.normalizeCoord(bottom),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NoteSelection &&
        other.text == text &&
        other.left == left &&
        other.top == top &&
        other.right == right &&
        other.bottom == bottom;
  }

  @override
  int get hashCode => Object.hash(text, left, top, right, bottom);
}
