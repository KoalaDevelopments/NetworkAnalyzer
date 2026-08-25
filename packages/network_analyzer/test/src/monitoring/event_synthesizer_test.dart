import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_analyzer/network_analyzer.dart';
import 'package:network_analyzer/src/monitoring/event_synthesizer.dart';
import 'package:network_analyzer/src/monitoring/metrics_engine.dart';

import 'fixtures.dart';

void main() {
  late EventSynthesizer synthesizer;
  late MetricsEngine engine;

  setUp(() {
    synthesizer = EventSynthesizer(thresholds: HealthThresholds())
      ..seed(sessionFixture());
    engine = MetricsEngine(
      session: sessionFixture(),
      options: MonitorOptions(),
      thresholds: HealthThresholds(),
    );
  });

  List<MonitorEvent> feed(Iterable<ProbeSample> samples) {
    final List<MonitorEvent> events = <MonitorEvent>[];
    for (final ProbeSample sample in samples) {
      final ConnectionMetrics metrics = engine.addSample(sample);
      events.addAll(
        synthesizer.fromMetrics(
          metrics,
          wasSpike: engine.lastSampleWasSpike,
        ),
      );
    }
    return events;
  }

  group('EventSynthesizer lifecycle', () {
    test('started names the interface, protocol and target', () {
      final MonitorEvent event = synthesizer.started(sessionFixture());

      check(event.kind).equals(MonitorEventKind.monitoringStarted);
      check(event.timestamp.isUtc).isTrue();
      check(event.message).contains('8.8.8.8');
      check(event.message).contains('wifi');
    });

    test('stopped reports the end of the session', () {
      check(
        synthesizer.stopped(sessionFixture()).kind,
      ).equals(MonitorEventKind.monitoringStopped);
    });
  });

  group('EventSynthesizer health transitions', () {
    test('a health change carries both the old and the new verdict', () {
      final List<MonitorEvent> events = feed(<ProbeSample>[
        ...steady(4, 20),
        ...List<ProbeSample>.generate(6, (int index) => hit(index + 4, 400)),
      ]);

      final MonitorEvent changed = events.firstWhere(
        (MonitorEvent event) => event.kind == MonitorEventKind.healthChanged,
      );
      check(changed.message).contains('unknown');
      check(changed.message).contains('stable');
    });

    test('a steady connection produces no health events', () {
      final List<MonitorEvent> events = feed(steady(3, 20));

      check(
        events.where(
          (MonitorEvent event) => event.kind == MonitorEventKind.healthChanged,
        ),
      ).length.equals(1); // unknown -> stable, once
    });
  });

  group('EventSynthesizer throttling', () {
    test('a persistent condition does not flood the stream', () {
      // Every sample after the first is a loss, so the condition holds for
      // the whole run; only the first crossing inside the cooldown reports.
      final List<MonitorEvent> events = feed(<ProbeSample>[
        hit(0, 20),
        ...List<ProbeSample>.generate(20, (int index) => miss(index + 1)),
      ]);

      check(
        events.where(
          (MonitorEvent event) =>
              event.kind == MonitorEventKind.packetLossDetected,
        ),
      ).length.equals(1);
    });

    test('the cooldown lets the condition report again later', () {
      final List<MonitorEvent> events = feed(<ProbeSample>[
        hit(0, 20),
        ...List<ProbeSample>.generate(40, (int index) => miss(index + 1)),
      ]);

      // Samples are one second apart in the fixtures, so a 40 second run
      // crosses the 30 second cooldown exactly once.
      check(
        events.where(
          (MonitorEvent event) =>
              event.kind == MonitorEventKind.packetLossDetected,
        ),
      ).length.equals(2);
    });

    test('edge-triggered kinds are never throttled', () {
      for (final MonitorEventKind kind in MonitorEventKind.values) {
        final bool expected = switch (kind) {
          MonitorEventKind.packetLossDetected ||
          MonitorEventKind.highJitterDetected ||
          MonitorEventKind.latencySpikeDetected => false,
          _ => true,
        };
        check(
          kind.isEdgeTriggered,
          because: 'expected ${kind.name} edge-triggered == $expected',
        ).equals(expected);
      }
    });

    test('suppressing spike events never alters the spike count', () {
      final List<ProbeSample> samples = <ProbeSample>[
        ...steady(3, 20),
        hit(3, 300),
        ...steady(3, 20, from: 4),
        hit(7, 300),
      ];
      final List<MonitorEvent> events = feed(samples);

      final int spikeEvents = events
          .where(
            (MonitorEvent event) =>
                event.kind == MonitorEventKind.latencySpikeDetected,
          )
          .length;
      check(spikeEvents).equals(1);
      // Both spikes are still counted, even though one event was suppressed.
      check(engine.addSample(hit(8, 20)).spikeCount).equals(2);
    });

    test('high jitter is reported', () {
      final List<MonitorEvent> events = feed(<ProbeSample>[
        hit(0, 20),
        hit(1, 200),
        hit(2, 20),
        hit(3, 200),
      ]);

      check(
        events.where(
          (MonitorEvent event) =>
              event.kind == MonitorEventKind.highJitterDetected,
        ),
      ).isNotEmpty();
    });
  });

  group('EventSynthesizer network changes', () {
    List<MonitorEvent> change(NetworkInterfaceType type, {String? device}) =>
        synthesizer.fromNetworkChange(
          NetworkStateChange(interfaceType: type, deviceIpAddress: device),
          sessionFixture(interfaceType: type),
        );

    test('losing connectivity is reported and the session stays open', () {
      final List<MonitorEvent> events = change(NetworkInterfaceType.none);

      check(events).length.equals(1);
      check(events.single.kind).equals(MonitorEventKind.connectivityLost);
      check(events.single.message).contains('stays open');
    });

    test('regaining connectivity is reported', () {
      change(NetworkInterfaceType.none);

      final List<MonitorEvent> events = change(NetworkInterfaceType.wifi);

      check(events.single.kind).equals(MonitorEventKind.connectivityRestored);
    });

    test('an interface switch is reported', () {
      final List<MonitorEvent> events = change(
        NetworkInterfaceType.cellular4g,
      );

      check(events.single.kind).equals(MonitorEventKind.interfaceChanged);
      check(events.single.message).contains('cellular4g');
    });

    test('an unchanged interface reports nothing', () {
      check(change(NetworkInterfaceType.wifi)).isEmpty();
    });

    test('a device address change is reported', () {
      final List<MonitorEvent> events = change(
        NetworkInterfaceType.wifi,
        device: '10.9.9.9',
      );

      check(events.single.kind).equals(MonitorEventKind.ipAddressChanged);
      check(events.single.message).contains('10.9.9.9');
    });

    test('a target address change is reported', () {
      final List<MonitorEvent> events = synthesizer.fromNetworkChange(
        const NetworkStateChange(
          interfaceType: NetworkInterfaceType.wifi,
          targetAddress: '8.8.4.4',
        ),
        sessionFixture(),
      );

      check(events.single.kind).equals(MonitorEventKind.targetAddressChanged);
      check(events.single.message).contains('8.8.4.4');
    });
  });
}
