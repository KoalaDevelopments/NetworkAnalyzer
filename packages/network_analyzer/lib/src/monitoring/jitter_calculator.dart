/// Jitter computation over a window of samples.
///
/// Jitter here is the mean absolute difference between consecutive
/// *successful* samples. That definition is window-scoped, deterministic and
/// explainable in one sentence — all three matter for a value that appears in
/// a public API and must be identical on both platforms.
///
/// The RFC 3550 smoothed estimator was considered and rejected: it carries
/// unbounded history, which contradicts the rolling window, and it is far
/// harder to assert against a fixture.
library;

import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';

/// The mean absolute difference between consecutive [successes].
///
/// Returns `null` with fewer than two successful samples, because a
/// difference needs two values and reporting zero would claim a perfectly
/// steady connection the plugin has not observed.
Duration? calculateJitter(List<ProbeSample> successes) {
  if (successes.length < 2) {
    return null;
  }
  int total = 0;
  for (int index = 1; index < successes.length; index++) {
    final int previous = successes[index - 1].roundTrip!.inMicroseconds;
    final int current = successes[index].roundTrip!.inMicroseconds;
    total += (current - previous).abs();
  }
  return Duration(microseconds: total ~/ (successes.length - 1));
}
