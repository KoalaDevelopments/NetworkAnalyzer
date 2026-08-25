import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_analyzer/network_analyzer.dart';
import 'package:network_analyzer/src/monitoring/health_evaluator.dart';

void main() {
  final HealthEvaluator evaluator = HealthEvaluator(HealthThresholds());

  ConnectionHealth verdict({
    int successfulSamples = 10,
    double packetLossPercent = 0,
    NetworkInterfaceType interfaceType = NetworkInterfaceType.wifi,
    Duration? meanLatency = const Duration(milliseconds: 20),
    Duration? jitter = const Duration(milliseconds: 5),
    HealthEvaluator? using,
  }) => (using ?? evaluator).evaluate(
    successfulSamples: successfulSamples,
    packetLossPercent: packetLossPercent,
    interfaceType: interfaceType,
    meanLatency: meanLatency,
    jitter: jitter,
  );

  group('HealthEvaluator', () {
    test('a good connection is stable', () {
      check(verdict()).equals(ConnectionHealth.stable);
    });

    test('latency alone can degrade the verdict', () {
      check(
        verdict(meanLatency: const Duration(milliseconds: 200)),
      ).equals(ConnectionHealth.unstable);
      check(
        verdict(meanLatency: const Duration(milliseconds: 400)),
      ).equals(ConnectionHealth.critical);
    });

    test('packet loss alone can degrade the verdict', () {
      check(verdict(packetLossPercent: 3)).equals(ConnectionHealth.unstable);
      check(verdict(packetLossPercent: 20)).equals(ConnectionHealth.critical);
    });

    test('jitter alone can degrade the verdict', () {
      check(
        verdict(jitter: const Duration(milliseconds: 40)),
      ).equals(ConnectionHealth.unstable);
      check(
        verdict(jitter: const Duration(milliseconds: 80)),
      ).equals(ConnectionHealth.critical);
    });

    test('the worst input wins — perfect jitter cannot mask heavy loss', () {
      check(
        verdict(packetLossPercent: 20, jitter: Duration.zero),
      ).equals(ConnectionHealth.critical);
    });

    test('boundaries are inclusive of the better grade', () {
      check(
        verdict(meanLatency: const Duration(milliseconds: 100)),
      ).equals(ConnectionHealth.stable);
      check(verdict(packetLossPercent: 1)).equals(ConnectionHealth.stable);
      check(
        verdict(jitter: const Duration(milliseconds: 30)),
      ).equals(ConnectionHealth.stable);
      check(
        verdict(meanLatency: const Duration(milliseconds: 250)),
      ).equals(ConnectionHealth.unstable);
    });

    test('too few successful samples means unknown', () {
      check(verdict(successfulSamples: 2)).equals(ConnectionHealth.unknown);
    });

    test('no interface at all means unknown', () {
      check(
        verdict(interfaceType: NetworkInterfaceType.none),
      ).equals(ConnectionHealth.unknown);
    });

    test('total loss on a live interface is critical, not unknown', () {
      // The network is up and the target is not answering. That is measured
      // information, not an absence of it.
      check(
        verdict(
          successfulSamples: 0,
          packetLossPercent: 100,
          meanLatency: null,
          jitter: null,
        ),
      ).equals(ConnectionHealth.critical);
    });

    test('custom thresholds shift every verdict', () {
      final HealthEvaluator strict = HealthEvaluator(
        HealthThresholds(
          stableLatency: const Duration(milliseconds: 10),
          unstableLatency: const Duration(milliseconds: 15),
        ),
      );

      check(
        verdict(using: strict),
      ).equals(ConnectionHealth.critical);
    });
  });
}
