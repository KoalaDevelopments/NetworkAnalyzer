import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';

void main() {
  const Failure testFailure = Failure(message: 'boom', details: 'wire down');

  group('Result.success', () {
    const Result<int, Failure> result = Result.success(42);

    test('reports isSuccess and not isFailure', () {
      check(result.isSuccess).isTrue();
      check(result.isFailure).isFalse();
    });

    test('fold invokes the onSuccess callback', () {
      final String folded = result.fold(
        onFailure: (Failure failure) => 'failure:${failure.message}',
        onSuccess: (Success<int> success) => 'success:${success.value}',
      );
      check(folded).equals('success:42');
    });

    test('tryFold returns the mapped value', () {
      final int? value = result.tryFold(
        onSuccess: (Success<int> success) => success.value,
      );
      check(value).equals(42);
    });

    test('success accessor exposes the value', () {
      check(result.success.value).equals(42);
    });

    test('failure accessor throws NotFailureException', () {
      check(() => result.failure).throws<NotFailureException>();
    });
  });

  group('Result.failure', () {
    const Result<int, Failure> result = Result.failure(testFailure);

    test('reports isFailure and not isSuccess', () {
      check(result.isFailure).isTrue();
      check(result.isSuccess).isFalse();
    });

    test('fold invokes the onFailure callback', () {
      final String folded = result.fold(
        onFailure: (Failure failure) => 'failure:${failure.message}',
        onSuccess: (Success<int> success) => 'success:${success.value}',
      );
      check(folded).equals('failure:boom');
    });

    test('tryFold returns null without invoking onSuccess', () {
      var invoked = false;
      final int? value = result.tryFold(
        onSuccess: (Success<int> success) {
          invoked = true;
          return success.value;
        },
      );
      check(value).isNull();
      check(invoked).isFalse();
    });

    test('failure accessor exposes the failure', () {
      check(result.failure.message).equals('boom');
      check(result.failure.details).equals('wire down');
    });

    test('success accessor throws NotSuccessException', () {
      check(() => result.success).throws<NotSuccessException>();
    });
  });

  group('Failure', () {
    test('default implementation formats toString with details', () {
      check(testFailure.toString()).equals('Failure: boom (wire down)');
    });

    test('default implementation formats toString without details', () {
      const Failure failure = Failure(message: 'boom');
      check(failure.toString()).equals('Failure: boom');
    });
  });

  group('VoidSuccess', () {
    test('is a Success<void>', () {
      const VoidSuccess success = VoidSuccess();
      check(success).isA<Success<void>>();
    });
  });
}
