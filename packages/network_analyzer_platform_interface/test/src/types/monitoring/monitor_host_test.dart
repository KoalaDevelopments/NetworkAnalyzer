import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';

void main() {
  group('PresetHost', () {
    test('exposes the documented provider addresses', () {
      check(PresetHost.google.primaryIPv4).equals('8.8.8.8');
      check(PresetHost.google.secondaryIPv4).equals('8.8.4.4');
      check(PresetHost.cloudflare.primaryIPv4).equals('1.1.1.1');
      check(PresetHost.cloudflare.secondaryIPv4).equals('1.0.0.1');
      check(PresetHost.openDns.primaryIPv4).equals('208.67.222.222');
      check(PresetHost.openDns.secondaryIPv4).equals('208.67.220.220');
    });

    test('every preset has a display name and the DNS port', () {
      for (final PresetHost preset in PresetHost.values) {
        check(preset.hostName).isNotEmpty();
        check(preset.port).equals(53);
      }
    });

    test('is a MonitorHost so it can be used wherever one is required', () {
      check(PresetHost.google).isA<MonitorHost>();
    });
  });

  group('CustomHost', () {
    test('requires only a host name and an IPv4 address', () {
      final CustomHost host = CustomHost(
        hostName: 'Corporate resolver',
        primaryIPv4: '10.0.0.53',
      );
      check(host.primaryIPv4).equals('10.0.0.53');
      check(host.secondaryIPv4).isNull();
      check(host.ipv6).isNull();
      check(host.port).equals(53);
    });

    test('accepts an optional IPv6 address and a custom port', () {
      final CustomHost host = CustomHost(
        hostName: 'Corporate resolver',
        primaryIPv4: '10.0.0.53',
        ipv6: '2001:4860:4860::8888',
        port: 443,
      );
      check(host.ipv6).equals('2001:4860:4860::8888');
      check(host.port).equals(443);
    });

    test('rejects an empty host name', () {
      check(
        () => CustomHost(hostName: '   ', primaryIPv4: '10.0.0.53'),
      ).throws<ArgumentError>();
    });

    test('rejects a malformed IPv4 address', () {
      for (final String bad in <String>[
        '',
        '10.0.0',
        '10.0.0.256',
        '10.0.0.1.1',
        'not-an-address',
        '2001:db8::1',
      ]) {
        check(
          () => CustomHost(hostName: 'x', primaryIPv4: bad),
          because: 'expected $bad to be rejected',
        ).throws<ArgumentError>();
      }
    });

    test('rejects a malformed IPv6 address', () {
      check(
        () => CustomHost(
          hostName: 'x',
          primaryIPv4: '10.0.0.53',
          ipv6: 'nope',
        ),
      ).throws<ArgumentError>();
    });

    test('rejects a port outside 1..65535', () {
      check(
        () => CustomHost(hostName: 'x', primaryIPv4: '10.0.0.53', port: 0),
      ).throws<ArgumentError>();
      check(
        () => CustomHost(hostName: 'x', primaryIPv4: '10.0.0.53', port: 65536),
      ).throws<ArgumentError>();
    });

    test('equal values are equal and share a hash code', () {
      final CustomHost a = CustomHost(hostName: 'x', primaryIPv4: '10.0.0.53');
      final CustomHost b = CustomHost(hostName: 'x', primaryIPv4: '10.0.0.53');
      check(a).equals(b);
      check(a.hashCode).equals(b.hashCode);
    });
  });
}
