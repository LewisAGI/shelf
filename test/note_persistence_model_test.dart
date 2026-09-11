import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/models/color_label.dart';
import 'package:shelf/models/note.dart';
import 'package:shelf/theme/shelf_theme.dart';

void main() {
  group('Note persistence model', () {
    final created = DateTime.utc(2026, 9, 11, 8, 30);
    final updated = DateTime.utc(2026, 9, 11, 9, 15);

    final note = Note(
      id: 'note-1',
      documentId: 'pdf-1',
      page: 4,
      x: 0.25,
      y: 0.8,
      text: 'Come back to this diagram.',
      colorLabelId: ColorLabel.orangeId,
      createdAt: created,
      updatedAt: updated,
    );

    test('round-trips through toMap/fromMap including colour label', () {
      final restored = Note.fromMap(note.toMap());
      expect(restored.id, note.id);
      expect(restored.documentId, note.documentId);
      expect(restored.page, 4);
      expect(restored.x, 0.25);
      expect(restored.y, 0.8);
      expect(restored.text, note.text);
      expect(restored.colorLabelId, ColorLabel.orangeId);
      expect(
        restored.createdAt.millisecondsSinceEpoch,
        created.millisecondsSinceEpoch,
      );
      expect(
        restored.updatedAt.millisecondsSinceEpoch,
        updated.millisecondsSinceEpoch,
      );
    });

    test('stores normalised coordinates as doubles', () {
      final map = note.toMap();
      expect(map['x'], isA<double>());
      expect(map['y'], isA<double>());
      expect(map['color_label_id'], ColorLabel.orangeId);
    });

    test('clamps page coordinates to 0–1', () {
      expect(Note.normalizeCoord(-0.2), 0);
      expect(Note.normalizeCoord(1.4), 1);
      expect(Note.normalizeCoord(0.33), 0.33);
      expect(Note.normalizeCoord(double.nan), 0);
    });
  });

  group('ColorLabel defaults', () {
    test('seeds orange as the default new-note label', () {
      final seeded = ColorLabel.seedDefaults();
      expect(seeded, hasLength(2));
      expect(seeded.first.id, ColorLabel.orangeId);
      expect(seeded.first.hex, ShelfColors.defaultOrangeHex);
      expect(seeded.first.isDefault, isTrue);
      expect(seeded[1].id, ColorLabel.purpleId);
      expect(seeded[1].isDefault, isFalse);
    });

    test('round-trips label rows', () {
      final label = ColorLabel.seedDefaults().first;
      final restored = ColorLabel.fromMap(label.toMap());
      expect(restored.id, label.id);
      expect(restored.name, label.name);
      expect(restored.meaning, label.meaning);
      expect(restored.hex, label.hex);
      expect(restored.isDefault, isTrue);
    });
  });
}
