import 'package:meta/meta.dart';

/// The cutoffs that turn measurements into a health verdict.
///
/// Every field is optional and falls back to a documented default, so a host
/// application can start monitoring without supplying any of them. Override
/// only what a particular link needs: a satellite connection and a LAN
/// cannot share one definition of "stable".
///
/// Latency, packet loss and jitter are graded independently and the worst
/// grade wins. The defaults follow the widely used interactive-quality
/// bands: 100 ms and 250 ms round-trip latency, 1% and 5% packet loss, and
/// 30 ms and 50 ms jitter.
///
/// ```dart
/// HealthThresholds(stableLatency: Duration(milliseconds: 40));
/// ```
@immutable
final class HealthThresholds {
  /// Creates health thresholds, validating them against each other.
  ///
  /// Throws an [ArgumentError] when a stable cutoff is not strictly below
  /// its unstable counterpart, when a percentage falls outside 0 to 100,
  /// when [spikeMultiplier] is not above 1, or when
  /// [minimumSamplesForVerdict] is below 1.
  HealthThresholds({
    this.stableLatency = defaultStableLatency,
    this.unstableLatency = defaultUnstableLatency,
    this.stablePacketLossPercent = defaultStablePacketLossPercent,
    this.unstablePacketLossPercent = defaultUnstablePacketLossPercent,
    this.stableJitter = defaultStableJitter,
    this.unstableJitter = defaultUnstableJitter,
    this.spikeMultiplier = defaultSpikeMultiplier,
    this.spikeMinDelta = defaultSpikeMinDelta,
    this.minimumSamplesForVerdict = defaultMinimumSamplesForVerdict,
  }) {
    _validate();
  }

  /// Rolling mean latency at or below which a connection is stable.
  static const Duration defaultStableLatency = Duration(milliseconds: 100);

  /// Rolling mean latency at or below which a connection is unstable rather
  /// than critical.
  static const Duration defaultUnstableLatency = Duration(milliseconds: 250);

  /// Rolling packet loss at or below which a connection is stable.
  static const double defaultStablePacketLossPercent = 1;

  /// Rolling packet loss at or below which a connection is unstable rather
  /// than critical.
  static const double defaultUnstablePacketLossPercent = 5;

  /// Rolling jitter at or below which a connection is stable.
  static const Duration defaultStableJitter = Duration(milliseconds: 30);

  /// Rolling jitter at or below which a connection is unstable rather than
  /// critical.
  static const Duration defaultUnstableJitter = Duration(milliseconds: 50);

  /// How many times the rolling mean a sample must exceed to be a spike.
  static const double defaultSpikeMultiplier = 2;

  /// The absolute margin a spike must also clear.
  ///
  /// Without it, a 3 ms to 7 ms wobble on a fast link would register as a
  /// spike, which is noise rather than signal.
  static const Duration defaultSpikeMinDelta = Duration(milliseconds: 50);

  /// How many successful samples are needed before a verdict is possible.
  static const int defaultMinimumSamplesForVerdict = 3;

  /// Rolling mean latency at or below which the verdict is stable.
  final Duration stableLatency;

  /// Rolling mean latency at or below which the verdict is unstable.
  final Duration unstableLatency;

  /// Rolling packet loss percentage at or below which the verdict is stable.
  final double stablePacketLossPercent;

  /// Rolling packet loss percentage at or below which the verdict is
  /// unstable.
  final double unstablePacketLossPercent;

  /// Rolling jitter at or below which the verdict is stable.
  final Duration stableJitter;

  /// Rolling jitter at or below which the verdict is unstable.
  final Duration unstableJitter;

  /// The factor above the rolling mean that marks a latency spike.
  final double spikeMultiplier;

  /// The absolute margin above the rolling mean that a spike must clear.
  final Duration spikeMinDelta;

  /// How many successful samples are required before a verdict is given.
  final int minimumSamplesForVerdict;

  void _validate() {
    _requireBelow(stableLatency, unstableLatency, 'stableLatency');
    _requireBelow(stableJitter, unstableJitter, 'stableJitter');
    _requirePercent(stablePacketLossPercent, 'stablePacketLossPercent');
    _requirePercent(unstablePacketLossPercent, 'unstablePacketLossPercent');
    if (stablePacketLossPercent >= unstablePacketLossPercent) {
      throw ArgumentError.value(
        stablePacketLossPercent,
        'stablePacketLossPercent',
        'must be below unstablePacketLossPercent '
            '($unstablePacketLossPercent)',
      );
    }
    if (spikeMultiplier <= 1) {
      throw ArgumentError.value(
        spikeMultiplier,
        'spikeMultiplier',
        'must be greater than 1',
      );
    }
    if (spikeMinDelta.isNegative) {
      throw ArgumentError.value(
        spikeMinDelta,
        'spikeMinDelta',
        'must not be negative',
      );
    }
    if (minimumSamplesForVerdict < 1) {
      throw ArgumentError.value(
        minimumSamplesForVerdict,
        'minimumSamplesForVerdict',
        'must be at least 1',
      );
    }
  }

  static void _requireBelow(Duration stable, Duration unstable, String name) {
    if (stable >= unstable) {
      throw ArgumentError.value(
        stable,
        name,
        'must be below its unstable counterpart ($unstable)',
      );
    }
  }

  static void _requirePercent(double value, String name) {
    if (value < 0 || value > 100) {
      throw ArgumentError.value(value, name, 'must be between 0 and 100');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is HealthThresholds &&
      other.stableLatency == stableLatency &&
      other.unstableLatency == unstableLatency &&
      other.stablePacketLossPercent == stablePacketLossPercent &&
      other.unstablePacketLossPercent == unstablePacketLossPercent &&
      other.stableJitter == stableJitter &&
      other.unstableJitter == unstableJitter &&
      other.spikeMultiplier == spikeMultiplier &&
      other.spikeMinDelta == spikeMinDelta &&
      other.minimumSamplesForVerdict == minimumSamplesForVerdict;

  @override
  int get hashCode => Object.hash(
    stableLatency,
    unstableLatency,
    stablePacketLossPercent,
    unstablePacketLossPercent,
    stableJitter,
    unstableJitter,
    spikeMultiplier,
    spikeMinDelta,
    minimumSamplesForVerdict,
  );
}
