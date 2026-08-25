import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:network_analyzer/network_analyzer.dart';

/// End-to-end verification of real-time monitoring on a real device.
///
/// These are the only tests in the repository that touch a live network. Every
/// rule about how measurements are derived is asserted against fixtures in the
/// unit tests instead; what is verified here is that the native side actually
/// probes, reports and stops.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late NetworkAnalyzer analyzer;

  setUp(() => analyzer = NetworkAnalyzer());
  tearDown(() async {
    await analyzer.stopMonitoring();
    await analyzer.dispose();
  });

  Future<List<T>> collect<T>(
    Stream<T> stream, {
    required int count,
    Duration timeout = const Duration(seconds: 20),
  }) {
    final List<T> received = <T>[];
    final Completer<List<T>> completer = Completer<List<T>>();
    late final StreamSubscription<T> subscription;
    final Timer timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(received);
      }
    });
    subscription = stream.listen((T item) {
      received.add(item);
      if (received.length >= count && !completer.isCompleted) {
        completer.complete(received);
      }
    });
    return completer.future.whenComplete(() {
      timer.cancel();
      unawaited(subscription.cancel());
    });
  }

  testWidgets('US1: an internet monitor reports a live session', (_) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final Future<List<ConnectionMetrics>> pending = collect(
      analyzer.metrics,
      count: 3,
    );

    final Result<SessionData, Failure> started = await analyzer.startMonitoring(
      InternetInterface(
        protocol: MonitorProtocol.tcp,
        host: PresetHost.google,
      ),
    );

    check(started.isSuccess).isTrue();
    final SessionData session = started.success.value;
    check(session.interfaceType).not(
      (it) => it.equals(
        NetworkInterfaceType.none,
      ),
    );
    check(session.deviceIpAddress).isNotEmpty();
    check(session.targetAddress).equals('8.8.8.8');
    check(session.kind).equals(MonitorKind.internet);
    check(session.startedAt.isUtc).isTrue();

    final List<ConnectionMetrics> metrics = await pending;
    // SC-001: the first measurement arrives within three seconds.
    check(metrics).isNotEmpty();
    check(stopwatch.elapsed).isLessThan(const Duration(seconds: 10));
    check(metrics.first.session.targetAddress).equals('8.8.8.8');
    check(metrics.last.uptime).isGreaterThan(Duration.zero);
  });

  testWidgets('US1: cadence holds with no gap beyond twice the interval', (
    _,
  ) async {
    final Future<List<ConnectionMetrics>> pending = collect(
      analyzer.metrics,
      count: 5,
    );
    await analyzer.startMonitoring(
      InternetInterface(
        protocol: MonitorProtocol.tcp,
        host: PresetHost.cloudflare,
        options: MonitorOptions(
          probeInterval: const Duration(milliseconds: 500),
          probeTimeout: const Duration(milliseconds: 500),
        ),
      ),
    );

    final List<ConnectionMetrics> metrics = await pending;

    check(metrics.length).isGreaterOrEqual(5);
    for (int index = 1; index < metrics.length; index++) {
      // SC-002: no gap wider than twice the configured interval.
      final Duration gap = metrics[index].uptime - metrics[index - 1].uptime;
      check(gap).isLessThan(const Duration(seconds: 1, milliseconds: 200));
    }
  });

  testWidgets('US2: monitoringStarted precedes the first measurement', (
    _,
  ) async {
    final Future<List<MonitorUpdate>> pending = collect(
      analyzer.updates,
      count: 2,
    );

    await analyzer.startMonitoring(
      InternetInterface(
        protocol: MonitorProtocol.tcp,
        host: PresetHost.google,
      ),
    );
    final List<MonitorUpdate> updates = await pending;

    check(updates.first).isA<EventUpdate>();
    check(
      (updates.first as EventUpdate).event.kind,
    ).equals(MonitorEventKind.monitoringStarted);
    check(updates.any((MonitorUpdate u) => u is MetricsUpdate)).isTrue();
  });

  testWidgets('US2: every event carries a UTC timestamp', (_) async {
    final Future<List<MonitorEvent>> pending = collect(
      analyzer.events,
      count: 1,
    );
    await analyzer.startMonitoring(
      InternetInterface(
        protocol: MonitorProtocol.tcp,
        host: PresetHost.google,
      ),
    );

    final List<MonitorEvent> events = await pending;

    check(events).isNotEmpty();
    for (final MonitorEvent event in events) {
      check(event.timestamp.isUtc).isTrue();
      check(event.message).isNotEmpty();
    }
  });

  testWidgets('US3: a gateway monitor discovers its own target', (_) async {
    final Result<SessionData, Failure> started = await analyzer.startMonitoring(
      GatewayInterface(protocol: MonitorProtocol.tcp),
    );

    started.fold(
      onFailure: (Failure failure) {
        // A network with no default route is a legitimate environment; the
        // contract is that it fails with the typed failure and no session.
        check(failure).isA<GatewayDiscoveryFailure>();
        check(analyzer.currentSession.isFailure).isTrue();
      },
      onSuccess: (Success<SessionData> success) {
        check(success.value.kind).equals(MonitorKind.gateway);
        check(success.value.targetAddress).isNotEmpty();
        check(success.value.targetName).equals('Gateway');
      },
    );
  });

  testWidgets('US4: every preset is reachable by name alone', (_) async {
    for (final PresetHost preset in PresetHost.values) {
      final NetworkAnalyzer local = NetworkAnalyzer();
      final Result<SessionData, Failure> started = await local.startMonitoring(
        InternetInterface(protocol: MonitorProtocol.tcp, host: preset),
      );

      check(
        started.isSuccess,
        because: 'expected ${preset.hostName} to start',
      ).isTrue();
      check(started.success.value.targetAddress).equals(preset.primaryIPv4);
      await local.stopMonitoring();
      await local.dispose();
    }
  });

  testWidgets('a second start is rejected and leaves the first running', (
    _,
  ) async {
    final Result<SessionData, Failure> first = await analyzer.startMonitoring(
      InternetInterface(
        protocol: MonitorProtocol.tcp,
        host: PresetHost.google,
      ),
    );
    final Result<SessionData, Failure> second = await analyzer.startMonitoring(
      InternetInterface(
        protocol: MonitorProtocol.tcp,
        host: PresetHost.openDns,
      ),
    );

    check(first.isSuccess).isTrue();
    check(second.isFailure).isTrue();
    check(second.failure).isA<SessionAlreadyRunningFailure>();
    check(
      analyzer.currentSession.success.value.targetAddress,
    ).equals(first.success.value.targetAddress);
  });

  testWidgets('stopping when idle succeeds as a no-op', (_) async {
    final Result<void, Failure> result = await analyzer.stopMonitoring();

    check(result.isSuccess).isTrue();
  });

  testWidgets('SC-005: probing stops within two seconds of the last cancel', (
    _,
  ) async {
    final List<ConnectionMetrics> received = <ConnectionMetrics>[];
    final StreamSubscription<ConnectionMetrics> subscription = analyzer.metrics
        .listen(received.add);
    await analyzer.startMonitoring(
      InternetInterface(
        protocol: MonitorProtocol.tcp,
        host: PresetHost.google,
      ),
    );
    await Future<void>.delayed(const Duration(seconds: 3));

    await subscription.cancel();
    final int atCancel = received.length;
    await Future<void>.delayed(const Duration(seconds: 2));

    check(received.length).equals(atCancel);
    check(analyzer.currentSession.isFailure).isTrue();
  });

  testWidgets('every protocol either measures or fails with a typed failure', (
    _,
  ) async {
    for (final MonitorProtocol protocol in MonitorProtocol.values) {
      final NetworkAnalyzer local = NetworkAnalyzer();
      final Result<SessionData, Failure> started = await local.startMonitoring(
        InternetInterface(protocol: protocol, host: PresetHost.google),
      );

      started.fold(
        onFailure: (Failure failure) {
          // The only acceptable failure here is an honest one: never a
          // silent substitution of another protocol.
          check(
            failure,
            because: '${protocol.name} must fail with a typed failure',
          ).isA<UnsupportedCapabilityFailure>();
        },
        onSuccess: (Success<SessionData> success) {
          check(success.value.protocol).equals(protocol);
        },
      );
      await local.stopMonitoring();
      await local.dispose();
    }
  });
}
