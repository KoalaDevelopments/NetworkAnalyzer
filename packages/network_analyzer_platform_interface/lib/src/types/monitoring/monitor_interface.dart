/// What a monitoring session watches, and how.
library;

import 'package:meta/meta.dart';
import 'package:network_analyzer_platform_interface/src/types/monitoring/health_thresholds.dart';
import 'package:network_analyzer_platform_interface/src/types/monitoring/monitor_host.dart';
import 'package:network_analyzer_platform_interface/src/types/monitoring/monitor_kind.dart';
import 'package:network_analyzer_platform_interface/src/types/monitoring/monitor_options.dart';
import 'package:network_analyzer_platform_interface/src/types/monitoring/monitor_protocol.dart';

part 'gateway_interface.dart';
part 'internet_interface.dart';

/// A description of what to monitor, built by the host application.
///
/// Exactly two kinds exist: an [InternetInterface] reaching a chosen target
/// over the public internet, and a [GatewayInterface] reaching the local
/// network's default gateway, whose address is discovered automatically.
/// Together they answer the question a user actually asks when something
/// feels slow — is it my router, or is it the internet?
///
/// Instances are immutable. Changing what is monitored means building a new
/// one and starting a new session.
sealed class MonitorInterface {
  MonitorInterface._({
    required this.protocol,
    MonitorOptions? options,
    HealthThresholds? thresholds,
  }) : options = options ?? MonitorOptions(),
       thresholds = thresholds ?? HealthThresholds();

  /// How probes are sent.
  final MonitorProtocol protocol;

  /// How often to probe and how much history to weigh.
  final MonitorOptions options;

  /// The cutoffs that turn measurements into a health verdict.
  final HealthThresholds thresholds;

  /// Which kind of monitor this is.
  MonitorKind get kind;
}
