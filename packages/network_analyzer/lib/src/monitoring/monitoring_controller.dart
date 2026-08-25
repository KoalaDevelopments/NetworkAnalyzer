import 'dart:async';

import 'package:network_analyzer/src/monitoring/event_synthesizer.dart';
import 'package:network_analyzer/src/monitoring/metrics_engine.dart';
import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';

/// Orchestrates one monitoring session.
///
/// Three responsibilities live here and nowhere else: enforcing that only one
/// session runs at a time, driving the metrics engine and the event
/// synthesizer from the platform's raw signals, and fanning the results out
/// to the three public streams.
///
/// The streams are views over a single internal source, so subscribing to any
/// combination changes no emitted value and starts no second session. When
/// the last subscriber across all three cancels, probing stops — a session
/// nobody is listening to has no reason to keep using the radio. That fires
/// only on a one-to-zero transition, so a session that has never been
/// subscribed to keeps running, as the specification requires.
final class MonitoringController {
  /// Creates a controller driving [platform].
  ///
  /// The platform is injected so the facade can be tested against a fake
  /// with no platform channel involved.
  MonitoringController({NetworkAnalyzerPlatform? platform})
    : _platform = platform ?? NetworkAnalyzerPlatform.instance {
    _trackedMetrics = _track(_metrics.stream);
    _trackedEvents = _track(_events.stream);
    _trackedUpdates = _track(_updates.stream);
  }

  final NetworkAnalyzerPlatform _platform;

  final StreamController<ConnectionMetrics> _metrics =
      StreamController<ConnectionMetrics>.broadcast();
  final StreamController<MonitorEvent> _events =
      StreamController<MonitorEvent>.broadcast();
  final StreamController<MonitorUpdate> _updates =
      StreamController<MonitorUpdate>.broadcast();

  StreamSubscription<MonitorSignal>? _signals;
  final List<StreamSubscription<Object?>> _trackers =
      <StreamSubscription<Object?>>[];
  MetricsEngine? _engine;
  EventSynthesizer? _synthesizer;
  SessionData? _session;
  int _subscribers = 0;
  bool _everSubscribed = false;

  late final Stream<ConnectionMetrics> _trackedMetrics;
  late final Stream<MonitorEvent> _trackedEvents;
  late final Stream<MonitorUpdate> _trackedUpdates;

  /// Measurements, one per completed probe.
  Stream<ConnectionMetrics> get metrics => _trackedMetrics;

  /// Notable moments in the session.
  Stream<MonitorEvent> get events => _trackedEvents;

  /// Measurements and events together, in production order.
  Stream<MonitorUpdate> get updates => _trackedUpdates;

  /// The running session, or [NoActiveSessionFailure] when idle.
  Result<SessionData, Failure> get currentSession {
    final SessionData? session = _session;
    if (session == null) {
      return const Result<SessionData, Failure>.failure(
        NoActiveSessionFailure(message: 'No monitoring session is running.'),
      );
    }
    return Result<SessionData, Failure>.success(session);
  }

  /// Starts a session against [target].
  ///
  /// Rejects the request with [SessionAlreadyRunningFailure] when a session
  /// is live, leaving that session untouched.
  Future<Result<SessionData, Failure>> start(MonitorInterface target) async {
    if (_session != null) {
      return const Result<SessionData, Failure>.failure(
        SessionAlreadyRunningFailure(
          message: 'A monitoring session is already running.',
        ),
      );
    }

    // Subscribe before starting so no sample can be lost in the gap between
    // the native side starting to probe and Dart starting to listen.
    final Stream<MonitorSignal> signals = _platform.monitorSignals();
    final StreamSubscription<MonitorSignal> subscription = signals.listen(
      _onSignal,
    );

    final Result<SessionData, Failure> result = await _platform.startMonitoring(
      target,
    );
    return result.fold(
      onFailure: (Failure failure) {
        unawaited(subscription.cancel());
        return Result<SessionData, Failure>.failure(failure);
      },
      onSuccess: (Success<SessionData> success) {
        final SessionData session = success.value;
        _signals = subscription;
        _session = session;
        _engine = MetricsEngine(
          session: session,
          options: target.options,
          thresholds: target.thresholds,
        );
        final EventSynthesizer synthesizer = EventSynthesizer(
          thresholds: target.thresholds,
        )..seed(session);
        _synthesizer = synthesizer;
        _emitEvent(synthesizer.started(session));
        return Result<SessionData, Failure>.success(session);
      },
    );
  }

  /// Stops the running session.
  ///
  /// A no-op when nothing is running, so callers never have to guard it.
  Future<Result<void, Failure>> stop() async {
    final SessionData? session = _session;
    final EventSynthesizer? synthesizer = _synthesizer;
    if (session != null && synthesizer != null) {
      _emitEvent(synthesizer.stopped(session));
    }
    await _signals?.cancel();
    _signals = null;
    _engine = null;
    _synthesizer = null;
    _session = null;
    if (session == null) {
      return const Result<void, Failure>.success(null);
    }
    return _platform.stopMonitoring();
  }

  /// Completes all three streams and releases the controller.
  ///
  /// The streams outlive an individual session on purpose. [stop] ends
  /// emission — nothing further is produced and probing halts — but closing
  /// the streams there would make the subscriber counting that [stop] itself
  /// depends on impossible, and would stop a host application from starting
  /// a second session on the same analyzer. Completion therefore belongs to
  /// dispose, which is the point at which the analyzer really is finished.
  Future<void> dispose() async {
    await stop();
    // Close the sources first so `onDone` propagates into each tracker;
    // cancelling the subscriptions first would strand the trackers open.
    await _metrics.close();
    await _events.close();
    await _updates.close();
    await Future<void>.delayed(Duration.zero);
    for (final StreamSubscription<Object?> tracker in _trackers) {
      await tracker.cancel();
    }
    _trackers.clear();
  }

  void _onSignal(MonitorSignal signal) {
    final MetricsEngine? engine = _engine;
    final EventSynthesizer? synthesizer = _synthesizer;
    if (engine == null || synthesizer == null) {
      return;
    }
    switch (signal) {
      case ProbeSample():
        final ConnectionMetrics measurement = engine.addSample(signal);
        _session = measurement.session;
        _emitMetrics(measurement);
        for (final MonitorEvent event in synthesizer.fromMetrics(
          measurement,
          wasSpike: engine.lastSampleWasSpike,
        )) {
          _emitEvent(event);
        }
      case NetworkStateChange():
        engine.applyNetworkChange(signal);
        _session = engine.session;
        for (final MonitorEvent event in synthesizer.fromNetworkChange(
          signal,
          engine.session,
        )) {
          _emitEvent(event);
        }
    }
  }

  void _emitMetrics(ConnectionMetrics measurement) {
    if (_metrics.isClosed) {
      return;
    }
    _metrics.add(measurement);
    _updates.add(MetricsUpdate(measurement));
  }

  void _emitEvent(MonitorEvent event) {
    if (_events.isClosed) {
      return;
    }
    _events.add(event);
    _updates.add(EventUpdate(event));
  }

  /// Wraps [source] so the controller can count live subscribers.
  ///
  /// Built once per stream in the constructor: a fresh wrapper per getter
  /// call would give every caller a private stream and make the subscriber
  /// count meaningless.
  Stream<T> _track<T>(Stream<T> source) {
    late final StreamController<T> tracker;
    bool attached = false;
    tracker = StreamController<T>.broadcast(
      onListen: () {
        _subscribers++;
        _everSubscribed = true;
        if (!attached) {
          attached = true;
          _trackers.add(
            source.listen(
              tracker.add,
              onError: tracker.addError,
              onDone: tracker.close,
            ),
          );
        }
      },
      onCancel: () {
        _subscribers--;
        if (_subscribers <= 0 && _everSubscribed) {
          unawaited(stop());
        }
      },
    );
    return tracker.stream;
  }
}
