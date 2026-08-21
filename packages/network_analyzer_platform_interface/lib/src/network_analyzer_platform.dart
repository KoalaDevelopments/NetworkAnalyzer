import 'package:network_analyzer_platform_interface/src/core/result/result.dart';
import 'package:network_analyzer_platform_interface/src/types/bridge_info.dart';
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
}

final class _PlaceholderNetworkAnalyzerPlatform
    extends NetworkAnalyzerPlatform {}
