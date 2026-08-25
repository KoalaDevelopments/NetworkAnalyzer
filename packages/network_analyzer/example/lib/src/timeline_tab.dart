import 'package:flutter/material.dart';
import 'package:network_analyzer/network_analyzer.dart';

/// Shows measurements and events interleaved, newest first.
class TimelineTab extends StatefulWidget {
  /// Creates the tab.
  const TimelineTab({required this.updates, super.key});

  /// The stream to render.
  final Stream<MonitorUpdate> updates;

  @override
  State<TimelineTab> createState() => _TimelineTabState();
}

class _TimelineTabState extends State<TimelineTab> {
  final List<String> _entries = <String>[];

  /// A lost probe has no latency; show that honestly instead of "null".
  static String _latency(ConnectionMetrics metrics) {
    final Duration? latency = metrics.latency;
    if (latency == null) {
      return 'no reply';
    }
    return '${latency.inMicroseconds / 1000} ms';
  }

  @override
  void initState() {
    super.initState();
    widget.updates.listen((MonitorUpdate update) {
      if (!mounted) {
        return;
      }
      // Exhaustive: MonitorUpdate is sealed, so no default branch exists.
      final String entry = switch (update) {
        MetricsUpdate(:final ConnectionMetrics metrics) =>
          'metrics · ${metrics.health.name} · ${_latency(metrics)}',
        EventUpdate(:final MonitorEvent event) =>
          'event · ${event.kind.name} · ${event.message}',
      };
      setState(() => _entries.insert(0, entry));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_entries.isEmpty) {
      return const Center(child: Text('Start monitoring to see the timeline.'));
    }
    return ListView.builder(
      key: const Key('timeline-list'),
      itemCount: _entries.length,
      itemBuilder: (BuildContext context, int index) =>
          ListTile(dense: true, title: Text(_entries[index])),
    );
  }
}
