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
export 'src/failures/monitoring_failures.dart';
export 'src/network_analyzer_platform.dart';
export 'src/types/bridge_info.dart';
export 'src/types/monitoring/connection_health.dart';
export 'src/types/monitoring/connection_metrics.dart';
export 'src/types/monitoring/health_thresholds.dart';
export 'src/types/monitoring/monitor_event.dart';
export 'src/types/monitoring/monitor_host.dart';
export 'src/types/monitoring/monitor_interface.dart';
export 'src/types/monitoring/monitor_kind.dart';
export 'src/types/monitoring/monitor_options.dart';
export 'src/types/monitoring/monitor_protocol.dart';
export 'src/types/monitoring/monitor_signal.dart';
export 'src/types/monitoring/monitor_update.dart';
export 'src/types/monitoring/network_interface_type.dart';
export 'src/types/monitoring/session_data.dart';
