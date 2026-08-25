import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';

void main() {
  group('ProbeSample', () {
    test('a successful sample carries a round-trip time', () {
      final ProbeSample sample = ProbeSample(
        sequence: 0,
        roundTrip: const Duration(milliseconds: 20),
        outcome: ProbeOutcome.success,
        sinceSessionStart: const Duration(seconds: 1),
      );
      check(sample.roundTrip).equals(const Duration(milliseconds: 20));
      check(sample.isSuccess).isTrue();
    });

    test('a failed sample has no round-trip time', () {
      final ProbeSample sample = ProbeSample(
        sequence: 1,
        outcome: ProbeOutcome.timeout,
        sinceSessionStart: const Duration(seconds: 2),
      );
      check(sample.roundTrip).isNull();
      check(sample.isSuccess).isFalse();
    });

    test('rejects a round-trip time on a non-successful outcome', () {
      check(
        () => ProbeSample(
          sequence: 1,
          roundTrip: const Duration(milliseconds: 20),
          outcome: ProbeOutcome.timeout,
          sinceSessionStart: const Duration(seconds: 2),
        ),
      ).throws<ArgumentError>();
    });

    test('rejects a successful outcome without a round-trip time', () {
      check(
        () => ProbeSample(
          sequence: 1,
          outcome: ProbeOutcome.success,
          sinceSessionStart: const Duration(seconds: 2),
        ),
      ).throws<ArgumentError>();
    });

    test('rejects a negative sequence number', () {
      check(
        () => ProbeSample(
          sequence: -1,
          outcome: ProbeOutcome.timeout,
          sinceSessionStart: const Duration(seconds: 1),
        ),
      ).throws<ArgumentError>();
    });
  });

  group('MonitorSignal', () {
    test('is sealed, so a switch over it is exhaustive', () {
      final List<MonitorSignal> signals = <MonitorSignal>[
        ProbeSample(
          sequence: 0,
          roundTrip: const Duration(milliseconds: 20),
          outcome: ProbeOutcome.success,
          sinceSessionStart: const Duration(seconds: 1),
        ),
        const NetworkStateChange(interfaceType: NetworkInterfaceType.cellular),
      ];
      final List<String> labels = signals
          .map(
            (MonitorSignal signal) => switch (signal) {
              ProbeSample() => 'sample',
              NetworkStateChange() => 'state',
            },
          )
          .toList();
      check(labels).deepEquals(<String>['sample', 'state']);
    });
  });
}
