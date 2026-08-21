/// The functional result core mandated by guidelines.md.
///
/// Every fallible public operation in the plugin returns a
/// [Result] instead of letting exceptions escape to the caller
/// (constitution, Principle III). This implementation is canonical: it must
/// not be replaced by third-party alternatives such as `dartz` or `fpdart`.
library;

part 'failure.dart';
part 'success.dart';

/// A callback function that takes a result and returns a value.
typedef ResultCallback<T, R> = T Function(R result);

/// Represents an operation that may either succeed or fail.
abstract interface class Result<T, S extends Failure> {
  /// Creates a failed [Result] carrying [failure].
  const factory Result.failure(S failure) = _FailureResult<T, S>;

  /// Creates a successful [Result] carrying [value].
  const factory Result.success(T value) = _SuccessResult<T, S>;

  /// Deconstructs the [Result] using the provided callbacks.
  R fold<R>({
    required ResultCallback<R, S> onFailure,
    required ResultCallback<R, Success<T>> onSuccess,
  });

  /// Deconstructs the [Result], returning the value if successful, or `null`
  /// if the operation fails.
  T? tryFold({required ResultCallback<T?, Success<T>> onSuccess});

  /// Whether this result represents a failed operation.
  bool get isFailure;

  /// Whether this result represents a successful operation.
  bool get isSuccess;

  /// Throws [NotFailureException] if the [Result] is a success.
  S get failure;

  /// Throws [NotSuccessException] if the [Result] is a failure.
  Success<T> get success;
}

final class _FailureResult<T, S extends Failure> implements Result<T, S> {
  const _FailureResult(this._failure);

  final S _failure;

  @override
  R fold<R>({
    required ResultCallback<R, S> onFailure,
    required ResultCallback<R, Success<T>> onSuccess,
  }) => onFailure(_failure);

  @override
  T? tryFold({required ResultCallback<T?, Success<T>> onSuccess}) => null;

  @override
  bool get isFailure => true;

  @override
  bool get isSuccess => false;

  @override
  S get failure => _failure;

  @override
  Success<T> get success => throw const NotSuccessException();
}

final class _SuccessResult<T, S extends Failure> implements Result<T, S> {
  const _SuccessResult(this._value);

  final T _value;

  @override
  R fold<R>({
    required ResultCallback<R, S> onFailure,
    required ResultCallback<R, Success<T>> onSuccess,
  }) => onSuccess(Success<T>(_value));

  @override
  T? tryFold({required ResultCallback<T?, Success<T>> onSuccess}) =>
      onSuccess(Success<T>(_value));

  @override
  bool get isFailure => false;

  @override
  bool get isSuccess => true;

  @override
  S get failure => throw const NotFailureException();

  @override
  Success<T> get success => Success<T>(_value);
}

/// Thrown when [Result.failure] is accessed on a successful result.
final class NotFailureException implements Exception {
  /// Creates the exception.
  const NotFailureException();

  @override
  String toString() => 'NotFailureException: the Result is a success.';
}

/// Thrown when [Result.success] is accessed on a failed result.
final class NotSuccessException implements Exception {
  /// Creates the exception.
  const NotSuccessException();

  @override
  String toString() => 'NotSuccessException: the Result is a failure.';
}
