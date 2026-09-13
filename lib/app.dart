import 'package:flutter/material.dart';

import 'data/shelf_store.dart';
import 'screens/home_shell.dart';
import 'services/ai_settings_controller.dart';
import 'theme/shelf_theme.dart';
import 'widgets/ai_scope.dart';

class ShelfApp extends StatelessWidget {
  const ShelfApp({super.key, required this.store, required this.ai});

  final ShelfStore store;
  final AiSettingsController ai;

  @override
  Widget build(BuildContext context) {
    return AiScope(
      controller: ai,
      child: MaterialApp(
        title: 'Shelf',
        debugShowCheckedModeBanner: false,
        theme: ShelfTheme.light(),
        home: HomeShell(store: store),
      ),
    );
  }
}
