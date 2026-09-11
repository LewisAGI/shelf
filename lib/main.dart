import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'app.dart';
import 'data/shelf_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize();
  final store = ShelfStore();
  await store.init();
  runApp(ShelfApp(store: store));
}
