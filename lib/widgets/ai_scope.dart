import 'package:flutter/material.dart';

import '../services/ai_settings_controller.dart';

/// Provides the BYO AI controller to Settings, Notes, and the composer.
class AiScope extends InheritedNotifier<AiSettingsController> {
  const AiScope({
    super.key,
    required AiSettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  static AiSettingsController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AiScope>()?.notifier;
  }

  static AiSettingsController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'AiScope not found in the widget tree');
    return controller!;
  }
}
