import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';

void main() {
  group('InternetInterface', () {
    test('reports the internet kind and defaults its tuning', () {
      final InternetInterface target = InternetInterface(
        protocol: MonitorProtocol.tcp,
        host: PresetHost.google,
      );
      check(target.kind).equals(MonitorKind.internet);
      check(target.options).equals(MonitorOptions());
      check(target.thresholds).equals(HealthThresholds());
    });

    test('accepts every protocol', () {
      for (final MonitorProtocol protocol in MonitorProtocol.values) {
        check(
          InternetInterface(protocol: protocol, host: PresetHost.google).kind,
        ).equals(MonitorKind.internet);
      }
    });

    test('carries supplied tuning', () {
      final InternetInterface target = InternetInterface(
        protocol: MonitorProtocol.icmp,
        host: PresetHost.cloudflare,
        options: MonitorOptions(sampleWindowSize: 20),
        thresholds: HealthThresholds(
          stableLatency: const Duration(milliseconds: 40),
        ),
      );
      check(target.options.sampleWindowSize).equals(20);
      check(
        target.thresholds.stableLatency,
      ).equals(const Duration(milliseconds: 40));
    });
  });

  group('GatewayInterface', () {
    test('reports the gateway kind', () {
      final GatewayInterface target = GatewayInterface(
        protocol: MonitorProtocol.tcp,
      );
      check(target.kind).equals(MonitorKind.gateway);
    });

    test('accepts TCP and ICMP', () {
      check(
        GatewayInterface(protocol: MonitorProtocol.tcp).protocol,
      ).equals(MonitorProtocol.tcp);
      check(
        GatewayInterface(protocol: MonitorProtocol.icmp).protocol,
      ).equals(MonitorProtocol.icmp);
    });

    test('rejects UDP', () {
      check(
        () => GatewayInterface(protocol: MonitorProtocol.udp),
      ).throws<ArgumentError>();
    });
  });

  group('MonitorInterface', () {
    test('is sealed, so a switch over it is exhaustive', () {
      final List<MonitorInterface> targets = <MonitorInterface>[
        InternetInterface(
          protocol: MonitorProtocol.tcp,
          host: PresetHost.google,
        ),
        GatewayInterface(protocol: MonitorProtocol.icmp),
      ];
      final List<String> described = targets
          .map(
            (MonitorInterface target) => switch (target) {
              InternetInterface(:final MonitorHost host) => host.hostName,
              GatewayInterface() => 'Gateway',
            },
          )
          .toList();
      check(described).deepEquals(<String>['Google Public DNS', 'Gateway']);
    });
  });
}
