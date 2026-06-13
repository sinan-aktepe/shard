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

    test('toString includes the empty constructor parens', () {
      expect(const AsyncIdle<int>().toString(), 'AsyncIdle<int>()');
    });

    test('AsyncIdle of different types are not equal', () {
      expect(
        const AsyncIdle<int>(),
        isNot(equals(const AsyncIdle<String>())),
      );
    });
  });

  test('isIdle is false for the other variants', () {
    expect(const AsyncLoading<int>().isIdle, isFalse);
    expect(const AsyncData<int>(1).isIdle, isFalse);
    expect(const AsyncError<int>('e').isIdle, isFalse);
  });

  group('when', () {
    String label(AsyncValue<int> v) => v.when(
      idle: () => 'idle',
      loading: (prev) => 'loading:$prev',
      data: (d) => 'data:$d',
      error: (e, st, prev) => 'error:$e:$prev',
    );

    test('routes idle', () {
      expect(label(const AsyncIdle<int>()), 'idle');
    });

    test('routes loading with previousData', () {
      expect(label(const AsyncLoading<int>(previousData: 7)), 'loading:7');
    });

    test('routes loading with null previousData', () {
      expect(label(const AsyncLoading<int>()), 'loading:null');
    });

    test('routes data', () {
      expect(label(const AsyncData<int>(42)), 'data:42');
    });

    test('routes error with previousData', () {
      expect(label(const AsyncError<int>('boom', null, 3)), 'error:boom:3');
    });
  });

  group('maybeWhen', () {
    test('falls through to orElse when the matching handler is null', () {
      final r = const AsyncData<int>(1).maybeWhen(
        loading: (_) => 'loading',
        orElse: () => 'else',
      );
      expect(r, 'else');
    });

    test('idle falls through to orElse when idle handler is null', () {
      final r = const AsyncIdle<int>().maybeWhen(
        data: (d) => 'data:$d',
        orElse: () => 'else',
      );
      expect(r, 'else');
    });

    test('uses the matching handler when provided', () {
      final r = const AsyncData<int>(1).maybeWhen(
        data: (d) => 'data:$d',
        orElse: () => 'else',
      );
      expect(r, 'data:1');
    });
  });

  group('mapData', () {
    test('transforms AsyncData', () {
      expect(
        const AsyncData<int>(2).mapData((d) => d * 10),
        const AsyncData<int>(20),
      );
    });

    test('keeps AsyncIdle as AsyncIdle of the new type', () {
      expect(
        const AsyncIdle<int>().mapData((d) => d.toString()),
        const AsyncIdle<String>(),
      );
    });

    test('keeps AsyncLoading, mapping previousData through transform', () {
      expect(
        const AsyncLoading<int>(previousData: 3).mapData((d) => d * 2),
        const AsyncLoading<int>(previousData: 6),
      );
    });

    test('keeps AsyncError, preserving error and mapping previousData', () {
      final mapped = const AsyncError<int>('e', null, 4).mapData((d) => d * 2);
      expect(mapped, isA<AsyncError<int>>());
      expect((mapped as AsyncError<int>).previousData, 8);
    });
  });

  group('whenData', () {
    test('returns f(data) for AsyncData', () {
      expect(const AsyncData<int>(5).whenData((d) => d + 1), 6);
    });

    test('returns null for idle/loading/error', () {
      expect(const AsyncIdle<int>().whenData((d) => d + 1), isNull);
      expect(const AsyncLoading<int>().whenData((d) => d + 1), isNull);
      expect(const AsyncError<int>('e').whenData((d) => d + 1), isNull);
    });
  });

  group('guard', () {
    test('returns AsyncData on success', () async {
      final r = await AsyncValue.guard<int>(() async => 42);
      expect(r, const AsyncData<int>(42));
    });

    test('returns AsyncError on throw, carrying stack and previousData', () async {
      final r = await AsyncValue.guard<int>(
        () async => throw Exception('boom'),
        previousData: 7,
      );
      expect(r, isA<AsyncError<int>>());
      final err = r as AsyncError<int>;
      expect(err.previousData, 7);
      expect(err.stackTrace, isNotNull);
    });
  });
}
