/// Conversion between pigeon transport messages and the public domain
/// models.
///
/// Generated message classes are transport detail and never leave this
/// package (constitution, Principle II). Everything here is pure Dart with
/// no platform dependency, so it is unit-tested directly.
library;

import 'package:network_analyzer_ios/src/monitoring.g.dart';
import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';

/// Builds the native configuration for [target].
///
/// A gateway monitor sends no address: the native side discovers the
/// default route itself.
MonitorConfigMessage toConfigMessage(MonitorInterface target) {
  final MonitorHost? host = switch (target) {
    InternetInterface(:final MonitorHost host) => host,
    GatewayInterface() => null,
  };
  return MonitorConfigMessage(
    probeProtocol: toProtocolMessage(target.protocol),
    kind: toKindMessage(target.kind),
    targetIPv4: host?.primaryIPv4,
    fallbackIPv4: host?.secondaryIPv4,
    targetName: host?.hostName,
    port: host?.port ?? _defaultGatewayPort,
    probeIntervalMillis: target.options.probeInterval.inMilliseconds,
    probeTimeoutMillis: target.options.probeTimeout.inMilliseconds,
  );
}

/// The port a gateway TCP probe connects to.
///
/// Most consumer routers answer on 80; ICMP ignores the port entirely.
const int _defaultGatewayPort = 80;

/// Converts a session description reported by the native side.
SessionData toSessionData(SessionDataMessage message) => SessionData(
  interfaceType: toNetworkInterfaceType(message.interfaceType),
  protocol: toMonitorProtocol(message.probeProtocol),
  kind: toMonitorKind(message.kind),
  deviceIpAddress: message.deviceIpAddress,
  targetAddress: message.targetAddress,
  targetName: message.targetName,
  startedAt: DateTime.fromMillisecondsSinceEpoch(
    message.startedAtUtcMillis,
    isUtc: true,
  ),
);

/// Converts one signal reported by the native side.
///
/// Microseconds arrive at full precision and are rounded once, later, by the
/// metrics engine — rounding here would round twice, differently, on two
/// platforms.
MonitorSignal toMonitorSignal(MonitorSignalMessage message) =>
    switch (message) {
      ProbeSampleMessage() => ProbeSample(
        sequence: message.sequence,
        outcome: toProbeOutcome(message.outcome),
        sinceSessionStart: Duration(microseconds: message.elapsedMicros),
        roundTrip: message.roundTripMicros == null
            ? null
            : Duration(microseconds: message.roundTripMicros!),
      ),
      NetworkStateMessage() => NetworkStateChange(
        interfaceType: toNetworkInterfaceType(message.interfaceType),
        deviceIpAddress: message.deviceIpAddress,
        targetAddress: message.targetAddress,
      ),
    };

/// Converts a protocol to its wire representation.
ProtocolMessage toProtocolMessage(MonitorProtocol protocol) =>
    switch (protocol) {
      MonitorProtocol.tcp => ProtocolMessage.tcp,
      MonitorProtocol.udp => ProtocolMessage.udp,
      MonitorProtocol.icmp => ProtocolMessage.icmp,
    };

/// Converts a protocol from its wire representation.
MonitorProtocol toMonitorProtocol(ProtocolMessage message) => switch (message) {
  ProtocolMessage.tcp => MonitorProtocol.tcp,
  ProtocolMessage.udp => MonitorProtocol.udp,
  ProtocolMessage.icmp => MonitorProtocol.icmp,
};

/// Converts a monitor kind to its wire representation.
KindMessage toKindMessage(MonitorKind kind) => switch (kind) {
  MonitorKind.internet => KindMessage.internet,
  MonitorKind.gateway => KindMessage.gateway,
};

/// Converts a monitor kind from its wire representation.
MonitorKind toMonitorKind(KindMessage message) => switch (message) {
  KindMessage.internet => MonitorKind.internet,
  KindMessage.gateway => MonitorKind.gateway,
};

/// Converts an interface type from its wire representation.
NetworkInterfaceType toNetworkInterfaceType(InterfaceTypeMessage message) =>
    switch (message) {
      InterfaceTypeMessage.ethernet => NetworkInterfaceType.ethernet,
      InterfaceTypeMessage.wifi => NetworkInterfaceType.wifi,
      InterfaceTypeMessage.cellular5g => NetworkInterfaceType.cellular5g,
      InterfaceTypeMessage.cellular4g => NetworkInterfaceType.cellular4g,
      InterfaceTypeMessage.cellular3g => NetworkInterfaceType.cellular3g,
      InterfaceTypeMessage.cellular2g => NetworkInterfaceType.cellular2g,
      InterfaceTypeMessage.cellular => NetworkInterfaceType.cellular,
      InterfaceTypeMessage.vpn => NetworkInterfaceType.vpn,
      InterfaceTypeMessage.other => NetworkInterfaceType.other,
      InterfaceTypeMessage.none => NetworkInterfaceType.none,
      InterfaceTypeMessage.unknown => NetworkInterfaceType.unknown,
    };

/// Converts an interface type to its wire representation.
InterfaceTypeMessage toInterfaceTypeMessage(NetworkInterfaceType type) =>
    switch (type) {
      NetworkInterfaceType.ethernet => InterfaceTypeMessage.ethernet,
      NetworkInterfaceType.wifi => InterfaceTypeMessage.wifi,
      NetworkInterfaceType.cellular5g => InterfaceTypeMessage.cellular5g,
      NetworkInterfaceType.cellular4g => InterfaceTypeMessage.cellular4g,
      NetworkInterfaceType.cellular3g => InterfaceTypeMessage.cellular3g,
      NetworkInterfaceType.cellular2g => InterfaceTypeMessage.cellular2g,
      NetworkInterfaceType.cellular => InterfaceTypeMessage.cellular,
      NetworkInterfaceType.vpn => InterfaceTypeMessage.vpn,
      NetworkInterfaceType.other => InterfaceTypeMessage.other,
      NetworkInterfaceType.none => InterfaceTypeMessage.none,
      NetworkInterfaceType.unknown => InterfaceTypeMessage.unknown,
    };

/// Converts a probe outcome from its wire representation.
ProbeOutcome toProbeOutcome(OutcomeMessage message) => switch (message) {
  OutcomeMessage.success => ProbeOutcome.success,
  OutcomeMessage.timeout => ProbeOutcome.timeout,
  OutcomeMessage.unreachable => ProbeOutcome.unreachable,
  OutcomeMessage.error => ProbeOutcome.error,
};

/// Converts a probe outcome to its wire representation.
OutcomeMessage toOutcomeMessage(ProbeOutcome outcome) => switch (outcome) {
  ProbeOutcome.success => OutcomeMessage.success,
  ProbeOutcome.timeout => OutcomeMessage.timeout,
  ProbeOutcome.unreachable => OutcomeMessage.unreachable,
  ProbeOutcome.error => OutcomeMessage.error,
};
