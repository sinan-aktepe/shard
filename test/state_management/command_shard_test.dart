import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/shard_test.dart';

void main() {
  group('CommandShard', () {
    test('starts idle', () {
      final c = CommandShard<int, int>((a) async => a + 1);
      addTearDown(c.dispose);
      expect(c.state, isA<AsyncIdle<int>>());
      expect(c.isRunning, isFalse);
      expect(c.valueOrNull, isNull);
    });

    test('execute emits loading then data and returns the value', () async {
      final c = CommandShard<int, int>((a) async => a + 1);
      addTearDown(c.dispose);
      final tester = ShardTester<AsyncValue<int>>(c);
      final result = await c.execute(41);
      expect(result, 42);
      expect(c.state, const AsyncData<int>(42));
      expect(c.valueOrNull, 42);
      await tester.expectStates([
        const AsyncLoading<int>(),
        const AsyncData<int>(42),
      ]);
    });

    test(
      'failure routes through addError, emits AsyncError, returns null',
      () async {
        await MockShardObserver.scope((observer) async {
          final err = Exception('boom');
          final c = CommandShard<int, int>((a) async => throw err);
          addTearDown(c.dispose);
          final result = await c.execute(1);
          expect(result, isNull);
          expect(c.state, isA<AsyncError<int>>());
          expect((c.state as AsyncError<int>).error, same(err));
          expect(observer.errorsFor(c), hasLength(1));
          expect(observer.errorsFor(c).single.error, same(err));
        });
      },
    );

    test('double-submit while running is ignored (action runs once)', () async {
      var calls = 0;
      final gate = Completer<int>();
      final c = CommandShard<void, int>((_) async {
        calls++;
        return gate.future;
      });
      addTearDown(c.dispose);
      final first = c.execute(null);
      final second = await c.execute(null);
      expect(second, isNull);
      expect(c.isRunning, isTrue);
      gate.complete(7);
      expect(await first, 7);
      expect(calls, 1);
    });

    test('reset returns to idle', () async {
      final c = CommandShard<int, int>((a) async => a);
      addTearDown(c.dispose);
      await c.execute(5);
      expect(c.state, const AsyncData<int>(5));
      c.reset();
      expect(c.state, isA<AsyncIdle<int>>());
    });

    test(
      're-run carries previous result as previousData on loading/error',
      () async {
        var fail = false;
        final err = Exception('second-run boom');
        final c = CommandShard<int, int>((a) async {
          if (fail) throw err;
          return a;
        });
        addTearDown(c.dispose);

        await c.execute(10);
        expect(c.state, const AsyncData<int>(10));

        // Second run fails; loading and the resulting error should retain 10.
        fail = true;
        final tester = ShardTester<AsyncValue<int>>(c);
        final result = await c.execute(20);
        expect(result, isNull);
        await tester.expectStates([const AsyncLoading<int>(previousData: 10)]);
        expect(c.state, isA<AsyncError<int>>());
        expect((c.state as AsyncError<int>).previousData, 10);
      },
    );

    test('dispose mid-run does not emit after dispose', () async {
      final gate = Completer<int>();
      final c = CommandShard<void, int>((_) async => gate.future);
      final future = c.execute(null);
      expect(c.isRunning, isTrue);
      c.dispose();
      gate.complete(99);
      expect(await future, isNull);
    });
  });
}
