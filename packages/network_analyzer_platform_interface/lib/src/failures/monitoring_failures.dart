import 'package:network_analyzer_platform_interface/src/core/result/result.dart';

/// Formats a failure the same way across the monitoring domain.
String _describe(String type, String message, String? details) =>
    details == null ? '$type: $message' : '$type: $message ($details)';

/// Raised when an operating system permission the plugin needs is denied.
///
/// Carries [remediation] so the host application can tell the user what to
/// do rather than only that something failed.
final class PermissionFailure implements Failure {
  /// Creates a [PermissionFailure].
  const PermissionFailure({
    required this.message,
    this.details,
    this.remediation,
  });

  @override
  final String message;

  @override
  final String? details;

  /// What the user or host application can do to resolve the denial.
  final String? remediation;

  @override
  String toString() => _describe('PermissionFailure', message, details);
}

/// Raised when the platform cannot honor a requested capability.
///
/// The plugin never substitutes a different protocol or strategy to work
/// around a limit — a degraded result that looks like a real one is worse
/// than an honest failure (constitution, Security section).
final class UnsupportedCapabilityFailure implements Failure {
  /// Creates an [UnsupportedCapabilityFailure].
  const UnsupportedCapabilityFailure({required this.message, this.details});

  @override
  final String message;

  @override
  final String? details;

  @override
  String toString() =>
      _describe('UnsupportedCapabilityFailure', message, details);
}

/// Raised when the current network exposes no default route to discover.
final class GatewayDiscoveryFailure implements Failure {
  /// Creates a [GatewayDiscoveryFailure].
  const GatewayDiscoveryFailure({required this.message, this.details});

  @override
  final String message;

  @override
  final String? details;

  @override
  String toString() => _describe('GatewayDiscoveryFailure', message, details);
}

/// Raised when a monitor configuration reaching the platform is invalid.
///
/// Host code that builds a configuration gets an [ArgumentError] at
/// construction instead; this failure covers the platform-side revalidation
/// that never trusts its caller.
final class InvalidConfigurationFailure implements Failure {
  /// Creates an [InvalidConfigurationFailure].
  const InvalidConfigurationFailure({required this.message, this.details});

  @override
  final String message;

  @override
  final String? details;

  @override
  String toString() =>
      _describe('InvalidConfigurationFailure', message, details);
}

/// Raised when the monitoring target cannot be reached at all.
final class TargetUnreachableFailure implements Failure {
  /// Creates a [TargetUnreachableFailure].
  const TargetUnreachableFailure({required this.message, this.details});

  @override
  final String message;

  @override
  final String? details;

  @override
  String toString() => _describe('TargetUnreachableFailure', message, details);
}

/// Raised when an operation exceeds its documented timeout.
///
/// Named for probes specifically so the shorter `TimeoutFailure` stays
/// available to the diagnostic tools domain, which needs its own.
final class ProbeTimeoutFailure implements Failure {
  /// Creates a [ProbeTimeoutFailure].
  const ProbeTimeoutFailure({required this.message, this.details});

  @override
  final String message;

  @override
  final String? details;

  @override
  String toString() => _describe('ProbeTimeoutFailure', message, details);
}

/// Raised when monitoring is started while a session is already running.
///
/// The running session is never disturbed by the rejected request.
final class SessionAlreadyRunningFailure implements Failure {
  /// Creates a [SessionAlreadyRunningFailure].
  const SessionAlreadyRunningFailure({required this.message, this.details});

  @override
  final String message;

  @override
  final String? details;

  @override
  String toString() =>
      _describe('SessionAlreadyRunningFailure', message, details);
}

/// Raised when session facts are requested and no session is running.
///
/// Reported explicitly rather than answered with a fabricated session.
final class NoActiveSessionFailure implements Failure {
  /// Creates a [NoActiveSessionFailure].
  const NoActiveSessionFailure({required this.message, this.details});

  @override
  final String message;

  @override
  final String? details;

  @override
  String toString() => _describe('NoActiveSessionFailure', message, details);
}
