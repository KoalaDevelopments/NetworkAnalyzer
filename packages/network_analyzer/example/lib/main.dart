import 'package:flutter/material.dart';
import 'package:network_analyzer/network_analyzer.dart';

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
    home: const HomeScreen(),
  );
}

/// The example's entry screen.
///
/// The plugin ships no UI, so everything visual lives here — this app is the
/// manual verification surface the constitution requires.
class HomeScreen extends StatelessWidget {
  /// Creates the home screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('NetworkAnalyzer'),
        bottom: const TabBar(
          tabs: <Widget>[
            Tab(text: 'Monitoring', icon: Icon(Icons.monitor_heart)),
            Tab(text: 'Bridge', icon: Icon(Icons.cable)),
          ],
        ),
      ),
      body: const TabBarView(
        children: <Widget>[MonitoringScreen(), BridgeInfoScreen()],
      ),
    ),
  );
}

/// Displays the result of the bootstrap probe ([NetworkAnalyzer.getBridgeInfo]).
class BridgeInfoScreen extends StatefulWidget {
  /// Creates the screen.
  const BridgeInfoScreen({super.key});

  @override
  State<BridgeInfoScreen> createState() => _BridgeInfoScreenState();
}

class _BridgeInfoScreenState extends State<BridgeInfoScreen> {
  late final Future<Result<BridgeInfo, Failure>> _bridgeInfo;

  @override
  void initState() {
    super.initState();
    _bridgeInfo = NetworkAnalyzer().getBridgeInfo();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FutureBuilder<Result<BridgeInfo, Failure>>(
        future: _bridgeInfo,
        builder: (context, snapshot) {
          final Result<BridgeInfo, Failure>? result = snapshot.data;
          if (result == null) {
            return const CircularProgressIndicator();
          }
          return result.fold(
            onFailure: (Failure failure) => _FailureView(failure: failure),
            onSuccess: (Success<BridgeInfo> success) =>
                _BridgeInfoView(info: success.value),
          );
        },
      ),
    ),
  );
}

class _BridgeInfoView extends StatelessWidget {
  const _BridgeInfoView({required this.info});

  final BridgeInfo info;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('Native bridge online', style: textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          '${info.operatingSystem} ${info.osVersion}',
          style: textTheme.bodyLarge,
        ),
      ],
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.failure});

  final Failure failure;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.error_outline, color: theme.colorScheme.error),
        const SizedBox(height: 8),
        Text(
          failure.message,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ],
    );
  }
}
