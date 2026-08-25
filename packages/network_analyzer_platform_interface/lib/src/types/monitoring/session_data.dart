import 'package:meta/meta.dart';
import 'package:network_analyzer_platform_interface/src/types/monitoring/monitor_kind.dart';
import 'package:network_analyzer_platform_interface/src/types/monitoring/monitor_protocol.dart';
import 'package:network_analyzer_platform_interface/src/types/monitoring/network_interface_type.dart';

/// The facts about a running monitoring session.
///
/// Attached to every measurement and every event, so any single item a host
/// application holds is self-describing — it never has to correlate an
/// emission back to the session that produced it.
///
/// [deviceIpAddress] and [targetAddress] are deliberately separate: one is
/// where this device sits on the network, the other is what probes are
/// actually sent to.
@immutable
final class SessionData {
  /// Creates the facts describing a session.
  ///
  /// Throws an [ArgumentError] when [startedAt] is not UTC. Only this one
  /// field reads a wall clock, because it is the only one shown to a person;
  /// everything elapsed is measured monotonically so a clock change cannot
  /// distort it.
  SessionData({
    required this.interfaceType,
    required this.protocol,
    required this.kind,
    required this.deviceIpAddress,
    required this.targetAddress,
    required this.targetName,
    required this.startedAt,
  }) {
    if (!startedAt.isUtc) {
      throw ArgumentError.value(startedAt, 'startedAt', 'must be UTC');
    }
  }

  /// The interface the session is running over, updated as it changes.
  final NetworkInterfaceType interfaceType;

  /// How probes are being sent.
  final MonitorProtocol protocol;

  /// Whether this session watches the internet or the local gateway.
  final MonitorKind kind;

  /// This device's address on the current network.
  final String deviceIpAddress;

  /// The endpoint probes are actually sent to.
  final String targetAddress;

  /// A display name for the target.
  final String targetName;

  /// When the session started, in UTC.
  final DateTime startedAt;

  /// Returns a copy with the named fields replaced.
  ///
  /// Used as the session's facts change mid-flight — an interface switch or
  /// a reassigned address — so later emissions report the truth rather than
  /// what was true at start.
  SessionData copyWith({
    NetworkInterfaceType? interfaceType,
    MonitorProtocol? protocol,
    MonitorKind? kind,
    String? deviceIpAddress,
    String? targetAddress,
    String? targetName,
    DateTime? startedAt,
  }) => SessionData(
    interfaceType: interfaceType ?? this.interfaceType,
    protocol: protocol ?? this.protocol,
    kind: kind ?? this.kind,
    deviceIpAddress: deviceIpAddress ?? this.deviceIpAddress,
    targetAddress: targetAddress ?? this.targetAddress,
    targetName: targetName ?? this.targetName,
    startedAt: startedAt ?? this.startedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is SessionData &&
      other.interfaceType == interfaceType &&
      other.protocol == protocol &&
      other.kind == kind &&
      other.deviceIpAddress == deviceIpAddress &&
      other.targetAddress == targetAddress &&
      other.targetName == targetName &&
      other.startedAt == startedAt;

  @override
  int get hashCode => Object.hash(
    interfaceType,
    protocol,
    kind,
    deviceIpAddress,
    targetAddress,
    targetName,
    startedAt,
  );

  @override
  String toString() =>
      'SessionData(${kind.name} via ${protocol.name} to $targetAddress '
      'on ${interfaceType.name})';
}
