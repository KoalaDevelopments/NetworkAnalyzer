import 'package:flutter/material.dart';
import 'package:network_analyzer/network_analyzer.dart';

/// Shows the latest measurement from the metrics stream.
class MetricsTab extends StatelessWidget {
  /// Creates the tab.
  const MetricsTab({required this.metrics, super.key});

  /// The stream to render.
  final Stream<ConnectionMetrics> metrics;

  @override
  Widget build(BuildContext context) => StreamBuilder<ConnectionMetrics>(
    stream: metrics,
    builder: (BuildContext context, AsyncSnapshot<ConnectionMetrics> snapshot) {
      final ConnectionMetrics? current = snapshot.data;
      if (current == null) {
        return const Center(child: Text('Start monitoring to see metrics.'));
      }
      return _MetricsView(metrics: current);
    },
  );
}

class _MetricsView extends StatelessWidget {
  const _MetricsView({required this.metrics});

  final ConnectionMetrics metrics;

  String _ms(Duration? value) =>
      value == null ? '—' : '${value.inMicroseconds / 1000} ms';

  @override
  Widget build(BuildContext context) {
    final SessionData session = metrics.session;
    return ListView(
      key: const Key('metrics-list'),
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _HealthChip(health: metrics.health),
        const SizedBox(height: 16),
        _Row(label: 'Latency', value: _ms(metrics.latency)),
        _Row(label: 'Packet loss', value: '${metrics.packetLossPercent}%'),
        _Row(label: 'Jitter', value: _ms(metrics.jitter)),
        _Row(label: 'Spikes', value: '${metrics.spikeCount}'),
        _Row(label: 'Uptime', value: _formatUptime(metrics.uptime)),
        const Divider(),
        _Row(label: 'Average', value: _ms(metrics.averageLatency)),
        _Row(label: 'Lowest', value: _ms(metrics.lowestLatency)),
        _Row(label: 'Highest', value: _ms(metrics.highestLatency)),
        const Divider(),
        _Row(label: 'Interface', value: session.interfaceType.name),
        _Row(label: 'Protocol', value: session.protocol.name),
        _Row(label: 'Monitor', value: session.kind.name),
        _Row(label: 'Device IP', value: session.deviceIpAddress),
        _Row(label: 'Target', value: session.targetAddress),
        _Row(label: 'Started', value: session.startedAt.toLocal().toString()),
      ],
    );
  }

  static String _formatUptime(Duration uptime) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(uptime.inHours)}:${two(uptime.inMinutes % 60)}:'
        '${two(uptime.inSeconds % 60)}';
  }
}

class _HealthChip extends StatelessWidget {
  const _HealthChip({required this.health});

  final ConnectionHealth health;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color color = switch (health) {
      ConnectionHealth.stable => colors.primary,
      ConnectionHealth.unstable => colors.tertiary,
      ConnectionHealth.critical => colors.error,
      ConnectionHealth.unknown => colors.outline,
    };
    return Chip(
      key: const Key('health-chip'),
      label: Text(health.name),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: text.labelLarge),
          Text(value, style: text.bodyLarge),
        ],
      ),
    );
  }
}
