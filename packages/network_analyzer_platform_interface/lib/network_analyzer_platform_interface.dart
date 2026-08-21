/// The platform contract and shared types for the network_analyzer
/// federated plugin.
///
/// Platform implementations extend [NetworkAnalyzerPlatform]; host
/// applications never depend on this package directly — they use the
/// app-facing `network_analyzer` package, which re-exports the public
/// types defined here.
library;

import 'network_analyzer_platform_interface.dart';

export 'src/core/result/result.dart';
export 'src/failures/bridge_failure.dart';
export 'src/network_analyzer_platform.dart';
export 'src/types/bridge_info.dart';
