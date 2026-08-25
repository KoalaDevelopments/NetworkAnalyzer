import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';

void main() {
  group('HealthThresholds', () {
    test('documented defaults apply when nothing is supplied', () {
      final HealthThresholds thresholds = HealthThresholds();
      check(thresholds.stableLatency).equals(const Duration(milliseconds: 100));
      check(
        thresholds.unstableLatency,
      ).equals(const Duration(milliseconds: 250));
      check(thresholds.stablePacketLossPercent).equals(1);
      check(thresholds.unstablePacketLossPercent).equals(5);
      check(thresholds.stableJitter).equals(const Duration(milliseconds: 30));
      check(thresholds.unstableJitter).equals(const Duration(milliseconds: 50));
      check(thresholds.spikeMultiplier).equals(2);
      check(thresholds.spikeMinDelta).equals(const Duration(milliseconds: 50));
      check(thresholds.minimumSamplesForVerdict).equals(3);
    });

    test('an omitted field falls back to its default', () {
      final HealthThresholds thresholds = HealthThresholds(
        stableLatency: const Duration(milliseconds: 40),
      );
      check(thresholds.stableLatency).equals(const Duration(milliseconds: 40));
      check(
        thresholds.unstableLatency,
      ).equals(const Duration(milliseconds: 250));
    });

    test('rejects a stable latency at or above the unstable latency', () {
      check(
        () => HealthThresholds(
          stableLatency: const Duration(milliseconds: 250),
        ),
      ).throws<ArgumentError>();
    });

    test('rejects a stable packet loss at or above the unstable loss', () {
      check(
        () => HealthThresholds(stablePacketLossPercent: 5),
      ).throws<ArgumentError>();
    });

    test('rejects a stable jitter at or above the unstable jitter', () {
      check(
        () => HealthThresholds(stableJitter: const Duration(seconds: 1)),
      ).throws<ArgumentError>();
    });

    test('rejects a packet loss percentage outside 0..100', () {
      check(
        () => HealthThresholds(stablePacketLossPercent: -1),
      ).throws<ArgumentError>();
      check(
        () => HealthThresholds(unstablePacketLossPercent: 101),
      ).throws<ArgumentError>();
    });

    test('rejects a spike multiplier at or below 1', () {
      check(() => HealthThresholds(spikeMultiplier: 1)).throws<ArgumentError>();
    });

    test('rejects a minimum sample count below 1', () {
      check(
        () => HealthThresholds(minimumSamplesForVerdict: 0),
      ).throws<ArgumentError>();
    });
  });
}
