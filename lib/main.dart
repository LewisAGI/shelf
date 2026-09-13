import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'app.dart';
import 'data/shelf_store.dart';
import 'services/ai_secure_storage.dart';
import 'services/ai_settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize();
  final store = ShelfStore();
  final ai = AiSettingsController(storage: KeychainAiSecureStorage());
  await store.init();
  await ai.load();
  runApp(ShelfApp(store: store, ai: ai));
}
