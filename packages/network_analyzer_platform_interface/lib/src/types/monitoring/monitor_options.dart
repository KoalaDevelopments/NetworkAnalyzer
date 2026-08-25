import 'package:meta/meta.dart';

/// Tuning for how often a session probes and how much history it weighs.
///
/// Every field is optional. Supplying nothing yields the documented
/// defaults — a one second probe interval, a one second probe timeout and a
/// ten sample window — so a host application can start monitoring without
/// deciding any of them.
///
/// The timeout is capped at the interval so at most one probe is ever in
/// flight, which keeps sequence numbering and loss accounting exact.
///
/// ```dart
/// const MonitorOptions(
///   probeInterval: Duration(milliseconds: 500),
///   sampleWindowSize: 20,
/// );
/// ```
@immutable
final class MonitorOptions {
  /// Creates monitor options, validating them against the documented bounds.
  ///
  /// Throws an [ArgumentError] when a value falls outside its bounds or when
  /// [probeTimeout] exceeds [probeInterval]. Out-of-range tuning is a
  /// programming error in host code, so it surfaces immediately rather than
  /// as a failure much later.
  MonitorOptions({
    this.probeInterval = defaultProbeInterval,
    this.probeTimeout = defaultProbeTimeout,
    this.sampleWindowSize = defaultSampleWindowSize,
  }) {
    _validate();
  }

  /// The probe interval applied when none is supplied.
  static const Duration defaultProbeInterval = Duration(seconds: 1);

  /// The probe timeout applied when none is supplied.
  static const Duration defaultProbeTimeout = Duration(seconds: 1);

  /// The rolling sample window size applied when none is supplied.
  static const int defaultSampleWindowSize = 10;

  /// The shortest permitted probe interval.
  static const Duration minProbeInterval = Duration(milliseconds: 200);

  /// The longest permitted probe interval.
  static const Duration maxProbeInterval = Duration(seconds: 60);

  /// The shortest permitted probe timeout.
  static const Duration minProbeTimeout = Duration(milliseconds: 100);

  /// The smallest permitted rolling sample window.
  static const int minSampleWindowSize = 1;

  /// The largest permitted rolling sample window.
  ///
  /// Caps how many samples a session retains, which is what bounds memory
  /// on a session running for days.
  static const int maxSampleWindowSize = 300;

  /// How often a probe is sent, and therefore how often a measurement is
  /// emitted.
  final Duration probeInterval;

  /// How long a single probe may take before it counts as lost.
  final Duration probeTimeout;

  /// How many recent samples packet loss and jitter are computed over.
  final int sampleWindowSize;

  void _validate() {
    if (probeInterval < minProbeInterval || probeInterval > maxProbeInterval) {
      throw ArgumentError.value(
        probeInterval,
        'probeInterval',
        'must be between $minProbeInterval and $maxProbeInterval',
      );
    }
    if (probeTimeout < minProbeTimeout) {
      throw ArgumentError.value(
        probeTimeout,
        'probeTimeout',
        'must be at least $minProbeTimeout',
      );
    }
    if (probeTimeout > probeInterval) {
      throw ArgumentError.value(
        probeTimeout,
        'probeTimeout',
        'must not exceed probeInterval ($probeInterval)',
      );
    }
    if (sampleWindowSize < minSampleWindowSize ||
        sampleWindowSize > maxSampleWindowSize) {
      throw ArgumentError.value(
        sampleWindowSize,
        'sampleWindowSize',
        'must be between $minSampleWindowSize and $maxSampleWindowSize',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is MonitorOptions &&
      other.probeInterval == probeInterval &&
      other.probeTimeout == probeTimeout &&
      other.sampleWindowSize == sampleWindowSize;

  @override
  int get hashCode => Object.hash(
    probeInterval,
    probeTimeout,
    sampleWindowSize,
  );

  @override
  String toString() =>
      'MonitorOptions(interval: $probeInterval, timeout: $probeTimeout, '
      'window: $sampleWindowSize)';
}
