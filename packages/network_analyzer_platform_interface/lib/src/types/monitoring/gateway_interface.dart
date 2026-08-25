part of 'monitor_interface.dart';

/// Monitors the local network's default gateway.
///
/// No address is supplied: the plugin discovers the current network's
/// default route itself, so the host application never has to know or guess
/// the router's address.
///
/// ```dart
/// GatewayInterface(protocol: MonitorProtocol.icmp);
/// ```
@immutable
final class GatewayInterface extends MonitorInterface {
  /// Creates a gateway monitor.
  ///
  /// Throws an [ArgumentError] when [protocol] is [MonitorProtocol.udp]: a
  /// gateway does not answer datagrams predictably, so accepting UDP here
  /// would promise a measurement that cannot be trusted.
  GatewayInterface({
    required super.protocol,
    super.options,
    super.thresholds,
  }) : super._() {
    if (protocol == MonitorProtocol.udp) {
      throw ArgumentError.value(
        protocol,
        'protocol',
        'a gateway monitor accepts only TCP and ICMP',
      );
    }
  }

  @override
  MonitorKind get kind => MonitorKind.gateway;

  @override
  bool operator ==(Object other) =>
      other is GatewayInterface &&
      other.protocol == protocol &&
      other.options == options &&
      other.thresholds == thresholds;

  @override
  int get hashCode => Object.hash(protocol, options, thresholds);

  @override
  String toString() => 'GatewayInterface(${protocol.name})';
}
