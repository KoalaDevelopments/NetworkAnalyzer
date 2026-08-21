part of 'result.dart';

/// A generic success carrying a value of type [T].
abstract interface class Success<T> {
  /// Wraps [value] as a [Success].
  const factory Success(T value) = _Success<T>;

  /// The value produced by the successful operation.
  T get value;
}

final class _Success<T> implements Success<T> {
  const _Success(this.value);

  @override
  final T value;
}

/// Specialization for operations that return nothing.
final class VoidSuccess implements Success<void> {
  /// Creates a [VoidSuccess].
  const VoidSuccess();

  @override
  void get value => {};
}
