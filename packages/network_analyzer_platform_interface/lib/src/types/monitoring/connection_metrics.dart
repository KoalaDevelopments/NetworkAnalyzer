import 'package:meta/meta.dart';
import 'package:network_analyzer_platform_interface/src/types/monitoring/connection_health.dart';
import 'package:network_analyzer_platform_interface/src/types/monitoring/session_data.dart';

/// One snapshot of connection quality.
///
/// Some values reflect only the rolling window and therefore recover once
/// conditions improve — [packetLossPercent], [jitter] and [health]. The rest
/// span the whole session and never reset while it runs: [spikeCount],
/// [uptime] and the three latency aggregates.
///
/// A value that cannot yet be computed is `null`, never zero. Reporting 0 ms
/// of jitter before two samples exist would be a measurement the plugin did
/// not make.
///
/// Latency and jitter are rounded to 0.1 ms and packet loss to 0.1%.
@immutable
final class ConnectionMetrics {
  /// Creates a measurement snapshot.
  const ConnectionMetrics({
    required this.session,
    required this.packetLossPercent,
    required this.spikeCount,
    required this.health,
    required this.uptime,
    this.latency,
    this.jitter,
    this.averageLatency,
    this.lowestLatency,
    this.highestLatency,
  });

  /// The facts about the session that produced this measurement.
  final SessionData session;

  /// The most recent probe's round-trip time, or `null` when it failed.
  final Duration? latency;

  /// Percentage of probes lost within the rolling window.
  final double packetLossPercent;

  /// Mean absolute difference between consecutive successful samples in the
  /// window, or `null` before two of them exist.
  final Duration? jitter;

  /// Latency spikes observed since the session started.
  final int spikeCount;

  /// The overall verdict on connection quality.
  final ConnectionHealth health;

  /// How long the session has been running, measured monotonically.
  final Duration uptime;

  /// Mean round-trip time across every successful probe in the session.
  final Duration? averageLatency;

  /// The fastest round-trip time seen in the session.
  final Duration? lowestLatency;

  /// The slowest round-trip time seen in the session.
  final Duration? highestLatency;

  @override
  bool operator ==(Object other) =>
      other is ConnectionMetrics &&
      other.session == session &&
      other.latency == latency &&
      other.packetLossPercent == packetLossPercent &&
      other.jitter == jitter &&
      other.spikeCount == spikeCount &&
      other.health == health &&
      other.uptime == uptime &&
      other.averageLatency == averageLatency &&
      other.lowestLatency == lowestLatency &&
      other.highestLatency == highestLatency;

  @override
  int get hashCode => Object.hash(
    session,
    latency,
    packetLossPercent,
    jitter,
    spikeCount,
    health,
    uptime,
    averageLatency,
    lowestLatency,
    highestLatency,
  );

  @override
  String toString() =>
      'ConnectionMetrics(${health.name}, latency: $latency, '
      'loss: $packetLossPercent%, jitter: $jitter, spikes: $spikeCount)';
}
