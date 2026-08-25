import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';

void main() {
  group('monitoring failures', () {
    final List<(String, Failure)> cases = <(String, Failure)>[
      ('PermissionFailure', const PermissionFailure(message: 'denied')),
      (
        'UnsupportedCapabilityFailure',
        const UnsupportedCapabilityFailure(message: 'no icmp'),
      ),
      (
        'GatewayDiscoveryFailure',
        const GatewayDiscoveryFailure(message: 'no route'),
      ),
      (
        'InvalidConfigurationFailure',
        const InvalidConfigurationFailure(message: 'bad'),
      ),
      (
        'TargetUnreachableFailure',
        const TargetUnreachableFailure(message: 'unreachable'),
      ),
      ('ProbeTimeoutFailure', const ProbeTimeoutFailure(message: 'timeout')),
      (
        'SessionAlreadyRunningFailure',
        const SessionAlreadyRunningFailure(message: 'running'),
      ),
      ('NoActiveSessionFailure', const NoActiveSessionFailure(message: 'idle')),
    ];

    for (final (String name, Failure failure) in cases) {
      test('$name implements Failure and exposes its message', () {
        check(failure).isA<Failure>();
        check(failure.message).isNotEmpty();
        check(failure.details).isNull();
        check(failure.toString()).startsWith('$name: ');
      });
    }

    test('details are appended to toString when present', () {
      const PermissionFailure failure = PermissionFailure(
        message: 'denied',
        details: 'ACCESS_NETWORK_STATE',
      );
      check(failure.toString()).equals(
        'PermissionFailure: denied (ACCESS_NETWORK_STATE)',
      );
    });

    test('PermissionFailure carries remediation guidance', () {
      const PermissionFailure failure = PermissionFailure(
        message: 'denied',
        remediation: 'Grant ACCESS_NETWORK_STATE.',
      );
      check(failure.remediation).equals('Grant ACCESS_NETWORK_STATE.');
    });
  });
}
