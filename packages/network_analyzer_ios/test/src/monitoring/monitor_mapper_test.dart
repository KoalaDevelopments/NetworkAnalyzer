import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_analyzer_ios/src/monitoring.g.dart';
import 'package:network_analyzer_ios/src/monitoring/monitor_mapper.dart';
import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';

void main() {
  group('enum mapping', () {
    test('protocols round-trip through the wire representation', () {
      for (final MonitorProtocol protocol in MonitorProtocol.values) {
        check(toMonitorProtocol(toProtocolMessage(protocol))).equals(protocol);
      }
    });

    test('monitor kinds round-trip through the wire representation', () {
      for (final MonitorKind kind in MonitorKind.values) {
        check(toMonitorKind(toKindMessage(kind))).equals(kind);
      }
    });

    test('interface types round-trip through the wire representation', () {
      for (final NetworkInterfaceType type in NetworkInterfaceType.values) {
        check(
          toNetworkInterfaceType(toInterfaceTypeMessage(type)),
        ).equals(type);
      }
    });

    test('probe outcomes round-trip through the wire representation', () {
      for (final ProbeOutcome outcome in ProbeOutcome.values) {
        check(toProbeOutcome(toOutcomeMessage(outcome))).equals(outcome);
      }
    });
  });

  group('toConfigMessage', () {
    test('an internet monitor carries its target and both addresses', () {
      final MonitorConfigMessage message = toConfigMessage(
        InternetInterface(
          protocol: MonitorProtocol.icmp,
          host: PresetHost.cloudflare,
        ),
      );
      check(message.probeProtocol).equals(ProtocolMessage.icmp);
      check(message.kind).equals(KindMessage.internet);
      check(message.targetIPv4).equals('1.1.1.1');
      check(message.fallbackIPv4).equals('1.0.0.1');
      check(message.targetName).equals('Cloudflare DNS');
      check(message.port).equals(53);
    });

    test('a gateway monitor sends no address', () {
      final MonitorConfigMessage message = toConfigMessage(
        GatewayInterface(protocol: MonitorProtocol.tcp),
      );
      check(message.kind).equals(KindMessage.gateway);
      check(message.targetIPv4).isNull();
      check(message.fallbackIPv4).isNull();
    });

    test('tuning crosses the wire in milliseconds', () {
      final MonitorConfigMessage message = toConfigMessage(
        InternetInterface(
          protocol: MonitorProtocol.tcp,
          host: PresetHost.google,
          options: MonitorOptions(
            probeInterval: const Duration(milliseconds: 500),
            probeTimeout: const Duration(milliseconds: 250),
          ),
        ),
      );
      check(message.probeIntervalMillis).equals(500);
      check(message.probeTimeoutMillis).equals(250);
    });

    test('thresholds are not sent — they are a Dart-side concern', () {
      MonitorConfigMessage build(HealthThresholds thresholds) =>
          toConfigMessage(
            InternetInterface(
              protocol: MonitorProtocol.tcp,
              host: PresetHost.google,
              thresholds: thresholds,
            ),
          );
      final MonitorConfigMessage withDefaults = build(HealthThresholds());
      final MonitorConfigMessage withOverrides = build(
        HealthThresholds(stableLatency: const Duration(milliseconds: 5)),
      );
      check(withOverrides.probeProtocol).equals(withDefaults.probeProtocol);
      check(withOverrides.kind).equals(withDefaults.kind);
      check(withOverrides.targetIPv4).equals(withDefaults.targetIPv4);
      check(withOverrides.fallbackIPv4).equals(withDefaults.fallbackIPv4);
      check(withOverrides.targetName).equals(withDefaults.targetName);
      check(withOverrides.port).equals(withDefaults.port);
      check(
        withOverrides.probeIntervalMillis,
      ).equals(withDefaults.probeIntervalMillis);
      check(
        withOverrides.probeTimeoutMillis,
      ).equals(withDefaults.probeTimeoutMillis);
    });
  });

  group('toSessionData', () {
    test('converts every field and keeps the timestamp in UTC', () {
      final SessionData session = toSessionData(
        SessionDataMessage(
          interfaceType: InterfaceTypeMessage.cellular4g,
          probeProtocol: ProtocolMessage.udp,
          kind: KindMessage.internet,
          deviceIpAddress: '10.1.2.3',
          targetAddress: '8.8.8.8',
          targetName: 'Google Public DNS',
          startedAtUtcMillis: 1787654321000,
        ),
      );
      check(session.interfaceType).equals(NetworkInterfaceType.cellular4g);
      check(session.protocol).equals(MonitorProtocol.udp);
      check(session.deviceIpAddress).equals('10.1.2.3');
      check(session.targetAddress).equals('8.8.8.8');
      check(session.startedAt.isUtc).isTrue();
      check(session.startedAt.millisecondsSinceEpoch).equals(1787654321000);
    });
  });

  group('toMonitorSignal', () {
    test('a successful sample keeps microsecond precision', () {
      final MonitorSignal signal = toMonitorSignal(
        ProbeSampleMessage(
          sequence: 7,
          roundTripMicros: 20345,
          outcome: OutcomeMessage.success,
          elapsedMicros: 7000000,
        ),
      );
      check(signal).isA<ProbeSample>();
      final ProbeSample sample = signal as ProbeSample;
      check(sample.sequence).equals(7);
      check(sample.roundTrip).equals(const Duration(microseconds: 20345));
      check(sample.sinceSessionStart).equals(const Duration(seconds: 7));
      check(sample.isSuccess).isTrue();
    });

    test('a failed sample carries no round-trip time', () {
      final ProbeSample sample =
          toMonitorSignal(
                ProbeSampleMessage(
                  sequence: 8,
                  outcome: OutcomeMessage.timeout,
                  elapsedMicros: 8000000,
                ),
              )
              as ProbeSample;
      check(sample.roundTrip).isNull();
      check(sample.outcome).equals(ProbeOutcome.timeout);
    });

    test('a network state change converts its optional addresses', () {
      final NetworkStateChange change =
          toMonitorSignal(
                NetworkStateMessage(
                  interfaceType: InterfaceTypeMessage.none,
                  targetAddress: '192.168.0.1',
                ),
              )
              as NetworkStateChange;
      check(change.interfaceType).equals(NetworkInterfaceType.none);
      check(change.deviceIpAddress).isNull();
      check(change.targetAddress).equals('192.168.0.1');
    });
  });
}
