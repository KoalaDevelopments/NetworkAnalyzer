import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_analyzer/src/monitoring/rolling_window.dart';

import 'fixtures.dart';

void main() {
  group('RollingWindow', () {
    test('never exceeds its capacity', () {
      final RollingWindow window = RollingWindow(3);

      for (final sample in steady(10, 20)) {
        window.add(sample);
      }

      check(window.length).equals(3);
    });

    test('evicts the oldest sample first', () {
      final RollingWindow window = RollingWindow(2)
        ..add(hit(0, 10))
        ..add(hit(1, 20))
        ..add(hit(2, 30));

      check(
        window.samples.map((sample) => sample.sequence).toList(),
      ).deepEquals(<int>[1, 2]);
    });

    test('reports no loss while empty', () {
      check(RollingWindow(5).packetLossPercent).equals(0);
    });

    test('counts loss over a partially filled window', () {
      final RollingWindow window = RollingWindow(10)
        ..add(hit(0, 20))
        ..add(miss(1))
        ..add(hit(2, 20))
        ..add(hit(3, 20));

      check(window.packetLossPercent).equals(25);
    });

    test('mean latency ignores failed samples', () {
      final RollingWindow window = RollingWindow(10)
        ..add(hit(0, 10))
        ..add(miss(1))
        ..add(hit(2, 30));

      check(window.meanLatency).equals(const Duration(milliseconds: 20));
      check(window.successes.length).equals(2);
    });

    test('mean latency is null with no successes', () {
      final RollingWindow window = RollingWindow(10)..add(miss(0));

      check(window.meanLatency).isNull();
    });
  });
}
