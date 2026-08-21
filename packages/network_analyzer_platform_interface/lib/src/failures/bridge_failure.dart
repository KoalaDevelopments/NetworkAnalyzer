import 'package:network_analyzer_platform_interface/src/core/result/result.dart';

/// Failure raised when the native bridge cannot service a request.
///
/// Platform implementations map native errors (e.g. a `PlatformException`)
/// into this type instead of letting them escape to the caller
/// (constitution, Principle III).
final class BridgeFailure implements Failure {
  /// Creates a [BridgeFailure] with a [message] and optional [details].
  const BridgeFailure({required this.message, this.details});

  @override
  final String message;

  @override
  final String? details;

  @override
  String toString() => details == null
      ? 'BridgeFailure: $message'
      : 'BridgeFailure: $message ($details)';
}
