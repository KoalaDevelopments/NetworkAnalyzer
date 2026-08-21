/// Network monitoring and analysis for mobile devices.
///
/// This is the app-facing package of the federated `network_analyzer`
/// plugin: the only package host applications depend on. It delegates to
/// the registered [NetworkAnalyzerPlatform] implementation
/// (`network_analyzer_android` / `network_analyzer_ios`), which are
/// endorsed by this package and wired automatically by the Flutter tool.
library;

import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';

export 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart'
    show
        BridgeFailure,
        BridgeInfo,
        Failure,
        NotFailureException,
        NotSuccessException,
        Result,
        ResultCallback,
        Success,
        VoidSuccess;

/// The entry point for network monitoring and analysis.
///
/// All fallible operations return a [Result] and never throw
/// (constitution, Principle III).
class NetworkAnalyzer {
  /// Creates a [NetworkAnalyzer].
  const NetworkAnalyzer();

  /// Reports the identity of the native side of the plugin.
  ///
  /// Bootstrap probe verifying the typed Dart↔native round-trip. On
  /// success the [BridgeInfo] describes the platform that answered; on
  /// failure a [BridgeFailure] describes why the native call could not
  /// complete.
  Future<Result<BridgeInfo, Failure>> getBridgeInfo() =>
      NetworkAnalyzerPlatform.instance.getBridgeInfo();
}
