part of 'result.dart';

/// Higher-order abstraction for failures. Implementers must expose a brief
/// [message] and, optionally, longer [details].
///
/// Define custom [Failure] subtypes per domain instead of reusing the
/// default implementation everywhere.
abstract interface class Failure implements Exception {
  /// Creates a generic [Failure] with a [message] and optional [details].
  const factory Failure({required String message, String? details}) = _Failure;

  /// A brief, human-readable description of what went wrong.
  String get message;

  /// Optional longer diagnostic details, e.g. the underlying error text.
  String? get details;
}

final class _Failure implements Failure {
  const _Failure({required this.message, this.details});

  @override
  final String message;

  @override
  final String? details;

  @override
  String toString() =>
      details == null ? 'Failure: $message' : 'Failure: $message ($details)';
}
