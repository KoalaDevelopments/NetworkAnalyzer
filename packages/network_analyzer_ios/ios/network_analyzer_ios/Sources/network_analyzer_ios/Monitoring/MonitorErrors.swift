import Foundation

/// The error codes the native side raises across the channel.
///
/// The Dart platform implementation maps each to a typed `Failure`, so no
/// `PlatformException` ever reaches a host application (constitution,
/// Principle III). Kept in one place because both platforms must agree.
enum MonitorErrors {
  static let permissionDenied = "PERMISSION_DENIED"
  static let unsupportedCapability = "UNSUPPORTED_CAPABILITY"
  static let gatewayDiscoveryFailed = "GATEWAY_DISCOVERY_FAILED"
  static let invalidConfiguration = "INVALID_CONFIGURATION"
  static let targetUnreachable = "TARGET_UNREACHABLE"
  static let sessionAlreadyRunning = "SESSION_ALREADY_RUNNING"
}
