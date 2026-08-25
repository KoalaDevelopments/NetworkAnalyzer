/// Mapping from native error codes to typed failures.
///
/// A raw `PlatformException` reaching a caller is a defect (constitution,
/// Principle III), so every code the native side can raise has a typed
/// counterpart here. The codes themselves are declared once per platform in
/// `MonitorErrors`, and both platforms use the same strings.
library;

import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';

/// Turns [error] into the typed failure its code names.
///
/// [operation] is used only for the log entry, so a failure is traceable to
/// the call that produced it. An unrecognized code becomes a
/// [TargetUnreachableFailure] rather than being rethrown: an unmapped native
/// error is still a failure the caller must handle, never an exception the
/// caller must catch.
Failure mapPlatformException(PlatformException error, String operation) {
  developer.log(
    '$operation failed',
    name: 'network_analyzer',
    level: 1000,
    error: error,
  );
  final String message = error.message ?? 'The native side reported an error.';
  final String? details = error.details?.toString();
  return switch (error.code) {
    'PERMISSION_DENIED' => PermissionFailure(
      message: message,
      details: details,
      remediation:
          'Grant the permission the platform requires to inspect the '
          'network, then start monitoring again.',
    ),
    'UNSUPPORTED_CAPABILITY' => UnsupportedCapabilityFailure(
      message: message,
      details: details,
    ),
    'GATEWAY_DISCOVERY_FAILED' => GatewayDiscoveryFailure(
      message: message,
      details: details,
    ),
    'INVALID_CONFIGURATION' => InvalidConfigurationFailure(
      message: message,
      details: details,
    ),
    'SESSION_ALREADY_RUNNING' => SessionAlreadyRunningFailure(
      message: message,
      details: details,
    ),
    'TARGET_UNREACHABLE' => TargetUnreachableFailure(
      message: message,
      details: details,
    ),
    _ => TargetUnreachableFailure(
      message: message,
      details: details ?? 'code: ${error.code}',
    ),
  };
}
