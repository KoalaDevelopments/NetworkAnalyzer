import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';

/// Turns rolling measurements into a health verdict.
///
/// Latency, packet loss and jitter are graded independently and the **worst**
/// grade wins. Averaging them would let one excellent input mask one terrible
/// one: a connection with 0 ms jitter and 20% packet loss is not healthy, and
/// hiding that is the opposite of what this plugin exists to do.
final class HealthEvaluator {
  /// Creates an evaluator using [thresholds].
  const HealthEvaluator(this.thresholds);

  /// The cutoffs that separate the levels.
  final HealthThresholds thresholds;

  /// The verdict for the current window.
  ///
  /// Returns [ConnectionHealth.unknown] in exactly two situations: too few
  /// successful samples to judge, or no network interface at all. A live
  /// interface whose target never answers is [ConnectionHealth.critical] —
  /// 100% loss on a working network is measured information, not an absence
  /// of it.
  ConnectionHealth evaluate({
    required int successfulSamples,
    required double packetLossPercent,
    required NetworkInterfaceType interfaceType,
    Duration? meanLatency,
    Duration? jitter,
  }) {
    if (!interfaceType.isConnected) {
      return ConnectionHealth.unknown;
    }
    if (successfulSamples == 0 && packetLossPercent >= 100) {
      return ConnectionHealth.critical;
    }
    if (successfulSamples < thresholds.minimumSamplesForVerdict) {
      return ConnectionHealth.unknown;
    }

    return <ConnectionHealth>[
      _gradeLoss(packetLossPercent),
      if (meanLatency != null) _gradeLatency(meanLatency),
      if (jitter != null) _gradeJitter(jitter),
    ].reduce(_worst);
  }

  ConnectionHealth _gradeLoss(double percent) {
    if (percent <= thresholds.stablePacketLossPercent) {
      return ConnectionHealth.stable;
    }
    if (percent <= thresholds.unstablePacketLossPercent) {
      return ConnectionHealth.unstable;
    }
    return ConnectionHealth.critical;
  }

  ConnectionHealth _gradeLatency(Duration latency) {
    if (latency <= thresholds.stableLatency) {
      return ConnectionHealth.stable;
    }
    if (latency <= thresholds.unstableLatency) {
      return ConnectionHealth.unstable;
    }
    return ConnectionHealth.critical;
  }

  ConnectionHealth _gradeJitter(Duration jitter) {
    if (jitter <= thresholds.stableJitter) {
      return ConnectionHealth.stable;
    }
    if (jitter <= thresholds.unstableJitter) {
      return ConnectionHealth.unstable;
    }
    return ConnectionHealth.critical;
  }

  static ConnectionHealth _worst(ConnectionHealth a, ConnectionHealth b) =>
      _severity(a) >= _severity(b) ? a : b;

  static int _severity(ConnectionHealth health) => switch (health) {
    ConnectionHealth.stable => 0,
    ConnectionHealth.unstable => 1,
    ConnectionHealth.critical => 2,
    ConnectionHealth.unknown => 3,
  };
}
