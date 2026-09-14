import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/models/color_label.dart';
import 'package:shelf/models/note.dart';
import 'package:shelf/models/note_selection.dart';
import 'package:shelf/services/note_open_sequence.dart';
import 'package:shelf/services/note_page_target.dart';

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

  group('NotePageTarget', () {
    test('0-based stored page 0 opens viewer page 1', () {
      expect(NotePageTarget.toViewerPage(0), 1);
    });

    test('1-based stored page 1 stays 1', () {
      expect(NotePageTarget.toViewerPage(1), 1);
    });

    test('stored page 12 is used as-is', () {
      expect(NotePageTarget.toViewerPage(12), 12);
    });

    test('stale pageCount of 1 does not pin a later page to page 1', () {
      expect(NotePageTarget.toViewerPage(42, pageCount: 1), 42);
      expect(NotePageTarget.toViewerPage(42, pageCount: 0), 42);
      expect(NotePageTarget.toViewerPage(42, pageCount: null), 42);
    });

    test('clamps only when the live count is greater than 1', () {
      expect(NotePageTarget.toViewerPage(99, pageCount: 50), 50);
      expect(NotePageTarget.toViewerPage(12, pageCount: 50), 12);
    });

    test('forNoteOpen prefers the note stored page over a fallback of 1', () {
      expect(
        NotePageTarget.forNoteOpen(note: _note(page: 17), fallbackPage: 1),
        17,
      );
      expect(
        NotePageTarget.forNoteOpen(note: _note(page: 0), fallbackPage: 9),
        1,
      );
      expect(NotePageTarget.forNoteOpen(note: null, fallbackPage: 8), 8);
    });

    test('NoteOpenSequence goToPage receives the resolved stored page', () async {
      final steps = <int>[];
      final note = _note(page: 0);

      await NoteOpenSequence.run(
        waitUntilReady: () async {},
        page: NotePageTarget.forNoteOpen(note: note, fallbackPage: 1),
        goToPage: (page) async => steps.add(page),
        openNote: () async {},
      );

      expect(steps, [1]);
    });

    test('hub open of a mid-book note is not rewritten to page 1', () async {
      final steps = <int>[];
      final note = _note(page: 214);

      await NoteOpenSequence.run(
        waitUntilReady: () async {},
        page: NotePageTarget.forNoteOpen(
          note: note,
          fallbackPage: 1,
          pageCount: 1,
        ),
        goToPage: (page) async => steps.add(page),
        openNote: () async {},
      );

      expect(steps, [214]);
    });
  });

  group('noteFocusPdfBounds', () {
    test('uses the stored selection box when present', () {
      final note = Note(
        id: 'n-sel',
        documentId: 'd1',
        page: 14,
        x: 0.1,
        y: 0.1,
        text: 'Hull jump',
        colorLabelId: ColorLabel.orangeId,
        createdAt: DateTime.utc(2026, 9, 14),
        updatedAt: DateTime.utc(2026, 9, 14),
        selection: const NoteSelection(
          text: 'derivative',
          left: 0.25,
          top: 0.25,
          right: 0.45,
          bottom: 0.275,
        ),
      );
      final bounds = noteFocusPdfBounds(
        note: note,
        pageWidth: 400,
        pageHeight: 800,
        pad: 10,
      );
      expect(bounds.left, closeTo(90, 0.0001));
      expect(bounds.right, closeTo(190, 0.0001));
      expect(bounds.top, closeTo(610, 0.0001));
      expect(bounds.bottom, closeTo(570, 0.0001));
    });

    test('falls back to the marker when there is no selection box', () {
      final bounds = noteFocusPdfBounds(
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
