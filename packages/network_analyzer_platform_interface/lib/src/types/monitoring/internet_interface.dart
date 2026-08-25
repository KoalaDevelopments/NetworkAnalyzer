part of 'monitor_interface.dart';

/// Monitors the public internet through a chosen target.
///
/// ```dart
/// InternetInterface(
///   protocol: MonitorProtocol.tcp,
///   host: PresetHost.cloudflare,
/// );
/// ```
@immutable
final class InternetInterface extends MonitorInterface {
  /// Creates an internet monitor aimed at [host].
  ///
  /// All three protocols are accepted. Tuning is optional: omitting
  /// [options] or [thresholds] applies the documented defaults.
  InternetInterface({
    required super.protocol,
    required this.host,
    super.options,
    super.thresholds,
  }) : super._();

  /// Where probes are sent.
  final MonitorHost host;

  @override
  MonitorKind get kind => MonitorKind.internet;

  @override
  bool operator ==(Object other) =>
      other is InternetInterface &&
      other.protocol == protocol &&
      other.host == host &&
      other.options == options &&
      other.thresholds == thresholds;

  @override
  int get hashCode => Object.hash(protocol, host, options, thresholds);

  @override
  String toString() =>
      'InternetInterface(${protocol.name} to ${host.hostName})';
}
