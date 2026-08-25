part of 'monitor_host.dart';

/// A monitoring target defined by the host application.
///
/// Use this to point monitoring at infrastructure the bundled presets do not
/// cover — a corporate resolver, an edge node, a service the application
/// actually depends on.
///
/// ```dart
/// CustomHost(hostName: 'Corporate resolver', primaryIPv4: '10.0.0.53');
/// ```
@immutable
final class CustomHost extends MonitorHost {
  /// Creates a custom target.
  ///
  /// Throws an [ArgumentError] when [hostName] is blank, when
  /// [primaryIPv4] is not a valid IPv4 address, when [ipv6] is supplied and
  /// is not a valid IPv6 address, or when [port] falls outside 1 to 65535.
  CustomHost({
    required this.hostName,
    required this.primaryIPv4,
    this.ipv6,
    this.port = 53,
  }) : super._() {
    if (hostName.trim().isEmpty) {
      throw ArgumentError.value(hostName, 'hostName', 'must not be blank');
    }
    requireIPv4(primaryIPv4, 'primaryIPv4');
    final String? v6 = ipv6;
    if (v6 != null) {
      requireIPv6(v6, 'ipv6');
    }
    requirePort(port, 'port');
  }

  @override
  final String hostName;

  @override
  final String primaryIPv4;

  @override
  final String? ipv6;

  @override
  final int port;

  /// Always `null`: a custom target defines a single address.
  @override
  String? get secondaryIPv4 => null;

  @override
  bool operator ==(Object other) =>
      other is CustomHost &&
      other.hostName == hostName &&
      other.primaryIPv4 == primaryIPv4 &&
      other.ipv6 == ipv6 &&
      other.port == port;

  @override
  int get hashCode => Object.hash(hostName, primaryIPv4, ipv6, port);

  @override
  String toString() => 'CustomHost($hostName, $primaryIPv4:$port)';
}
