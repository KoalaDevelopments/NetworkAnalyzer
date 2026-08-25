import 'package:flutter/material.dart';

import 'src/monitoring_screen.dart';

void main() => runApp(const ExampleApp());

/// Example host application for the network_analyzer plugin.
class ExampleApp extends StatelessWidget {
  /// Creates the example app.
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'NetworkAnalyzer Example',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0D47A1),
      ),
    ),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0D47A1),
        brightness: Brightness.dark,
      ),
    ),
    home: const MonitoringScreen(),
  );
}
