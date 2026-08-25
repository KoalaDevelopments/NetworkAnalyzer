import 'package:network_analyzer/src/monitoring/health_evaluator.dart';
import 'package:network_analyzer/src/monitoring/jitter_calculator.dart';
import 'package:network_analyzer/src/monitoring/rolling_window.dart';
import 'package:network_analyzer/src/monitoring/rounding.dart';
import 'package:network_analyzer/src/monitoring/spike_detector.dart';
import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';

/// Turns raw probe samples into measurements.
///
/// This is the whole reason native code stays simple. Every derived value —
/// rolling loss, jitter, spike detection, the health verdict, the session
/// aggregates — is computed here, once, in Dart. Android and iOS therefore
/// cannot drift apart on any of them, and every rule is testable against a
/// fixed sample sequence without touching a network.
///
/// The engine is a pure accumulator: feed it signals in order and it yields
/// the same measurements every time.
final class MetricsEngine {
  /// Creates an engine for a session described by [session].
  MetricsEngine({
    required SessionData session,
    required this.options,
    required this.thresholds,
  }) : _session = session,
       _window = RollingWindow(options.sampleWindowSize),
       _evaluator = HealthEvaluator(thresholds),
       _spikes = SpikeDetector(thresholds);

  /// The session's tuning.
  final MonitorOptions options;

  /// The session's health cutoffs.
  final HealthThresholds thresholds;

  final RollingWindow _window;
  final HealthEvaluator _evaluator;
  final SpikeDetector _spikes;

  SessionData _session;
  int _spikeCount = 0;
  int _successCount = 0;
  int _latencyTotalMicros = 0;
  int? _lowestMicros;
  int? _highestMicros;
  Duration _uptime = Duration.zero;
  ConnectionHealth _health = ConnectionHealth.unknown;

  /// The session's facts as they currently stand.
  SessionData get session => _session;

  /// The most recent health verdict.
  ConnectionHealth get health => _health;

  /// How many samples the window is holding.
  ///
  /// Exposed so a test can assert that a long session retains no more than
  /// the configured window, rather than growing without bound.
  int get retainedSamples => _window.length;

  /// Whether the most recent spike detection fired.
  bool get lastSampleWasSpike => _lastSampleWasSpike;
  bool _lastSampleWasSpike = false;

  /// Folds [change] into the session's facts.
  ///
  /// Later measurements then report the truth rather than what was true when
  /// the session started.
  void applyNetworkChange(NetworkStateChange change) {
    _session = _session.copyWith(
      interfaceType: change.interfaceType,
      deviceIpAddress: change.deviceIpAddress,
      targetAddress: change.targetAddress,
    );
  }

  /// Folds [sample] in and returns the resulting measurement.
  ConnectionMetrics addSample(ProbeSample sample) {
    _lastSampleWasSpike = _spikes.isSpike(sample, _window.successes);
    if (_lastSampleWasSpike) {
      _spikeCount++;
    }

    _window.add(sample);
    _uptime = sample.sinceSessionStart;

    final Duration? latency = sample.roundTrip;
    if (latency != null) {
      final int micros = latency.inMicroseconds;
      _successCount++;
      _latencyTotalMicros += micros;
      _lowestMicros = _lowestMicros == null
          ? micros
          : (micros < _lowestMicros! ? micros : _lowestMicros);
      _highestMicros = _highestMicros == null
          ? micros
          : (micros > _highestMicros! ? micros : _highestMicros);
    }

    final List<ProbeSample> successes = _window.successes;
    final Duration? jitter = calculateJitter(successes);
    final double loss = _window.packetLossPercent;
    _health = _evaluator.evaluate(
      successfulSamples: successes.length,
      packetLossPercent: loss,
      interfaceType: _session.interfaceType,
      meanLatency: _window.meanLatency,
      jitter: jitter,
    );

    return ConnectionMetrics(
      session: _session,
      latency: latency == null ? null : roundToTenthMilli(latency),
      packetLossPercent: roundToTenth(loss),
      jitter: jitter == null ? null : roundToTenthMilli(jitter),
      spikeCount: _spikeCount,
      health: _health,
      uptime: _uptime,
      averageLatency: _successCount == 0
          ? null
          : roundToTenthMilli(
              Duration(microseconds: _latencyTotalMicros ~/ _successCount),
            ),
      lowestLatency: _lowestMicros == null
          ? null
          : roundToTenthMilli(Duration(microseconds: _lowestMicros!)),
      highestLatency: _highestMicros == null
          ? null
          : roundToTenthMilli(Duration(microseconds: _highestMicros!)),
    );
  }
}
