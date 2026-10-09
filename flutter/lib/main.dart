import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'di.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    // A phone-shaped default window keeps the UI pixel-consistent with the
    // Android app, while staying freely resizable.
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      title: 'Hermes',
      size: Size(480, 880),
      minimumSize: Size(380, 600),
      center: true,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  await Di.init();
  Di.appVisibility.isForeground = true;
  runApp(const HermesApp());
}
