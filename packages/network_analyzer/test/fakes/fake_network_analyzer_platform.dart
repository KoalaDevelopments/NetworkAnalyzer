import 'dart:async';

import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';

/// A platform implementation that replays a scripted signal list.
///
/// This is what keeps every Dart test off the network. The metrics engine is
/// a pure function of the signals it receives, so a fixed list here produces
/// exactly the measurements a real device would for the same probe results.
final class FakeNetworkAnalyzerPlatform extends NetworkAnalyzerPlatform {
  /// Creates a fake that answers [startMonitoring] with [session].
  ///
  /// Pass [startFailure] to make starting fail instead.
  FakeNetworkAnalyzerPlatform({SessionData? session, this.startFailure})
    : session = session ?? defaultSession();

  /// A plausible Wi-Fi session against Google Public DNS.
  static SessionData defaultSession() => SessionData(
    interfaceType: NetworkInterfaceType.wifi,
    protocol: MonitorProtocol.tcp,
    kind: MonitorKind.internet,
    deviceIpAddress: '192.168.1.42',
    targetAddress: '8.8.8.8',
    targetName: 'Google Public DNS',
    startedAt: DateTime.utc(2026, 8, 24, 12),
  );

  /// The session reported when starting succeeds.
  final SessionData session;

  /// The failure reported when starting should fail.
  final Failure? startFailure;

  /// How many times [startMonitoring] was called.
  int startCalls = 0;

  /// How many times [stopMonitoring] was called.
  int stopCalls = 0;

  /// Whether the signal stream currently has a subscriber.
  bool get isStreaming => _signals.hasListener;

  final StreamController<MonitorSignal> _signals =
      StreamController<MonitorSignal>.broadcast();

  bool _running = false;

  /// Pushes [signal] to whoever is listening.
  void emit(MonitorSignal signal) => _signals.add(signal);

  /// Pushes every signal in [signals], in order, letting the event loop turn
  /// between each so subscribers observe them one at a time.
  Future<void> emitAll(Iterable<MonitorSignal> signals) async {
    for (final MonitorSignal signal in signals) {
      _signals.add(signal);
      await Future<void>.delayed(Duration.zero);
    }
  }

  @override
  Future<Result<SessionData, Failure>> startMonitoring(
    MonitorInterface target,
  ) async {
    startCalls++;
    final Failure? failure = startFailure;
    if (failure != null) {
      return Result<SessionData, Failure>.failure(failure);
    }
    _running = true;
    return Result<SessionData, Failure>.success(session);
  }

  @override
  Future<Result<void, Failure>> stopMonitoring() async {
    stopCalls++;
    _running = false;
    return const Result<void, Failure>.success(null);
  }

  @override
  Future<Result<SessionData, Failure>> currentSession() async => _running
      ? Result<SessionData, Failure>.success(session)
      : const Result<SessionData, Failure>.failure(
          NoActiveSessionFailure(message: 'No monitoring session is running.'),
        );

  @override
  Stream<MonitorSignal> monitorSignals() => _signals.stream;

  /// Closes the signal stream.
  Future<void> dispose() => _signals.close();
}
