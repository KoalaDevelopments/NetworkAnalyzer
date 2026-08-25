/// The target an internet monitor probes.
library;

import 'package:meta/meta.dart';
import 'package:network_analyzer_platform_interface/src/types/monitoring/ip_validation.dart';

part 'custom_host.dart';
part 'preset_host.dart';

/// Where an internet monitor sends its probes.
///
/// Either one of the bundled [PresetHost] providers, so a host application
/// never hard-codes an address, or a [CustomHost] it defines itself.
///
/// ```dart
/// InternetInterface(protocol: MonitorProtocol.icmp, host: PresetHost.google);
/// ```
sealed class MonitorHost {
  const MonitorHost._();

  /// A display name for the target, suitable for showing to a user.
  String get hostName;

  /// The address probes are sent to first.
  String get primaryIPv4;

  /// An alternative address to fall back to, when the target offers one.
  ///
  /// A session switches to it after three consecutive failed probes and does
  /// not switch back, so a marginal link cannot flap between two addresses
  /// and corrupt the latency aggregates.
  String? get secondaryIPv4;

  /// An optional IPv6 address.
  ///
  /// Carried and exposed, but not probed in this version: probing is IPv4
  /// only, and an ICMP session on an IPv6-only network reports an
  /// unsupported-capability failure rather than pretending to work.
  String? get ipv6;

  /// The port TCP and UDP probes connect to.
  int get port;
}
