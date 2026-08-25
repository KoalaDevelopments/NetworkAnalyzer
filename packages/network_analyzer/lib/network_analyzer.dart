/// Network monitoring and analysis for mobile devices.
///
/// This is the app-facing package of the federated `network_analyzer`
/// plugin: the only package host applications depend on. It delegates to
/// the registered [NetworkAnalyzerPlatform] implementation
/// (`network_analyzer_android` / `network_analyzer_ios`), which are
/// endorsed by this package and wired automatically by the Flutter tool.
library;

import 'package:network_analyzer/src/monitoring/monitoring_controller.dart';
import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';

export 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart'
    show
        BridgeFailure,
        BridgeInfo,
        ConnectionHealth,
        ConnectionMetrics,
        CustomHost,
        EventUpdate,
        Failure,
        GatewayDiscoveryFailure,
        GatewayInterface,
        HealthThresholds,
        InternetInterface,
        InvalidConfigurationFailure,
        MetricsUpdate,
        MonitorEvent,
        MonitorEventKind,
        MonitorHost,
        MonitorInterface,
        MonitorKind,
        MonitorOptions,
        MonitorProtocol,
        MonitorSignal,
        MonitorUpdate,
        NetworkInterfaceType,
        NetworkStateChange,
        NoActiveSessionFailure,
        NotFailureException,
        NotSuccessException,
        PermissionFailure,
        PresetHost,
        ProbeOutcome,
        ProbeSample,
        ProbeTimeoutFailure,
        Result,
        ResultCallback,
        SessionAlreadyRunningFailure,
        SessionData,
        Success,
        TargetUnreachableFailure,
        UnsupportedCapabilityFailure,
        VoidSuccess;
export 'src/monitoring/monitoring_controller.dart' show MonitoringController;

/// The entry point for network monitoring and analysis.
///
/// All fallible operations return a [Result] and never throw
/// (constitution, Principle III).
///
/// ```dart
/// final analyzer = NetworkAnalyzer();
/// final result = await analyzer.startMonitoring(
///   InternetInterface(
///     protocol: MonitorProtocol.icmp,
///     host: PresetHost.cloudflare,
///   ),
/// );
/// analyzer.metrics.listen((m) => print('${m.latency} · ${m.health}'));
/// ```
class NetworkAnalyzer {
  /// Creates a [NetworkAnalyzer].
  ///
  /// [controller] is injectable so tests run against a fake platform with no
  /// channel involved. The constructor is not `const`: the analyzer holds
  /// the running session, which is what lets it reject a second start
  /// without reaching for global state.
  NetworkAnalyzer({MonitoringController? controller})
    : _controller = controller ?? MonitoringController();

  final MonitoringController _controller;

  /// Reports the identity of the native side of the plugin.
  ///
  /// Bootstrap probe verifying the typed Dart↔native round-trip. On
  /// success the [BridgeInfo] describes the platform that answered; on
  /// failure a [BridgeFailure] describes why the native call could not
  /// complete.
  Future<Result<BridgeInfo, Failure>> getBridgeInfo() =>
      NetworkAnalyzerPlatform.instance.getBridgeInfo();

  /// Starts monitoring [target] and describes the session that began.
  ///
  /// At most one session runs at a time. Starting while one is live returns
  /// a [SessionAlreadyRunningFailure] and leaves the running session
  /// untouched; switching between an internet and a gateway monitor means
  /// [stopMonitoring] then [startMonitoring].
  ///
  /// Fails with [PermissionFailure],
  /// [UnsupportedCapabilityFailure], [GatewayDiscoveryFailure],
  /// [InvalidConfigurationFailure] or [TargetUnreachableFailure] as the
  /// situation warrants. It never throws.
  Future<Result<SessionData, Failure>> startMonitoring(
    MonitorInterface target,
  ) => _controller.start(target);

  /// Stops the running session.
  ///
  /// Completes all three streams and halts probing within 500 ms. Calling
  /// this with nothing running succeeds as a no-op.
  Future<Result<void, Failure>> stopMonitoring() => _controller.stop();

  /// The facts about the running session.
  ///
  /// Returns a [NoActiveSessionFailure] when nothing is running, rather than
  /// a fabricated session. Synchronous because the analyzer already holds
  /// the answer.
  Result<SessionData, Failure> get currentSession => _controller.currentSession;

  /// Measurements, one per completed probe.
  ///
  /// Emission cadence equals the configured probe interval — one second
  /// unless [MonitorOptions] says otherwise.
  Stream<ConnectionMetrics> get metrics => _controller.metrics;

  /// Notable moments in the session, each timestamped in UTC.
  ///
  /// Transitions are always reported; ongoing conditions are throttled to
  /// one event per kind every 30 seconds so a persistent problem cannot
  /// flood the stream.
  Stream<MonitorEvent> get events => _controller.events;

  /// Measurements and events together, in the order they were produced.
  ///
  /// A view over the same source as [metrics] and [events]: subscribing to
  /// any combination changes no emitted value and starts no second session.
  Stream<MonitorUpdate> get updates => _controller.updates;

  /// Releases the streams. The analyzer cannot be reused afterwards.
  Future<void> dispose() => _controller.dispose();
}
