import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

void main() {
  group('AsyncLoading', () {
    test('default equals default', () {
      expect(AsyncLoading<int>(), AsyncLoading<int>());
    });

    test('with same previousData are equal', () {
      expect(
        AsyncLoading<int>(previousData: 42),
        AsyncLoading<int>(previousData: 42),
      );
    });

    test('with different previousData are not equal', () {
      expect(
        AsyncLoading<int>(previousData: 1) == AsyncLoading<int>(previousData: 2),
        isFalse,
      );
    });

    test('isLoading is true, others false', () {
      const v = AsyncLoading<int>();
      expect(v.isLoading, isTrue);
      expect(v.hasData, isFalse);
      expect(v.hasError, isFalse);
    });

    test('dataOrNull is previousData', () {
      expect(AsyncLoading<int>().dataOrNull, isNull);
      expect(AsyncLoading<int>(previousData: 9).dataOrNull, 9);
    });

    test('errorOrNull and stackTraceOrNull are null', () {
      const v = AsyncLoading<int>(previousData: 9);
      expect(v.errorOrNull, isNull);
      expect(v.stackTraceOrNull, isNull);
    });
  });

  group('AsyncData', () {
    test('with same data are equal', () {
      expect(AsyncData<int>(42), AsyncData<int>(42));
    });

    test('with different data are not equal', () {
      expect(AsyncData<int>(1) == AsyncData<int>(2), isFalse);
    });

    test('hasData is true, others false', () {
      const v = AsyncData<int>(7);
      expect(v.hasData, isTrue);
      expect(v.isLoading, isFalse);
      expect(v.hasError, isFalse);
    });

    test('dataOrNull is the data', () {
      expect(AsyncData<int>(7).dataOrNull, 7);
    });
  });

  group('AsyncError', () {
    test('with same error and previousData are equal', () {
      final err = Exception('boom');
      expect(
        AsyncError<int>(err, null, 5),
        AsyncError<int>(err, null, 5),
      );
    });

    test('with different errors are not equal', () {
      expect(
        AsyncError<int>(Exception('a'), null, 1) ==
            AsyncError<int>(Exception('b'), null, 1),
        isFalse,
      );
    });

    test('hasError is true, others false', () {
      final v = AsyncError<int>(Exception('x'));
      expect(v.hasError, isTrue);
      expect(v.isLoading, isFalse);
      expect(v.hasData, isFalse);
    });

    test('dataOrNull is previousData', () {
      expect(AsyncError<int>(Exception('x'), null, 9).dataOrNull, 9);
      expect(AsyncError<int>(Exception('x')).dataOrNull, isNull);
    });

    test('errorOrNull is the error', () {
      final err = Exception('boom');
      expect(AsyncError<int>(err).errorOrNull, same(err));
    });

    test('stackTraceOrNull is the stack trace', () {
      final st = StackTrace.current;
      expect(AsyncError<int>(Exception('x'), st).stackTraceOrNull, same(st));
    });
  });

  group('AsyncIdle', () {
    test('isIdle is true, others false', () {
      const v = AsyncIdle<int>();
      expect(v.isIdle, isTrue);
      expect(v.isLoading, isFalse);
      expect(v.hasData, isFalse);
      expect(v.hasError, isFalse);
    });

    test('two AsyncIdle of the same type are equal', () {
      expect(const AsyncIdle<int>(), const AsyncIdle<int>());
    });

    test('dataOrNull is null', () {
      expect(const AsyncIdle<int>().dataOrNull, isNull);
    });

    test('errorOrNull and stackTraceOrNull are null', () {
      const v = AsyncIdle<int>();
      expect(v.errorOrNull, isNull);
      expect(v.stackTraceOrNull, isNull);
    });
  });

  test('isIdle is false for the other variants', () {
    expect(const AsyncLoading<int>().isIdle, isFalse);
    expect(const AsyncData<int>(1).isIdle, isFalse);
    expect(const AsyncError<int>('e').isIdle, isFalse);
  });
}
