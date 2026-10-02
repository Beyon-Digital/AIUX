import 'package:beyond_aiux/beyond_aiux.dart';
import 'package:flutter/material.dart';

import 'src/demo_controller.dart';
import 'src/root_view.dart';

/// The demo app — a fullscreen AIUX conversation over the real Dart-FFI
/// session core.
void main() {
  runApp(const AiuxExampleApp());
}

class AiuxExampleApp extends StatelessWidget {
  const AiuxExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AiuxTheme(
      data: AiuxThemeData.standard(),
      child: MaterialApp(
        title: 'AIUX demo',
        theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
        darkTheme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: AiuxExampleRootView(controller: DemoController.bootstrap()),
      ),
    );
  }
}
