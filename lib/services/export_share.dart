import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// System share sheet. Tests assign [override] so they never open a real sheet.
class ExportShare {
  static Future<void> Function(List<String> paths, String subject)? override;

  static Future<void> files(
    List<File> files, {
    required String subject,
  }) async {
    final hook = override;
    final paths = files.map((file) => file.path).toList();
    if (hook != null) {
      await hook(paths, subject);
      return;
    }
    // Widget tests have no share sheet; hanging on the platform channel
    // would stall `flutter test`.
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    if (bindingName.contains('Test')) {
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [for (final file in files) XFile(file.path)],
        subject: subject,
      ),
    );
  }
}
