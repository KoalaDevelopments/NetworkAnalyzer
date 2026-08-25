import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_analyzer/network_analyzer.dart';

import '../../fakes/fake_network_analyzer_platform.dart';
import 'fixtures.dart';

void main() {
  late FakeNetworkAnalyzerPlatform platform;
  late MonitoringController controller;

  MonitorInterface target({MonitorOptions? options}) => InternetInterface(
    protocol: MonitorProtocol.tcp,
    host: PresetHost.google,
    options: options,
  );

  setUp(() {
    platform = FakeNetworkAnalyzerPlatform();
    controller = MonitoringController(platform: platform);
  });

  tearDown(() async {
    await controller.dispose();
    await platform.dispose();
  });

  group('single-flight', () {
    test('a second start is rejected and leaves the first alone', () async {
      final Result<SessionData, Failure> first = await controller.start(
        target(),
      );

      final Result<SessionData, Failure> second = await controller.start(
        target(),
      );

      check(first.isSuccess).isTrue();
      check(second.isFailure).isTrue();
      check(second.failure).isA<SessionAlreadyRunningFailure>();
      check(platform.startCalls).equals(1);
      check(controller.currentSession.isSuccess).isTrue();
    });

    test('a failed start leaves no session behind', () async {
      final FakeNetworkAnalyzerPlatform failing = FakeNetworkAnalyzerPlatform(
        startFailure: const GatewayDiscoveryFailure(message: 'no route'),
      );
      final MonitoringController failingController = MonitoringController(
        platform: failing,
      );

      final Result<SessionData, Failure> result = await failingController.start(
        GatewayInterface(protocol: MonitorProtocol.tcp),
      );

      check(result.isFailure).isTrue();
      check(failingController.currentSession.isFailure).isTrue();
      await failingController.dispose();
      await failing.dispose();
    });

    test('stopping when idle succeeds as a no-op', () async {
      final Result<void, Failure> result = await controller.stop();

      check(result.isSuccess).isTrue();
      check(platform.stopCalls).equals(0);
    });

    test('currentSession reports no session when idle', () {
      check(controller.currentSession.isFailure).isTrue();
      check(controller.currentSession.failure).isA<NoActiveSessionFailure>();
    });

    test('a session can be restarted after stopping', () async {
      await controller.start(target());
      await controller.stop();

      final Result<SessionData, Failure> again = await controller.start(
        target(),
      );

      check(again.isSuccess).isTrue();
      check(platform.startCalls).equals(2);
    });
  });

  group('streams', () {
    test('metrics arrive for every sample', () async {
      final List<ConnectionMetrics> received = <ConnectionMetrics>[];
      final StreamSubscription<ConnectionMetrics> subscription = controller
          .metrics
          .listen(received.add);
      await controller.start(target());

      await platform.emitAll(steady(3, 20));

      check(received).length.equals(3);
      check(received.last.latency).equals(const Duration(milliseconds: 20));
      await subscription.cancel();
    });

    test(
      'the combined stream carries both kinds in production order',
      () async {
        final List<MonitorUpdate> received = <MonitorUpdate>[];
        final StreamSubscription<MonitorUpdate> subscription = controller
            .updates
            .listen(received.add);
        await controller.start(target());
        await Future<void>.delayed(Duration.zero);

        await platform.emitAll(steady(3, 20));

        // monitoringStarted, then a metrics update per sample.
        check(received.first).isA<EventUpdate>();
        check(
          received.whereType<MetricsUpdate>(),
        ).length.equals(3);
        await subscription.cancel();
      },
    );

    test('every update is exhaustively identifiable', () async {
      final List<String> kinds = <String>[];
      final StreamSubscription<MonitorUpdate> subscription = controller.updates
          .listen((MonitorUpdate update) {
            kinds.add(switch (update) {
              MetricsUpdate() => 'metrics',
              EventUpdate() => 'event',
            });
          });
      await controller.start(target());
      await platform.emitAll(<ProbeSample>[hit(0, 20)]);

      check(kinds).contains('metrics');
      check(kinds).contains('event');
      await subscription.cancel();
    });

    test('subscribing to every stream starts no second session', () async {
      final StreamSubscription<ConnectionMetrics> a = controller.metrics.listen(
        (_) {},
      );
      final StreamSubscription<MonitorEvent> b = controller.events.listen(
        (_) {},
      );
      final StreamSubscription<MonitorUpdate> c = controller.updates.listen(
        (_) {},
      );
      await controller.start(target());

      check(platform.startCalls).equals(1);
      await a.cancel();
      await b.cancel();
      await c.cancel();
    });

    test('all three streams see the same measurements', () async {
      final List<ConnectionMetrics> viaMetrics = <ConnectionMetrics>[];
      final List<ConnectionMetrics> viaUpdates = <ConnectionMetrics>[];
      final StreamSubscription<ConnectionMetrics> a = controller.metrics.listen(
        viaMetrics.add,
      );
      final StreamSubscription<MonitorUpdate> b = controller.updates.listen((
        MonitorUpdate update,
      ) {
        if (update is MetricsUpdate) {
          viaUpdates.add(update.metrics);
        }
      });
      await controller.start(target());

      await platform.emitAll(steady(4, 20));

      check(viaUpdates).deepEquals(viaMetrics);
      await a.cancel();
      await b.cancel();
    });
  });

  group('subscriber accounting', () {
    test('a never-subscribed session keeps running', () async {
      await controller.start(target());
      await Future<void>.delayed(Duration.zero);

      check(controller.currentSession.isSuccess).isTrue();
      check(platform.stopCalls).equals(0);
    });

    test('the last cancellation stops the session', () async {
      await controller.start(target());
      final StreamSubscription<ConnectionMetrics> subscription = controller
          .metrics
          .listen((_) {});
      await Future<void>.delayed(Duration.zero);

      await subscription.cancel();
      await Future<void>.delayed(Duration.zero);

      check(platform.stopCalls).equals(1);
      check(controller.currentSession.isFailure).isTrue();
    });

    test('cancelling one of two streams keeps the session alive', () async {
      await controller.start(target());
      final StreamSubscription<ConnectionMetrics> a = controller.metrics.listen(
        (_) {},
      );
      final StreamSubscription<MonitorEvent> b = controller.events.listen(
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);

      await a.cancel();
      await Future<void>.delayed(Duration.zero);

      check(platform.stopCalls).equals(0);
      check(controller.currentSession.isSuccess).isTrue();
      await b.cancel();
    });
  });

  group('target address fallback', () {
    test('a target change is reflected in the session facts', () async {
      final List<MonitorEvent> events = <MonitorEvent>[];
      final StreamSubscription<MonitorEvent> subscription = controller.events
          .listen(events.add);
      await controller.start(
        InternetInterface(
          protocol: MonitorProtocol.tcp,
          host: PresetHost.google,
        ),
      );

      await platform.emitAll(<MonitorSignal>[
        miss(0),
        miss(1),
        miss(2),
        const NetworkStateChange(
          interfaceType: NetworkInterfaceType.wifi,
          targetAddress: '8.8.4.4',
        ),
      ]);

      check(controller.currentSession.success.value.targetAddress).equals(
        '8.8.4.4',
      );
      check(
        events.map((MonitorEvent event) => event.kind),
      ).contains(MonitorEventKind.targetAddressChanged);
      await subscription.cancel();
    });
  });
}
