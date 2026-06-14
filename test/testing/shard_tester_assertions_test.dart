import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/src/testing/shard_tester.dart';

class _CounterShard extends Shard<int> {
  _CounterShard() : super(0);
  void inc() => emit(state + 1);
}

void main() {
  group('ShardTester — expectStates', () {
    test('passes on prefix match (default)', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      shard.inc();
      shard.inc();
      shard.inc();
      await tester.expectStates([1, 2]); // extra state allowed
      await tester.dispose();
      shard.dispose();
    });

    test('passes on exact match when exactMatch: true', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      shard.inc();
      shard.inc();
      await tester.expectStates([1, 2], exactMatch: true);
      await tester.dispose();
      shard.dispose();
    });

    test('fails on mismatch with full diff in message', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      shard.inc();
      shard.inc();
      try {
        await tester.expectStates([1, 99]);
        fail('expected ShardAssertionError');
      } on ShardAssertionError catch (e) {
        expect(e.message, contains('[1, 99]'));
        expect(e.message, contains('[1, 2]'));
      }
      await tester.dispose();
      shard.dispose();
    });

    test('fails on exact match when extra states exist', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      shard.inc();
      shard.inc();
      shard.inc();
      await expectLater(
        tester.expectStates([1, 2], exactMatch: true),
        throwsA(isA<ShardAssertionError>()),
      );
      await tester.dispose();
      shard.dispose();
    });

    test('waits up to timeout for expected count', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      Future.delayed(const Duration(milliseconds: 30), shard.inc);
      Future.delayed(const Duration(milliseconds: 60), shard.inc);
      await tester.expectStates([
        1,
        2,
      ], timeout: const Duration(milliseconds: 500));
      await tester.dispose();
      shard.dispose();
    });

    test('fails on timeout with partial states', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      shard.inc();
      await expectLater(
        tester.expectStates([
          1,
          2,
          3,
        ], timeout: const Duration(milliseconds: 50)),
        throwsA(isA<ShardAssertionError>()),
      );
      await tester.dispose();
      shard.dispose();
    });

    test(
      'empty expected with exactMatch: true requires no emissions',
      () async {
        final shard = _CounterShard();
        final tester = ShardTester(shard);
        await tester.expectStates(
          [],
          exactMatch: true,
          timeout: const Duration(milliseconds: 20),
        );
        await tester.dispose();
        shard.dispose();
      },
    );

    test('empty expected with exactMatch: false is vacuously true', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      shard.inc(); // extra state, doesn't matter
      await tester.expectStates([]);
      await tester.dispose();
      shard.dispose();
    });
  });

  group('ShardTester — expectNoMoreStates', () {
    test('passes when no emissions occur within window', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      await tester.expectNoMoreStates(window: const Duration(milliseconds: 30));
      await tester.dispose();
      shard.dispose();
    });

    test('fails when a state arrives within window', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      Future.delayed(const Duration(milliseconds: 10), shard.inc);
      await expectLater(
        tester.expectNoMoreStates(window: const Duration(milliseconds: 50)),
        throwsA(isA<ShardAssertionError>()),
      );
      await tester.dispose();
      shard.dispose();
    });
  });
}
