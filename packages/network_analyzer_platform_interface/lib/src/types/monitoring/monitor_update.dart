/// The combined view over a session's measurements and events.
library;

import 'package:meta/meta.dart';
import 'package:network_analyzer_platform_interface/src/types/monitoring/connection_metrics.dart';
import 'package:network_analyzer_platform_interface/src/types/monitoring/monitor_event.dart';
import 'package:network_analyzer_platform_interface/src/types/monitoring/session_data.dart';

/// Anything new from a monitoring session.
///
/// Sealed so a host application can switch over it exhaustively with no
/// default branch — the compiler, rather than a comment, guarantees both
/// cases are handled.
///
/// ```dart
/// switch (update) {
///   case MetricsUpdate(:final ConnectionMetrics metrics):
///     render(metrics);
///   case EventUpdate(:final MonitorEvent event):
///     log(event.message);
/// }
/// ```
sealed class MonitorUpdate {
  const MonitorUpdate._(this.session);

  /// The facts about the session that produced this update.
  final SessionData session;
}

/// A measurement arrived.
@immutable
final class MetricsUpdate extends MonitorUpdate {
  /// Wraps [metrics] for the combined stream.
  MetricsUpdate(this.metrics) : super._(metrics.session);

  /// The measurement.
  final ConnectionMetrics metrics;

  @override
  bool operator ==(Object other) =>
      other is MetricsUpdate && other.metrics == metrics;

  @override
  int get hashCode => metrics.hashCode;

  @override
  String toString() => 'MetricsUpdate($metrics)';
}

/// An event occurred.
@immutable
final class EventUpdate extends MonitorUpdate {
  /// Wraps [event] for the combined stream.
  EventUpdate(this.event) : super._(event.session);

  /// The event.
  final MonitorEvent event;

  @override
  bool operator ==(Object other) =>
      other is EventUpdate && other.event == event;

  @override
  int get hashCode => event.hashCode;

  @override
  String toString() => 'EventUpdate($event)';
}
