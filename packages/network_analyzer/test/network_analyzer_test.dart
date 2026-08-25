import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_analyzer/network_analyzer.dart';

import 'fakes/fake_network_analyzer_platform.dart';
import 'src/monitoring/fixtures.dart';

void main() {
  group('NetworkAnalyzer monitoring', () {
    late FakeNetworkAnalyzerPlatform platform;
    late NetworkAnalyzer analyzer;

    setUp(() {
      platform = FakeNetworkAnalyzerPlatform();
      analyzer = NetworkAnalyzer(
        controller: MonitoringController(platform: platform),
      );
    });

    tearDown(() async {
      await analyzer.dispose();
      await platform.dispose();
    });

    test('starting returns the facts about the session', () async {
      final Result<SessionData, Failure> result = await analyzer
          .startMonitoring(
            InternetInterface(
              protocol: MonitorProtocol.tcp,
              host: PresetHost.google,
            ),
          );

      check(result.isSuccess).isTrue();
      final SessionData session = result.success.value;
      check(session.interfaceType).equals(NetworkInterfaceType.wifi);
      check(session.deviceIpAddress).equals('192.168.1.42');
      check(session.targetAddress).equals('8.8.8.8');
      check(session.kind).equals(MonitorKind.internet);
      check(session.startedAt.isUtc).isTrue();
    });

    test('a preset session needs no address and no tuning', () async {
      // Five statements, no IP address, no interval, no window, no
      // threshold — the whole point of the presets and the defaults.
      final NetworkAnalyzer local = NetworkAnalyzer(
        controller: MonitoringController(platform: platform),
      );
      final Result<SessionData, Failure> result = await local.startMonitoring(
        InternetInterface(
          protocol: MonitorProtocol.tcp,
          host: PresetHost.cloudflare,
        ),
      );

      check(result.isSuccess).isTrue();
      await local.dispose();
    });

    test('every preset is usable without hard-coding an address', () async {
      for (final PresetHost preset in PresetHost.values) {
        final FakeNetworkAnalyzerPlatform each = FakeNetworkAnalyzerPlatform(
          session: FakeNetworkAnalyzerPlatform.defaultSession().copyWith(
            targetAddress: preset.primaryIPv4,
            targetName: preset.hostName,
          ),
        );
        final NetworkAnalyzer local = NetworkAnalyzer(
          controller: MonitoringController(platform: each),
        );

        final Result<SessionData, Failure> result = await local.startMonitoring(
          InternetInterface(
            protocol: MonitorProtocol.tcp,
            host: preset,
          ),
        );

        check(
          result.success.value.targetAddress,
          because: 'expected ${preset.name} to report its own address',
        ).equals(preset.primaryIPv4);
        check(result.success.value.targetName).equals(preset.hostName);
        await local.dispose();
        await each.dispose();
      }
    });

    test('a custom target is reported by name and address', () async {
      final FakeNetworkAnalyzerPlatform custom = FakeNetworkAnalyzerPlatform(
        session: FakeNetworkAnalyzerPlatform.defaultSession().copyWith(
          targetAddress: '10.0.0.53',
          targetName: 'Corporate resolver',
        ),
      );
      final NetworkAnalyzer local = NetworkAnalyzer(
        controller: MonitoringController(platform: custom),
      );

      final Result<SessionData, Failure> result = await local.startMonitoring(
        InternetInterface(
          protocol: MonitorProtocol.udp,
          host: CustomHost(
            hostName: 'Corporate resolver',
            primaryIPv4: '10.0.0.53',
          ),
        ),
      );

      check(result.success.value.targetAddress).equals('10.0.0.53');
      await local.dispose();
      await custom.dispose();
    });

    test('a gateway session reports the discovered address', () async {
      final FakeNetworkAnalyzerPlatform gateway = FakeNetworkAnalyzerPlatform(
        session: FakeNetworkAnalyzerPlatform.defaultSession().copyWith(
          kind: MonitorKind.gateway,
          targetAddress: '192.168.1.1',
          targetName: 'Gateway',
        ),
      );
      final NetworkAnalyzer local = NetworkAnalyzer(
        controller: MonitoringController(platform: gateway),
      );

      final Result<SessionData, Failure> result = await local.startMonitoring(
        GatewayInterface(protocol: MonitorProtocol.icmp),
      );

      check(result.success.value.targetAddress).equals('192.168.1.1');
      check(result.success.value.kind).equals(MonitorKind.gateway);
      await local.dispose();
      await gateway.dispose();
    });

    test('a failed gateway discovery yields no session at all', () async {
      final FakeNetworkAnalyzerPlatform failing = FakeNetworkAnalyzerPlatform(
        startFailure: const GatewayDiscoveryFailure(
          message: 'No default route is available.',
        ),
      );
      final NetworkAnalyzer local = NetworkAnalyzer(
        controller: MonitoringController(platform: failing),
      );
      final List<ConnectionMetrics> metrics = <ConnectionMetrics>[];
      final StreamSubscription<ConnectionMetrics> subscription = local.metrics
          .listen(metrics.add);

      final Result<SessionData, Failure> result = await local.startMonitoring(
        GatewayInterface(protocol: MonitorProtocol.tcp),
      );

      check(result.isFailure).isTrue();
      check(result.failure).isA<GatewayDiscoveryFailure>();
      check(local.currentSession.isFailure).isTrue();
      check(metrics).isEmpty();
      await subscription.cancel();
      await local.dispose();
      await failing.dispose();
    });

    test('a second start is rejected and never throws', () async {
      await analyzer.startMonitoring(
        InternetInterface(
          protocol: MonitorProtocol.tcp,
          host: PresetHost.google,
        ),
      );

      final Result<SessionData, Failure> second = await analyzer
          .startMonitoring(
            InternetInterface(
              protocol: MonitorProtocol.icmp,
              host: PresetHost.openDns,
            ),
          );

      check(second.isFailure).isTrue();
      check(second.failure).isA<SessionAlreadyRunningFailure>();
      check(analyzer.currentSession.success.value.protocol).equals(
        MonitorProtocol.tcp,
      );
    });

    test('stopping ends emission and halts probing', () async {
      final List<ConnectionMetrics> received = <ConnectionMetrics>[];
      final StreamSubscription<ConnectionMetrics> subscription = analyzer
          .metrics
          .listen(received.add);
      await analyzer.startMonitoring(
        InternetInterface(
          protocol: MonitorProtocol.tcp,
          host: PresetHost.google,
        ),
      );
      await platform.emitAll(steady(2, 20));

      await analyzer.stopMonitoring();
      await platform.emitAll(steady(3, 20, from: 2));

      check(received).length.equals(2);
      check(platform.stopCalls).equals(1);
      check(analyzer.currentSession.isFailure).isTrue();
      await subscription.cancel();
    });

    test('disposing completes the streams', () async {
      bool metricsDone = false;
      bool eventsDone = false;
      final StreamSubscription<ConnectionMetrics> a = analyzer.metrics.listen(
        (_) {},
        onDone: () => metricsDone = true,
      );
      final StreamSubscription<MonitorEvent> b = analyzer.events.listen(
        (_) {},
        onDone: () => eventsDone = true,
      );
      await analyzer.startMonitoring(
        InternetInterface(
          protocol: MonitorProtocol.tcp,
          host: PresetHost.google,
        ),
      );

      await analyzer.dispose();
      await Future<void>.delayed(Duration.zero);

      check(metricsDone).isTrue();
      check(eventsDone).isTrue();
      await a.cancel();
      await b.cancel();
    });

    test('measurements reach the caller', () async {
      final List<ConnectionMetrics> received = <ConnectionMetrics>[];
      final StreamSubscription<ConnectionMetrics> subscription = analyzer
          .metrics
          .listen(received.add);
      await analyzer.startMonitoring(
        InternetInterface(
          protocol: MonitorProtocol.tcp,
          host: PresetHost.google,
        ),
      );

      await platform.emitAll(steady(5, 20));

      check(received).length.equals(5);
      check(received.last.health).equals(ConnectionHealth.stable);
      await subscription.cancel();
    });

    test('monitoringStarted arrives before the first measurement', () async {
      final List<String> order = <String>[];
      final StreamSubscription<MonitorUpdate> subscription = analyzer.updates
          .listen((MonitorUpdate update) {
            order.add(switch (update) {
              MetricsUpdate() => 'metrics',
              EventUpdate(:final MonitorEvent event) => event.kind.name,
            });
          });
      await analyzer.startMonitoring(
        InternetInterface(
          protocol: MonitorProtocol.tcp,
          host: PresetHost.google,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await platform.emitAll(<ProbeSample>[hit(0, 20)]);

      check(order.first).equals('monitoringStarted');
      check(order).contains('metrics');
      await subscription.cancel();
    });

    test('currentSession reports no session when idle', () {
      check(analyzer.currentSession.isFailure).isTrue();
      check(analyzer.currentSession.failure).isA<NoActiveSessionFailure>();
    });
  });
}
