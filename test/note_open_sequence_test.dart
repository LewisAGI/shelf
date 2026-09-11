import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/models/color_label.dart';
import 'package:shelf/models/note.dart';
import 'package:shelf/services/note_open_sequence.dart';

Note _note({double x = 0.25, double y = 0.4, int page = 3}) {
  return Note(
    id: 'n1',
    documentId: 'd1',
    page: page,
    x: x,
    y: y,
    text: 'Focus this',
    colorLabelId: ColorLabel.orangeId,
    createdAt: DateTime.utc(2026, 9, 11),
    updatedAt: DateTime.utc(2026, 9, 11),
  );
}

void main() {
  group('NoteOpenSequence', () {
    test('awaits ready, then page, then marker, then editor — no delay', () async {
      final steps = <String>[];

      await NoteOpenSequence.run(
        waitUntilReady: () async => steps.add('ready'),
        page: 7,
        goToPage: (page) async => steps.add('go:$page'),
        waitUntilPageCurrent: () async => steps.add('page-current'),
        ensureMarkerVisible: () async => steps.add('marker'),
        openNote: () async => steps.add('editor'),
      );

      expect(steps, [
        'ready',
        'go:7',
        'page-current',
        'marker',
        'editor',
      ]);
    });

    test('does not open the editor if the route is no longer active', () async {
      final steps = <String>[];
      var active = true;

      await NoteOpenSequence.run(
        waitUntilReady: () async => steps.add('ready'),
        page: 2,
        goToPage: (page) async {
          steps.add('go:$page');
          active = false;
        },
        waitUntilPageCurrent: () async => steps.add('page-current'),
        ensureMarkerVisible: () async => steps.add('marker'),
        openNote: () async => steps.add('editor'),
        isActive: () => active,
      );

      expect(steps, ['ready', 'go:2']);
    });

    test('still opens the editor when marker focus is omitted', () async {
      final steps = <String>[];

      await NoteOpenSequence.run(
        waitUntilReady: () async => steps.add('ready'),
        page: 1,
        goToPage: (page) async => steps.add('go:$page'),
        openNote: () async => steps.add('editor'),
      );

      expect(steps, ['ready', 'go:1', 'editor']);
    });
  });

  group('noteMarkerContains', () {
    final note = _note();

    test('hits the marker centre', () {
      expect(
        noteMarkerContains(
          note: note,
          normalisedTap: const Offset(0.25, 0.4),
          pageSizeInView: const Size(400, 800),
        ),
        isTrue,
      );
    });

    test('misses a tap far from the marker', () {
      expect(
        noteMarkerContains(
          note: note,
          normalisedTap: const Offset(0.9, 0.9),
          pageSizeInView: const Size(400, 800),
        ),
        isFalse,
      );
    });
  });

  group('markerPdfBounds', () {
    test('converts top-left normalised notes to PDF bottom-left space', () {
      final bounds = markerPdfBounds(
        note: _note(x: 0.5, y: 0.25),
        pageWidth: 200,
        pageHeight: 400,
        pad: 10,
      );
      expect(bounds.left, 90);
      expect(bounds.right, 110);
      expect(bounds.bottom, 290);
      expect(bounds.top, 310);
    });
  });
}
