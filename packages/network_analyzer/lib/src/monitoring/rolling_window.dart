import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';

/// A fixed-capacity view of the most recent probe samples.
///
/// Packet loss, jitter and the health verdict are computed over this window
/// rather than the whole session, which is what lets them recover once
/// conditions improve. Capacity is what bounds memory: a session running for
/// days holds this many samples and no more.
final class RollingWindow {
  /// Creates a window holding at most [capacity] samples.
  RollingWindow(this.capacity)
    : assert(capacity > 0, 'capacity must be positive');

  /// How many samples the window holds before evicting the oldest.
  final int capacity;

  final List<ProbeSample> _samples = <ProbeSample>[];

  /// The samples currently held, oldest first.
  List<ProbeSample> get samples => List<ProbeSample>.unmodifiable(_samples);

  /// The successful samples currently held, oldest first.
  List<ProbeSample> get successes =>
      _samples.where((ProbeSample sample) => sample.isSuccess).toList();

  /// How many samples are held.
  int get length => _samples.length;

  /// Adds [sample], evicting the oldest when the window is full.
  void add(ProbeSample sample) {
    _samples.add(sample);
    if (_samples.length > capacity) {
      _samples.removeAt(0);
    }
  }

  /// Percentage of probes in the window that did not succeed.
  ///
  /// Zero for an empty window: no probe has been lost, because none has been
  /// sent.
  double get packetLossPercent {
    if (_samples.isEmpty) {
      return 0;
    }
    final int lost = _samples.length - successes.length;
    return lost * 100 / _samples.length;
  }

  /// Mean round-trip time across the window's successful samples.
  ///
  /// `null` when none have succeeded.
  Duration? get meanLatency {
    final List<ProbeSample> hits = successes;
    if (hits.isEmpty) {
      return null;
    }
    final int total = hits.fold<int>(
      0,
      (int sum, ProbeSample sample) => sum + sample.roundTrip!.inMicroseconds,
    );
    return Duration(microseconds: total ~/ hits.length);
  }
}
