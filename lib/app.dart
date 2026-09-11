import 'package:flutter/material.dart';

import 'data/shelf_store.dart';
import 'screens/home_shell.dart';
import 'theme/shelf_theme.dart';

class ShelfApp extends StatelessWidget {
  const ShelfApp({super.key, required this.store});

  final ShelfStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shelf',
      debugShowCheckedModeBanner: false,
      theme: ShelfTheme.light(),
      home: HomeShell(store: store),
    );
  }
}
