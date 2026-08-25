// Pigeon API definition for real-time monitoring.
//
// Regenerate with ./tool/bootstrap.sh, which runs every pigeons/*.dart
// input. Generated files are committed after generation. Never edit a
// generated file by hand and never hand-write channel code (constitution,
// Principle II).
//
// includeErrorClass is false here because pigeons/messages.dart already
// emits the error class into the same Kotlin package and Swift module; a
// second copy would not compile.
//
// Thresholds and the sample window are deliberately absent from
// MonitorConfigMessage. They are consumed only by the Dart metrics engine,
// and sending them across the boundary would invite a second, divergent
// implementation natively.

// The event-channel API is a single-method class by pigeon's design.
// ignore_for_file: one_member_abstracts

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/monitoring.g.dart',
    swiftOut:
        'ios/network_analyzer_ios/Sources/network_analyzer_ios/Monitoring.g.swift',
    swiftOptions: SwiftOptions(includeErrorClass: false),
    dartPackageName: 'network_analyzer_ios',
  ),
)
/// How probes are sent.
enum ProtocolMessage { tcp, udp, icmp }

/// Whether the session watches the internet or the local gateway.
enum KindMessage { internet, gateway }

/// The interface a session is running over.
enum InterfaceTypeMessage {
  ethernet,
  wifi,
  cellular5g,
  cellular4g,
  cellular3g,
  cellular2g,
  cellular,
  vpn,
  other,
  none,
  unknown,
}

/// How a single probe ended.
enum OutcomeMessage { success, timeout, unreachable, error }

/// What to probe, how, and how often.
class MonitorConfigMessage {
  MonitorConfigMessage({
    required this.probeProtocol,
    required this.kind,
    required this.port,
    required this.probeIntervalMillis,
    required this.probeTimeoutMillis,
    this.targetIPv4,
    this.fallbackIPv4,
    this.targetName,
  });

  /// Named probeProtocol, not protocol: `protocol` is a reserved word in
  /// Swift, and pigeon emits it unescaped.
  ProtocolMessage probeProtocol;
  KindMessage kind;

  /// Null for a gateway monitor, whose target is discovered natively.
  String? targetIPv4;

  /// An alternative address to fall back to after repeated failures.
  String? fallbackIPv4;

  String? targetName;
  int port;
  int probeIntervalMillis;
  int probeTimeoutMillis;
}

/// The facts about a running session.
class SessionDataMessage {
  SessionDataMessage({
    required this.interfaceType,
    required this.probeProtocol,
    required this.kind,
    required this.deviceIpAddress,
    required this.targetAddress,
    required this.targetName,
    required this.startedAtUtcMillis,
  });

  InterfaceTypeMessage interfaceType;

  /// Named probeProtocol, not protocol: `protocol` is a reserved word in
  /// Swift, and pigeon emits it unescaped.
  ProtocolMessage probeProtocol;
  KindMessage kind;
  String deviceIpAddress;
  String targetAddress;
  String targetName;

  /// The only wall clock on the wire; every elapsed value is monotonic.
  int startedAtUtcMillis;
}

/// Session control.
@HostApi()
abstract class MonitoringHostApi {
  /// Starts probing and returns the facts about the new session.
  SessionDataMessage startSession(MonitorConfigMessage config);

  /// Stops probing within 500 ms. A no-op when nothing is running.
  void stopSession();

  /// The running session, or null when none is running.
  SessionDataMessage? currentSession();
}

/// Something the native side observed.
sealed class MonitorSignalMessage {}

/// The result of one probe.
class ProbeSampleMessage extends MonitorSignalMessage {
  ProbeSampleMessage({
    required this.sequence,
    required this.outcome,
    required this.elapsedMicros,
    this.roundTripMicros,
  });

  int sequence;

  /// Monotonic, and null unless the outcome is success.
  int? roundTripMicros;

  OutcomeMessage outcome;

  /// Monotonic time since the session started.
  int elapsedMicros;
}

/// A change in the device's network situation.
class NetworkStateMessage extends MonitorSignalMessage {
  NetworkStateMessage({
    required this.interfaceType,
    this.deviceIpAddress,
    this.targetAddress,
  });

  InterfaceTypeMessage interfaceType;
  String? deviceIpAddress;
  String? targetAddress;
}

/// The single signal stream.
///
/// Pigeon forbids parameters on event-channel methods and requires them all
/// to live in one class, so configuration travels via [MonitoringHostApi]
/// instead and the two signal kinds share one channel through a sealed
/// union.
@EventChannelApi()
abstract class MonitoringEventApi {
  MonitorSignalMessage streamMonitorSignals();
}
