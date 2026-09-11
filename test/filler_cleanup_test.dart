import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/services/filler_cleanup.dart';

void main() {
  group('FillerCleanup', () {
    test('strips um, uh and like as whole words', () {
      const raw = 'This is, um, like a useful uh point';
      expect(FillerCleanup.clean(raw), 'This is, a useful point');
    });

    test('is case-insensitive and trims leftover space', () {
      expect(FillerCleanup.clean('UM the author UH argues'), 'The author argues');
    });

    test('leaves likely and dislike alone', () {
      expect(
        FillerCleanup.clean('I likely dislike this claim'),
        'I likely dislike this claim',
      );
    });

    test('returns empty string for filler-only speech', () {
      expect(FillerCleanup.clean('um uh like'), '');
    });

    test('capitalises the first remaining letter', () {
      expect(FillerCleanup.clean('um the method works'), 'The method works');
    });
  });
}
