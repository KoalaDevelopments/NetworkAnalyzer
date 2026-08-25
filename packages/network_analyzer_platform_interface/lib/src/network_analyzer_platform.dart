import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart'
    show BridgeFailure;
import 'package:network_analyzer_platform_interface/src/core/result/result.dart';
import 'package:network_analyzer_platform_interface/src/failures/bridge_failure.dart'
    show BridgeFailure;
import 'package:network_analyzer_platform_interface/src/types/bridge_info.dart';
import 'package:network_analyzer_platform_interface/src/types/monitoring/monitor_interface.dart';
import 'package:network_analyzer_platform_interface/src/types/monitoring/monitor_signal.dart';
import 'package:network_analyzer_platform_interface/src/types/monitoring/session_data.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// The interface that platform implementations of `network_analyzer` must
/// extend.
///
/// Platform implementations must **extend** this class rather than
/// implement it. Extending guarantees that newly added members — which are
/// not breaking changes under the add-only contract (constitution,
/// Principle II) — fall back to the default [UnimplementedError] behavior
/// instead of failing to compile.
abstract class NetworkAnalyzerPlatform extends PlatformInterface {
  /// Constructs a [NetworkAnalyzerPlatform] and registers the verification
  /// token.
  NetworkAnalyzerPlatform() : super(token: _token);

  static final Object _token = Object();

  static NetworkAnalyzerPlatform _instance =
      _PlaceholderNetworkAnalyzerPlatform();

  /// The instance of [NetworkAnalyzerPlatform] in use.
  ///
  /// Defaults to a placeholder that throws [UnimplementedError] until a
  /// platform implementation registers itself via its `registerWith`
  /// entry point (`dartPluginClass`).
  static NetworkAnalyzerPlatform get instance => _instance;

  /// Sets the platform instance, verifying the extension token.
  static set instance(NetworkAnalyzerPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Reports the identity of the native side of the plugin.
  ///
  /// This is the bootstrap probe verifying the typed channel round-trip on
  /// each platform. Implementations return a [BridgeFailure] when the
  /// native call cannot complete.
  Future<Result<BridgeInfo, Failure>> getBridgeInfo() =>
      throw UnimplementedError('getBridgeInfo() has not been implemented.');

  /// Starts a monitoring session against [target].
  ///
  /// On success the returned [SessionData] describes the live session: the
  /// interface type, the device's address, the endpoint actually reached and
  /// when it started. At most one session may run at a time; a second call
  /// while one is live is rejected rather than allowed to disturb it.
  ///
  /// Implementations validate [target] again on their side and never trust
  /// the caller, and they never let a native exception escape.
  Future<Result<SessionData, Failure>> startMonitoring(
    MonitorInterface target,
  ) => throw UnimplementedError('startMonitoring() has not been implemented.');

  /// Stops the running session and halts all probing.
  ///
  /// Probing ceases within 500 ms. Calling this with no session running
  /// succeeds as a no-op, so callers never have to guard it.
  Future<Result<void, Failure>> stopMonitoring() =>
      throw UnimplementedError('stopMonitoring() has not been implemented.');

  /// The facts about the running session.
  ///
  /// Reports a failure when nothing is running rather than answering with a
  /// fabricated session.
  Future<Result<SessionData, Failure>> currentSession() =>
      throw UnimplementedError('currentSession() has not been implemented.');

  /// Raw probe results and network-state changes from the native side.
  ///
  /// This is the plugin's internal boundary: measurements a host application
  /// consumes are derived from this stream in Dart, once, so the two
  /// platforms cannot drift apart. Cancelling the last subscription stops
  /// native probing within 500 ms.
  Stream<MonitorSignal> monitorSignals() =>
      throw UnimplementedError('monitorSignals() has not been implemented.');
}

final class _PlaceholderNetworkAnalyzerPlatform
    extends NetworkAnalyzerPlatform {}
