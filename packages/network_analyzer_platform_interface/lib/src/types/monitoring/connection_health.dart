/// An overall verdict on connection quality.
///
/// Derived from rolling latency, packet loss and jitter, each graded
/// independently against its thresholds; the worst of the three wins, so a
/// connection with perfect jitter and heavy loss is never called healthy.
enum ConnectionHealth {
  /// Measurements are steady and within expected ranges.
  stable,

  /// Occasional spikes or variation that may degrade performance.
  unstable,

  /// Very high latency or packet loss, or frequent drops, with severe
  /// impact.
  critical,

  /// Not enough information to judge.
  ///
  /// Reported before enough samples have been collected, or when the device
  /// has no network interface at all. A reachable network whose target never
  /// answers is [critical] rather than [unknown] — total loss on a live
  /// interface is measured information, not an absence of it.
  unknown,
}
