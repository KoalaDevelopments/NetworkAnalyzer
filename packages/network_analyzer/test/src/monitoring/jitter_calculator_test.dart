import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_analyzer/network_analyzer.dart';
import 'package:network_analyzer/src/monitoring/jitter_calculator.dart';

import 'fixtures.dart';

void main() {
  group('calculateJitter', () {
    test('is null with no samples', () {
      check(calculateJitter(<ProbeSample>[])).isNull();
    });

    test('is null with a single sample', () {
      check(calculateJitter(<ProbeSample>[hit(0, 20)])).isNull();
    });

    test('is the absolute difference for two samples', () {
      check(
        calculateJitter(<ProbeSample>[hit(0, 20), hit(1, 35)]),
      ).equals(const Duration(milliseconds: 15));
    });

    test('direction does not matter', () {
      check(
        calculateJitter(<ProbeSample>[hit(0, 35), hit(1, 20)]),
      ).equals(const Duration(milliseconds: 15));
    });

    test('is the mean absolute consecutive difference', () {
      // Differences: 10, 10, 40 → mean 20.
      check(
        calculateJitter(<ProbeSample>[
          hit(0, 20),
          hit(1, 30),
          hit(2, 20),
          hit(3, 60),
        ]),
      ).equals(const Duration(milliseconds: 20));
    });

    test('is zero for a perfectly steady sequence', () {
      check(calculateJitter(steady(5, 20))).equals(Duration.zero);
    });
  });
}
