import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:network_analyzer/network_analyzer.dart';

import 'events_tab.dart';
import 'metrics_tab.dart';
import 'target_picker.dart';
import 'timeline_tab.dart';

/// Exercises every part of the real-time monitoring API.
///
/// The example app is the manual verification surface required by the
/// constitution, so this screen deliberately touches all three streams, both
/// monitor kinds, every preset and a custom target.
class MonitoringScreen extends StatefulWidget {
  /// Creates the screen.
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  final NetworkAnalyzer _analyzer = NetworkAnalyzer();
  final ValueNotifier<Failure?> _failure = ValueNotifier<Failure?>(null);
  final ValueNotifier<bool> _running = ValueNotifier<bool>(false);

  MonitorKind _kind = MonitorKind.internet;
  MonitorProtocol _protocol = MonitorProtocol.tcp;
  MonitorHost _host = PresetHost.google;

  @override
  void dispose() {
    _analyzer.dispose();
    _failure.dispose();
    _running.dispose();
    super.dispose();
  }

  MonitorInterface _buildTarget() => switch (_kind) {
    MonitorKind.internet => InternetInterface(
      protocol: _protocol,
      host: _host,
    ),
    MonitorKind.gateway => GatewayInterface(
      // A gateway monitor rejects UDP, so fall back to TCP rather than
      // letting the picker build something invalid.
      protocol: _protocol == MonitorProtocol.udp
          ? MonitorProtocol.tcp
          : _protocol,
    ),
  };

  Future<void> _start() async {
    final Result<SessionData, Failure> result = await _analyzer.startMonitoring(
      _buildTarget(),
    );
    result.fold(
      onFailure: (Failure failure) {
        _failure.value = failure;
        _running.value = false;
      },
      onSuccess: (Success<SessionData> success) {
        _failure.value = null;
        _running.value = true;
      },
    );
  }

  Future<void> _stop() async {
    await _analyzer.stopMonitoring();
    _running.value = false;
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Real-time monitoring'),
        bottom: const TabBar(
          tabs: <Widget>[
            Tab(text: 'Metrics', icon: Icon(Icons.speed)),
            Tab(text: 'Events', icon: Icon(Icons.list_alt)),
            Tab(text: 'Timeline', icon: Icon(Icons.timeline)),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          TargetPicker(
            kind: _kind,
            protocol: _protocol,
            host: _host,
            onKindChanged: (MonitorKind kind) => setState(() => _kind = kind),
            onProtocolChanged: (MonitorProtocol protocol) =>
                setState(() => _protocol = protocol),
            onHostChanged: (MonitorHost host) => setState(() => _host = host),
          ),
          _Controls(running: _running, onStart: _start, onStop: _stop),
          _FailureBanner(failure: _failure),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                MetricsTab(metrics: _analyzer.metrics),
                EventsTab(events: _analyzer.events),
                TimelineTab(updates: _analyzer.updates),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.running,
    required this.onStart,
    required this.onStop,
  });

  final ValueListenable<bool> running;
  final Future<void> Function() onStart;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: ValueListenableBuilder<bool>(
      valueListenable: running,
      builder: (BuildContext context, bool isRunning, _) => Row(
        children: <Widget>[
          Expanded(
            child: FilledButton.icon(
              key: const Key('start-monitoring'),
              onPressed: isRunning ? null : () => onStart(),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('stop-monitoring'),
              onPressed: isRunning ? () => onStop() : null,
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.failure});

  final ValueListenable<Failure?> failure;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Failure?>(
    valueListenable: failure,
    builder: (BuildContext context, Failure? value, _) {
      if (value == null) {
        return const SizedBox.shrink();
      }
      final ThemeData theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: <Widget>[
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value.message,
                key: const Key('failure-message'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
