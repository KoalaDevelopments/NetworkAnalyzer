part of 'monitor_host.dart';

/// The public resolvers bundled with the plugin.
///
/// An enum rather than a set of constants so host applications get an
/// exhaustive `switch` and a ready-made list for building a picker.
enum PresetHost implements MonitorHost {
  /// Google Public DNS.
  google('Google Public DNS', '8.8.8.8', '8.8.4.4'),

  /// Cloudflare DNS.
  cloudflare('Cloudflare DNS', '1.1.1.1', '1.0.0.1'),

  /// OpenDNS.
  openDns('OpenDNS', '208.67.222.222', '208.67.220.220');

  const PresetHost(this.hostName, this.primaryIPv4, this.secondaryIPv4);

  @override
  final String hostName;

  @override
  final String primaryIPv4;

  @override
  final String secondaryIPv4;

  /// Always `null`: the bundled presets are addressed over IPv4.
  @override
  String? get ipv6 => null;

  /// Always 53: every bundled preset is a DNS resolver.
  @override
  int get port => 53;
}
