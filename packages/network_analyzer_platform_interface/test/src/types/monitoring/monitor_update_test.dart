import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';

void main() {
  final SessionData session = SessionData(
    interfaceType: NetworkInterfaceType.wifi,
    protocol: MonitorProtocol.tcp,
    kind: MonitorKind.internet,
    deviceIpAddress: '192.168.1.42',
    targetAddress: '8.8.8.8',
    targetName: 'Google Public DNS',
    startedAt: DateTime.utc(2026, 8, 24, 12),
  );

  final ConnectionMetrics metrics = ConnectionMetrics(
    session: session,
    packetLossPercent: 0,
    spikeCount: 0,
    health: ConnectionHealth.stable,
    uptime: const Duration(seconds: 5),
    latency: const Duration(milliseconds: 20),
  );

  final MonitorEvent event = MonitorEvent(
    session: session,
    timestamp: DateTime.utc(2026, 8, 24, 12, 0, 5),
    kind: MonitorEventKind.monitoringStarted,
    message: 'started',
  );

  group('MonitorUpdate', () {
    test('a switch over it needs no default branch', () {
      final List<MonitorUpdate> updates = <MonitorUpdate>[
        MetricsUpdate(metrics),
        EventUpdate(event),
      ];

      final List<String> described = updates
          .map(
            (MonitorUpdate update) => switch (update) {
              MetricsUpdate(:final ConnectionMetrics metrics) =>
                metrics.health.name,
              EventUpdate(:final MonitorEvent event) => event.kind.name,
            },
          )
          .toList();

      check(described).deepEquals(<String>['stable', 'monitoringStarted']);
    });

    test('every update exposes the session that produced it', () {
      check(MetricsUpdate(metrics).session).equals(session);
      check(EventUpdate(event).session).equals(session);
    });

    test('equal values are equal', () {
      check(MetricsUpdate(metrics)).equals(MetricsUpdate(metrics));
      check(EventUpdate(event)).equals(EventUpdate(event));
    });
  });
}
