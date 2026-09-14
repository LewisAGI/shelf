import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// iOS (and iPad UIPopover) reject a missing or zero [sharePositionOrigin].
/// Android's share sheet ignores origin — omit it there.
///
/// Resolve a real button/menu-anchor rect, or a safe non-zero fallback
/// inside the source view. Never returns [Rect.zero].
class ShareOrigin {
  static const Size _fallbackView = Size(393, 852);
  static const double _fallbackBox = 44;

  /// True when [rect] has positive size and sits inside [viewSize].
  static bool isUsable(Rect rect, Size viewSize) {
    if (viewSize.width <= 0 || viewSize.height <= 0) {
      return false;
    }
    if (rect.hasNaN || rect.width <= 0 || rect.height <= 0) {
      return false;
    }
    if (rect.left < 0 || rect.top < 0) {
      return false;
    }
    if (rect.right > viewSize.width || rect.bottom > viewSize.height) {
      return false;
    }
    return true;
  }

  /// Centre of [viewSize], at least 1×1, fully inside the view.
  static Rect fallback(Size viewSize) {
    final width = viewSize.width > 0 ? viewSize.width : _fallbackView.width;
    final height = viewSize.height > 0 ? viewSize.height : _fallbackView.height;
    final size = _fallbackBox.clamp(1.0, width).clamp(1.0, height).toDouble();
    final left = ((width - size) / 2).clamp(0.0, width - size);
    final top = ((height - size) / 2).clamp(0.0, height - size);
    return Rect.fromLTWH(left, top, size, size);
  }

  /// Prefer [preferred], then a [GlobalKey] / [BuildContext] box, else fallback.
  /// Zero or out-of-bounds rects are rejected, never passed through.
  static Rect resolve({
    Rect? preferred,
    BuildContext? context,
    GlobalKey? key,
    Size? viewSize,
  }) {
    final view = viewSize ?? viewSizeOf(context ?? key?.currentContext);
    for (final candidate in [
      preferred,
      fromContext(key?.currentContext),
      fromContext(context),
    ]) {
      if (candidate == null) {
        continue;
      }
      if (isUsable(candidate, view)) {
        return candidate;
      }
      if (candidate.width > 0 && candidate.height > 0) {
        final fitted = fitInView(candidate, view);
        if (isUsable(fitted, view)) {
          return fitted;
        }
      }
    }
    return fallback(view);
  }

  static Rect? fromContext(BuildContext? context) {
    if (context == null || !context.mounted) {
      return null;
    }
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return null;
    }
    if (box.size.width <= 0 || box.size.height <= 0) {
      return null;
    }
    return box.localToGlobal(Offset.zero) & box.size;
  }

  static Rect fromKey(GlobalKey key, {Size? viewSize}) {
    return resolve(key: key, viewSize: viewSize);
  }

  static Rect fitInView(Rect rect, Size viewSize) {
    final width = viewSize.width > 0 ? viewSize.width : _fallbackView.width;
    final height = viewSize.height > 0 ? viewSize.height : _fallbackView.height;
    final boxWidth = rect.width.clamp(1.0, width).toDouble();
    final boxHeight = rect.height.clamp(1.0, height).toDouble();
    final left = rect.left.clamp(0.0, width - boxWidth).toDouble();
    final top = rect.top.clamp(0.0, height - boxHeight).toDouble();
    return Rect.fromLTWH(left, top, boxWidth, boxHeight);
  }

  static Size viewSizeOf(BuildContext? context) {
    if (context != null && context.mounted) {
      final media = MediaQuery.maybeSizeOf(context);
      if (media != null && media.width > 0 && media.height > 0) {
        return media;
      }
      final view = View.maybeOf(context);
      if (view != null) {
        final logical = view.physicalSize / view.devicePixelRatio;
        if (logical.width > 0 && logical.height > 0) {
          return logical;
        }
      }
    }
    return _fallbackView;
  }

  /// iOS / iPad popovers need a valid origin. Android must not rely on one.
  static bool requiresSharePositionOrigin([TargetPlatform? platform]) {
    final resolved = platform ?? defaultTargetPlatform;
    return resolved == TargetPlatform.iOS || resolved == TargetPlatform.macOS;
  }
}

/// System share sheet. Tests assign [override] so they never open a real sheet.
class ExportShare {
  static Future<void> Function(List<String> paths, String subject)? override;

  /// Last origin resolved for the share sheet. Tests read this.
  static Rect? lastSharePositionOrigin;

  /// Whether the last share attached [sharePositionOrigin] (iOS popover only).
  static bool lastShareAttachedOrigin = false;

  static Future<void> files(
    List<File> files, {
    required String subject,
    BuildContext? shareContext,
    GlobalKey? shareKey,
    Rect? sharePositionOrigin,
    TargetPlatform? platform,
  }) async {
    final origin = ShareOrigin.resolve(
      preferred: sharePositionOrigin,
      context: shareContext,
      key: shareKey,
    );
    lastSharePositionOrigin = origin;
    final attachOrigin = ShareOrigin.requiresSharePositionOrigin(platform);
    lastShareAttachedOrigin = attachOrigin;
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
        sharePositionOrigin: attachOrigin ? origin : null,
      ),
    );
  }
}
