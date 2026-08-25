part of 'monitor_interface.dart';

/// Monitors the local network's default gateway.
///
/// No address is supplied: the plugin discovers the current network's
/// default route itself, so the host application never has to know or guess
/// the router's address.
///
/// **Designed for Wi-Fi and Ethernet, where the gateway is a local router
/// one hop away.** On cellular there is no local router: the discovered
/// address is the carrier's first hop, and most carriers silently drop
/// probes to it. A session started on cellular therefore tends to report
/// total loss and a critical verdict even though the connection itself is
/// healthy — an honest measurement of a gateway that refuses to answer, not
/// a connection problem. To judge a cellular connection, monitor the
/// internet with an [InternetInterface] instead.
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
