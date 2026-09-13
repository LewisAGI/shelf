import 'note_selection.dart';

class Note {
  const Note({
    required this.id,
    required this.documentId,
    required this.page,
    required this.x,
    required this.y,
    required this.text,
    required this.colorLabelId,
    required this.createdAt,
    required this.updatedAt,
    this.selection,
  });

  final String id;
  final String documentId;

  /// 1-based PDF page number.
  final int page;

  /// Normalised page position, origin top-left, range 0–1.
  final double x;

  /// Normalised page position, origin top-left, range 0–1.
  final double y;

  final String text;
  final String colorLabelId;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// When set, the note is anchored to a PDF word/selection, not only a tap point.
  final NoteSelection? selection;

  bool get isSelectionAnchored => selection != null;

  Note copyWith({
    String? id,
    String? documentId,
    int? page,
    double? x,
    double? y,
    String? text,
    String? colorLabelId,
    DateTime? createdAt,
    DateTime? updatedAt,
    NoteSelection? selection,
    bool clearSelection = false,
  }) {
    return Note(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      page: page ?? this.page,
      x: x ?? this.x,
      y: y ?? this.y,
      text: text ?? this.text,
      colorLabelId: colorLabelId ?? this.colorLabelId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      selection: clearSelection ? null : (selection ?? this.selection),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'document_id': documentId,
      'page': page,
      'x': x,
      'y': y,
      'text': text,
      'color_label_id': colorLabelId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      ...?selection?.toMap(),
      if (selection == null) ...{
        'selected_text': null,
        'selection_left': null,
        'selection_top': null,
        'selection_right': null,
        'selection_bottom': null,
      },
    };
  }

  factory Note.fromMap(Map<String, Object?> map) {
    return Note(
      id: map['id']! as String,
      documentId: map['document_id']! as String,
      page: map['page']! as int,
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      text: map['text']! as String,
      colorLabelId: map['color_label_id']! as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']! as int),
      selection: NoteSelection.fromMap(map),
    );
  }

  /// Clamp stored coordinates into the inclusive 0–1 page range.
  static double normalizeCoord(double value) {
    if (value.isNaN || value.isInfinite) {
      return 0;
    }
    return value.clamp(0.0, 1.0);
  }
}
