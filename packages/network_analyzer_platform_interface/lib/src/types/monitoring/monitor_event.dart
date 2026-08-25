import 'package:meta/meta.dart';
import 'package:network_analyzer_platform_interface/src/types/monitoring/session_data.dart';

/// What a [MonitorEvent] describes.
///
/// The kinds split into two groups by how they are triggered, which is what
/// makes throttling possible without losing information. Edge-triggered
/// kinds describe a transition and are always emitted; level-triggered kinds
/// describe an ongoing condition and are emitted at most once every 30
/// seconds so a persistent problem cannot flood the stream.
enum MonitorEventKind {
  /// A session started. Always the first event on the stream.
  monitoringStarted,

  /// A session ended.
  monitoringStopped,

  /// The health verdict moved from one level to another.
  healthChanged,

  /// The device lost all connectivity. The session stays alive.
  connectivityLost,

  /// Connectivity returned after being lost.
  connectivityRestored,

  /// The network interface type changed, such as Wi-Fi to mobile data.
  interfaceChanged,

  /// The device's address on the network changed.
  ipAddressChanged,

  /// Probing switched to the target's alternative address.
  targetAddressChanged,

  /// Probes are being lost. Level-triggered.
  packetLossDetected,

  /// Jitter exceeded its threshold. Level-triggered.
  highJitterDetected,

  /// A latency spike occurred. Level-triggered.
  latencySpikeDetected;

  /// Whether this kind describes a transition rather than a condition.
  ///
  /// Edge-triggered kinds are never throttled: they cannot repeat unless
  /// something actually changed, and suppressing one would lose the only
  /// record of that change.
  bool get isEdgeTriggered => switch (this) {
    monitoringStarted ||
    monitoringStopped ||
    healthChanged ||
    connectivityLost ||
    connectivityRestored ||
    interfaceChanged ||
    ipAddressChanged ||
    targetAddressChanged => true,
    packetLossDetected || highJitterDetected || latencySpikeDetected => false,
  };
}

/// One notable moment in a monitoring session.
@immutable
final class MonitorEvent {
  /// Creates an event.
  ///
  /// Throws an [ArgumentError] when [timestamp] is not UTC. Events carry UTC
  /// so the host application can convert to the viewer's local time; a
  /// device that changes time zone mid-session must not reorder its own log.
  MonitorEvent({
    required this.session,
    required this.timestamp,
    required this.kind,
    required this.message,
  }) {
    if (!timestamp.isUtc) {
      throw ArgumentError.value(timestamp, 'timestamp', 'must be UTC');
    }
  }

  /// The facts about the session at the moment of the event.
  final SessionData session;

  /// When it happened, in UTC.
  final DateTime timestamp;

  /// What happened, machine-readable.
  final MonitorEventKind kind;

  /// What happened, in words, including the value that triggered it.
  final String message;

  @override
  bool operator ==(Object other) =>
      other is MonitorEvent &&
      other.session == session &&
      other.timestamp == timestamp &&
      other.kind == kind &&
      other.message == message;

  @override
  int get hashCode => Object.hash(session, timestamp, kind, message);

  @override
  String toString() => 'MonitorEvent(${kind.name}: $message)';
}
