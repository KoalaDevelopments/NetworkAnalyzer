import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_analyzer/network_analyzer.dart';
import 'package:network_analyzer/src/monitoring/metrics_engine.dart';

import 'fixtures.dart';

MetricsEngine engineFor({
  MonitorOptions? options,
  HealthThresholds? thresholds,
  NetworkInterfaceType interfaceType = NetworkInterfaceType.wifi,
}) => MetricsEngine(
  session: sessionFixture(interfaceType: interfaceType),
  options: options ?? MonitorOptions(),
  thresholds: thresholds ?? HealthThresholds(),
);

List<ConnectionMetrics> replay(
  Iterable<ProbeSample> samples, {
  MetricsEngine? engine,
}) {
  final MetricsEngine active = engine ?? engineFor();
  return samples.map(active.addSample).toList();
}

void main() {
  group('MetricsEngine', () {
    test('a steady sequence is stable with no loss', () {
      final ConnectionMetrics last = replay(steady(10, 20)).last;

      check(last.health).equals(ConnectionHealth.stable);
      check(last.packetLossPercent).equals(0);
      check(last.latency).equals(const Duration(milliseconds: 20));
    });

    test('a single sample gives equal aggregates and no jitter', () {
      final ConnectionMetrics first = replay(<ProbeSample>[hit(0, 20)]).single;

      check(first.jitter).isNull();
      check(first.averageLatency).equals(const Duration(milliseconds: 20));
      check(first.lowestLatency).equals(const Duration(milliseconds: 20));
      check(first.highestLatency).equals(const Duration(milliseconds: 20));
      check(first.health).equals(ConnectionHealth.unknown);
    });

    test('jitter becomes available at the second successful sample', () {
      final List<ConnectionMetrics> emitted = replay(<ProbeSample>[
        hit(0, 20),
        hit(1, 35),
      ]);

      check(emitted.first.jitter).isNull();
      check(emitted.last.jitter).equals(const Duration(milliseconds: 15));
    });

    test('fewer than three successes means unknown health', () {
      final List<ConnectionMetrics> emitted = replay(steady(3, 20));

      check(emitted[0].health).equals(ConnectionHealth.unknown);
      check(emitted[1].health).equals(ConnectionHealth.unknown);
      check(emitted[2].health).equals(ConnectionHealth.stable);
    });

    test('one loss in a window of ten is ten percent', () {
      final List<ProbeSample> samples = <ProbeSample>[
        ...steady(9, 20),
        miss(9),
      ];

      check(replay(samples).last.packetLossPercent).equals(10);
    });

    test('loss recovers as the window rolls past it', () {
      final MetricsEngine engine = engineFor();
      replay(<ProbeSample>[...steady(9, 20), miss(9)], engine: engine);

      final ConnectionMetrics recovered = replay(
        steady(10, 20, from: 10),
        engine: engine,
      ).last;

      check(recovered.packetLossPercent).equals(0);
    });

    test('latency aggregates are cumulative and never reset', () {
      final MetricsEngine engine = engineFor();
      final List<ProbeSample> samples = <ProbeSample>[
        hit(0, 10),
        hit(1, 50),
        ...steady(20, 20, from: 2),
      ];

      final ConnectionMetrics last = replay(samples, engine: engine).last;

      // The 10 ms and 50 ms samples fell out of the 10-sample window long
      // ago, but the session's extremes still remember them.
      check(last.lowestLatency).equals(const Duration(milliseconds: 10));
      check(last.highestLatency).equals(const Duration(milliseconds: 50));
    });

    test('a spike is counted once and the count never decreases', () {
      final List<ConnectionMetrics> emitted = replay(<ProbeSample>[
        ...steady(3, 20),
        hit(3, 300),
        ...steady(5, 20, from: 4),
      ]);

      check(emitted[2].spikeCount).equals(0);
      check(emitted[3].spikeCount).equals(1);
      check(emitted.last.spikeCount).equals(1);
    });

    test('a small jump does not count as a spike', () {
      final List<ConnectionMetrics> emitted = replay(<ProbeSample>[
        ...steady(3, 20),
        hit(3, 45),
      ]);

      check(emitted.last.spikeCount).equals(0);
    });

    test('sustained loss on a live interface is 100 percent and critical', () {
      final List<ProbeSample> samples = List<ProbeSample>.generate(
        10,
        (int index) => miss(index),
      );

      final ConnectionMetrics last = replay(samples).last;

      check(last.packetLossPercent).equals(100);
      check(last.health).equals(ConnectionHealth.critical);
      check(last.latency).isNull();
      check(last.averageLatency).isNull();
    });

    test('losing the interface makes the verdict unknown', () {
      final MetricsEngine engine = engineFor();
      replay(steady(5, 20), engine: engine);

      engine.applyNetworkChange(
        const NetworkStateChange(interfaceType: NetworkInterfaceType.none),
      );
      final ConnectionMetrics after = engine.addSample(miss(5));

      check(after.health).equals(ConnectionHealth.unknown);
      check(after.session.interfaceType).equals(NetworkInterfaceType.none);
    });

    test('a network change updates the session on later measurements', () {
      final MetricsEngine engine = engineFor();
      replay(steady(3, 20), engine: engine);

      engine.applyNetworkChange(
        const NetworkStateChange(
          interfaceType: NetworkInterfaceType.cellular4g,
          deviceIpAddress: '10.1.2.3',
        ),
      );
      final ConnectionMetrics after = engine.addSample(hit(3, 40));

      check(
        after.session.interfaceType,
      ).equals(NetworkInterfaceType.cellular4g);
      check(after.session.deviceIpAddress).equals('10.1.2.3');
      check(after.session.targetAddress).equals('8.8.8.8');
    });

    test('uptime tracks the monotonic elapsed time from the sample', () {
      final ConnectionMetrics last = replay(steady(5, 20)).last;

      check(last.uptime).equals(const Duration(seconds: 5));
    });

    test('latency and jitter round to a tenth of a millisecond', () {
      final ConnectionMetrics last = replay(<ProbeSample>[
        ProbeSample(
          sequence: 0,
          outcome: ProbeOutcome.success,
          roundTrip: const Duration(microseconds: 20_349),
          sinceSessionStart: const Duration(seconds: 1),
        ),
        ProbeSample(
          sequence: 1,
          outcome: ProbeOutcome.success,
          roundTrip: const Duration(microseconds: 25_351),
          sinceSessionStart: const Duration(seconds: 2),
        ),
      ]).last;

      check(last.latency).equals(const Duration(microseconds: 25_400));
      check(last.jitter).equals(const Duration(microseconds: 5_000));
    });

    test('packet loss rounds to one decimal place', () {
      final List<ProbeSample> samples = <ProbeSample>[
        miss(0),
        ...steady(2, 20, from: 1),
      ];

      // 1 of 3 lost is 33.333…%, reported as 33.3%.
      check(replay(samples).last.packetLossPercent).equals(33.3);
    });

    test('the same fixture replayed twice produces identical output', () {
      final List<ProbeSample> samples = <ProbeSample>[
        ...steady(4, 20),
        miss(4),
        hit(5, 300),
        ...steady(4, 25, from: 6),
      ];

      check(replay(samples)).deepEquals(replay(samples));
    });

    test('retained samples never exceed the configured window', () {
      final MetricsEngine engine = engineFor(
        options: MonitorOptions(),
      );

      // 86,400 samples is a full day at the default one second cadence.
      for (int index = 0; index < 86400; index++) {
        engine.addSample(hit(index, 20));
      }

      check(engine.retainedSamples).equals(10);
    });

    test('a 24 hour session still reports correct aggregates', () {
      final MetricsEngine engine = engineFor();
      ConnectionMetrics? last;
      for (int index = 0; index < 86400; index++) {
        last = engine.addSample(hit(index, index == 0 ? 5 : 20));
      }

      check(last!.lowestLatency).equals(const Duration(milliseconds: 5));
      check(last.highestLatency).equals(const Duration(milliseconds: 20));
      check(last.uptime).equals(const Duration(seconds: 86400));
    });
  });
}
