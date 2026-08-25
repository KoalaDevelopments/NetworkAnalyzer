import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_analyzer/network_analyzer.dart';
import 'package:network_analyzer/src/monitoring/spike_detector.dart';

import 'fixtures.dart';

void main() {
  group('SpikeDetector', () {
    final SpikeDetector detector = SpikeDetector(HealthThresholds());

    test('a large jump above a steady baseline is a spike', () {
      check(detector.isSpike(hit(3, 300), steady(3, 20))).isTrue();
    });

    test('a small jump is not a spike, even at more than twice the mean', () {
      // 45 ms is over 2x the 20 ms mean, but only 25 ms above it — under the
      // 50 ms floor that separates a spike from ordinary noise.
      check(detector.isSpike(hit(3, 45), steady(3, 20))).isFalse();
    });

    test('a large absolute jump under the multiplier is not a spike', () {
      // 260 ms clears the 50 ms margin over a 200 ms mean, but is not double
      // it.
      check(detector.isSpike(hit(3, 260), steady(3, 200))).isFalse();
    });

    test('too few earlier samples means no verdict', () {
      check(detector.isSpike(hit(2, 500), steady(2, 20))).isFalse();
    });

    test('a failed sample is never a spike', () {
      check(detector.isSpike(miss(3), steady(3, 20))).isFalse();
    });

    test('custom thresholds move the bar', () {
      final SpikeDetector sensitive = SpikeDetector(
        HealthThresholds(
          spikeMultiplier: 1.5,
          spikeMinDelta: const Duration(milliseconds: 5),
        ),
      );

      check(sensitive.isSpike(hit(3, 45), steady(3, 20))).isTrue();
    });
  });
}
