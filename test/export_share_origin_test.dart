import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/services/export_share.dart';

void main() {
  tearDown(() {
    ExportShare.override = null;
    ExportShare.lastSharePositionOrigin = null;
  });

  test('rejects a zero rect and supplies a non-zero fallback inside the view', () {
    const view = Size(393, 852);
    final origin = ShareOrigin.resolve(
      preferred: Rect.zero,
      viewSize: view,
    );

    expect(origin, isNot(Rect.zero));
    expect(origin.width, greaterThan(0));
    expect(origin.height, greaterThan(0));
    expect(ShareOrigin.isUsable(Rect.zero, view), isFalse);
    expect(ShareOrigin.isUsable(origin, view), isTrue);
    expect(origin.left, greaterThanOrEqualTo(0));
    expect(origin.top, greaterThanOrEqualTo(0));
    expect(origin.right, lessThanOrEqualTo(view.width));
    expect(origin.bottom, lessThanOrEqualTo(view.height));
  });

  test('rejects a missing origin and still stays inside iPhone-sized bounds', () {
    final origin = ShareOrigin.resolve();
    expect(origin.width, greaterThan(0));
    expect(origin.height, greaterThan(0));
    expect(ShareOrigin.isUsable(origin, const Size(393, 852)), isTrue);
  });

  test('clamps an out-of-bounds positive rect into the view', () {
    const view = Size(393, 852);
    final origin = ShareOrigin.resolve(
      preferred: const Rect.fromLTWH(380, 840, 40, 40),
      viewSize: view,
    );
    expect(ShareOrigin.isUsable(origin, view), isTrue);
    expect(origin.width, greaterThan(0));
    expect(origin.height, greaterThan(0));
  });

  test('ExportShare.files never records a zero origin even if one is passed', () async {
    ExportShare.override = (_, _) async {};
    final dir = await Directory.systemTemp.createTemp('shelf-share-origin-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/notes.json')..writeAsStringSync('{}');

    await ExportShare.files(
      [file],
      subject: 'Shelf notes',
      sharePositionOrigin: Rect.zero,
    );

    final origin = ExportShare.lastSharePositionOrigin;
    expect(origin, isNotNull);
    expect(origin!.width, greaterThan(0));
    expect(origin.height, greaterThan(0));
    expect(ShareOrigin.isUsable(origin, const Size(393, 852)), isTrue);
  });

  testWidgets('supplies a non-zero origin from a GlobalKey button', (
    tester,
  ) async {
    final key = GlobalKey();
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: IconButton(
              key: key,
              icon: const Icon(Icons.more_vert),
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final origin = ShareOrigin.fromKey(key, viewSize: const Size(393, 852));
    expect(origin, isNot(Rect.zero));
    expect(origin.width, greaterThan(0));
    expect(origin.height, greaterThan(0));
    expect(ShareOrigin.isUsable(origin, const Size(393, 852)), isTrue);

    final box = key.currentContext!.findRenderObject()! as RenderBox;
    final expected = box.localToGlobal(Offset.zero) & box.size;
    expect(origin, expected);
  });

  testWidgets('supplies a non-zero origin from a BuildContext', (tester) async {
    BuildContext? captured;
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox(width: 48, height: 48);
            },
          ),
        ),
      ),
    );
    await tester.pump();

    final origin = ShareOrigin.resolve(
      context: captured,
      viewSize: const Size(393, 852),
    );
    expect(origin.width, 48);
    expect(origin.height, 48);
    expect(ShareOrigin.isUsable(origin, const Size(393, 852)), isTrue);
  });
}
