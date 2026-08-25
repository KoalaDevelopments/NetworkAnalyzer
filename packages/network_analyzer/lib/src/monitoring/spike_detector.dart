import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';

/// Decides whether a sample is a latency spike.
///
/// A spike must clear two bars: a multiple of the window mean, and an
/// absolute margin above it. The multiplier alone would call a 3 ms to 7 ms
/// wobble on a fast link a spike, which is noise; the absolute floor
/// suppresses that without weakening detection on a slow link.
final class SpikeDetector {
  /// Creates a detector using [thresholds].
  SpikeDetector(this.thresholds);

  /// The cutoffs that define a spike.
  final HealthThresholds thresholds;

  /// Whether [sample] spikes above the mean of [previousSuccesses].
  ///
  /// Requires at least [HealthThresholds.minimumSamplesForVerdict] earlier
  /// successes, so the mean it is compared against means something.
  bool isSpike(ProbeSample sample, List<ProbeSample> previousSuccesses) {
    final Duration? latency = sample.roundTrip;
    if (latency == null ||
        previousSuccesses.length < thresholds.minimumSamplesForVerdict) {
      return false;
    }
    final int total = previousSuccesses.fold<int>(
      0,
      (int sum, ProbeSample each) => sum + each.roundTrip!.inMicroseconds,
    );
    final double mean = total / previousSuccesses.length;
    final double observed = latency.inMicroseconds.toDouble();
    final bool clearsMultiple = observed > mean * thresholds.spikeMultiplier;
    final bool clearsMargin =
        observed - mean >= thresholds.spikeMinDelta.inMicroseconds;
    return clearsMultiple && clearsMargin;
  }
}
