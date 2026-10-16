import 'package:flutter_test/flutter_test.dart';

/// Lets async export file IO finish, then flushes the test zone.
///
/// [done] stops the wait once the share hook has recorded a result.
/// Close tests pass a flag that stays false, so a mistaken share still
/// has time to show up.
Future<void> flushExport(WidgetTester tester, bool Function() done) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  for (var i = 0; i < 8 && !done(); i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
  }
}
