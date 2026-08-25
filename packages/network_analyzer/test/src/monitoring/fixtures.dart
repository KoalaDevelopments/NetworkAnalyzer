/// Fixed sample sequences shared by the engine tests.
///
/// Every test in this directory drives the engine from data built here, so
/// none of them touches a network and all of them are reproducible.
library;

import 'package:network_analyzer/network_analyzer.dart';

/// A plausible Wi-Fi session against Google Public DNS.
SessionData sessionFixture({
  NetworkInterfaceType interfaceType = NetworkInterfaceType.wifi,
}) => SessionData(
  interfaceType: interfaceType,
  protocol: MonitorProtocol.tcp,
  kind: MonitorKind.internet,
  deviceIpAddress: '192.168.1.42',
  targetAddress: '8.8.8.8',
  targetName: 'Google Public DNS',
  startedAt: DateTime.utc(2026, 8, 24, 12),
);

/// A successful sample of [latencyMillis] at position [sequence].
ProbeSample hit(int sequence, int latencyMillis) => ProbeSample(
  sequence: sequence,
  outcome: ProbeOutcome.success,
  roundTrip: Duration(milliseconds: latencyMillis),
  sinceSessionStart: Duration(seconds: sequence + 1),
);

/// A lost sample at position [sequence].
ProbeSample miss(int sequence, {ProbeOutcome outcome = ProbeOutcome.timeout}) =>
    ProbeSample(
      sequence: sequence,
      outcome: outcome,
      sinceSessionStart: Duration(seconds: sequence + 1),
    );

/// [count] successful samples of [latencyMillis], starting at [from].
List<ProbeSample> steady(int count, int latencyMillis, {int from = 0}) =>
    List<ProbeSample>.generate(
      count,
      (int index) => hit(from + index, latencyMillis),
    );
