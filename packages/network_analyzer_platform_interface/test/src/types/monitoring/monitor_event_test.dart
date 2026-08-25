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

  group('MonitorEvent', () {
    test('requires a UTC timestamp', () {
      check(
        () => MonitorEvent(
          session: session,
          timestamp: DateTime(2026, 8, 24, 12),
          kind: MonitorEventKind.monitoringStarted,
          message: 'started',
        ),
      ).throws<ArgumentError>();
    });

    test('equal values are equal and share a hash code', () {
      MonitorEvent build() => MonitorEvent(
        session: session,
        timestamp: DateTime.utc(2026, 8, 24, 12, 0, 5),
        kind: MonitorEventKind.healthChanged,
        message: 'changed',
      );

      check(build()).equals(build());
      check(build().hashCode).equals(build().hashCode);
    });
  });

  group('MonitorEventKind', () {
    test('every kind declares how it is triggered', () {
      final Iterable<MonitorEventKind> levelTriggered = MonitorEventKind.values
          .where((MonitorEventKind kind) => !kind.isEdgeTriggered);

      check(levelTriggered).unorderedEquals(<MonitorEventKind>[
        MonitorEventKind.packetLossDetected,
        MonitorEventKind.highJitterDetected,
        MonitorEventKind.latencySpikeDetected,
      ]);
    });
  });
}
