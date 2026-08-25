/// The raw input a platform implementation produces.
library;

import 'package:meta/meta.dart';
import 'package:network_analyzer_platform_interface/src/types/monitoring/network_interface_type.dart';

/// Something a platform implementation observed.
///
/// This is the plugin's internal boundary, exposed so the metrics engine can
/// be driven from fixed fixtures in tests without a platform channel. Host
/// applications consume the derived measurements instead.
///
/// Native code decides only what native must decide — a round-trip time, an
/// interface type, an address. Everything derived from these is computed
/// once in Dart, which is what keeps Android and iOS from drifting apart.
sealed class MonitorSignal {
  const MonitorSignal._();
}

/// How a single probe ended.
enum ProbeOutcome {
  /// The target answered within the timeout.
  success,

  /// The target did not answer within the timeout.
  timeout,

  /// The target could not be reached at all.
  unreachable,

  /// The probe could not be completed for another reason.
  error,
}

/// The result of one probe.
@immutable
final class ProbeSample extends MonitorSignal {
  /// Creates a probe sample.
  ///
  /// Throws an [ArgumentError] when [sequence] is negative, or when
  /// [roundTrip] does not agree with [outcome] — a successful probe always
  /// has a round-trip time and a failed one never does. A failed probe is
  /// still a sample, never a skipped emission, because losses are what
  /// packet loss is counted from.
  ProbeSample({
    required this.sequence,
    required this.outcome,
    required this.sinceSessionStart,
    this.roundTrip,
  }) : super._() {
    if (sequence < 0) {
      throw ArgumentError.value(sequence, 'sequence', 'must not be negative');
    }
    if (outcome == ProbeOutcome.success && roundTrip == null) {
      throw ArgumentError.value(
        roundTrip,
        'roundTrip',
        'a successful probe must report a round-trip time',
      );
    }
    if (outcome != ProbeOutcome.success && roundTrip != null) {
      throw ArgumentError.value(
        roundTrip,
        'roundTrip',
        'only a successful probe may report a round-trip time',
      );
    }
  }

  /// The probe's position in the session, counting from zero.
  final int sequence;

  /// How the probe ended.
  final ProbeOutcome outcome;

  /// Monotonic time elapsed since the session started.
  final Duration sinceSessionStart;

  /// How long the target took to answer, or `null` when it did not.
  final Duration? roundTrip;

  /// Whether the target answered.
  bool get isSuccess => outcome == ProbeOutcome.success;

  @override
  bool operator ==(Object other) =>
      other is ProbeSample &&
      other.sequence == sequence &&
      other.outcome == outcome &&
      other.sinceSessionStart == sinceSessionStart &&
      other.roundTrip == roundTrip;

  @override
  int get hashCode =>
      Object.hash(sequence, outcome, sinceSessionStart, roundTrip);

  @override
  String toString() =>
      'ProbeSample(#$sequence ${outcome.name}${roundTrip == null ? '' : ' '
                'in $roundTrip'})';
}

/// A change in the device's network situation, observed mid-session.
@immutable
final class NetworkStateChange extends MonitorSignal {
  /// Creates a network state change.
  ///
  /// A `null` address means that fact did not change; only the fields that
  /// actually moved are reported.
  const NetworkStateChange({
    required this.interfaceType,
    this.deviceIpAddress,
    this.targetAddress,
  }) : super._();

  /// The interface the device is now using.
  final NetworkInterfaceType interfaceType;

  /// The device's new address, when it changed.
  final String? deviceIpAddress;

  /// The endpoint now being probed, when it changed.
  final String? targetAddress;

  @override
  bool operator ==(Object other) =>
      other is NetworkStateChange &&
      other.interfaceType == interfaceType &&
      other.deviceIpAddress == deviceIpAddress &&
      other.targetAddress == targetAddress;

  @override
  int get hashCode =>
      Object.hash(interfaceType, deviceIpAddress, targetAddress);

  @override
  String toString() => 'NetworkStateChange(${interfaceType.name})';
}
