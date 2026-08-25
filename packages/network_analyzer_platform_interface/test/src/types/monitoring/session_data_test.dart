import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';

void main() {
  group('SessionData', () {
    final SessionData session = SessionData(
      interfaceType: NetworkInterfaceType.wifi,
      protocol: MonitorProtocol.tcp,
      kind: MonitorKind.internet,
      deviceIpAddress: '192.168.1.42',
      targetAddress: '8.8.8.8',
      targetName: 'Google Public DNS',
      startedAt: DateTime.utc(2026, 8, 24, 12),
    );

    test('keeps the device address and the target address distinct', () {
      check(session.deviceIpAddress).equals('192.168.1.42');
      check(session.targetAddress).equals('8.8.8.8');
    });

    test('requires startedAt to be UTC', () {
      check(
        () => SessionData(
          interfaceType: NetworkInterfaceType.wifi,
          protocol: MonitorProtocol.tcp,
          kind: MonitorKind.internet,
          deviceIpAddress: '192.168.1.42',
          targetAddress: '8.8.8.8',
          targetName: 'Google Public DNS',
          startedAt: DateTime(2026, 8, 24, 12),
        ),
      ).throws<ArgumentError>();
    });

    test('copyWith replaces only the named fields', () {
      final SessionData updated = session.copyWith(
        interfaceType: NetworkInterfaceType.cellular4g,
        deviceIpAddress: '10.1.2.3',
      );
      check(updated.interfaceType).equals(NetworkInterfaceType.cellular4g);
      check(updated.deviceIpAddress).equals('10.1.2.3');
      check(updated.targetAddress).equals('8.8.8.8');
      check(updated.startedAt).equals(session.startedAt);
    });

    test('equal values are equal and share a hash code', () {
      check(session).equals(session.copyWith());
      check(session.hashCode).equals(session.copyWith().hashCode);
    });
  });
}
