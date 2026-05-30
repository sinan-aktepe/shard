import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/src/testing/shard_tester.dart';

class _CounterShard extends Shard<int> {
  _CounterShard() : super(0);
  void inc() => emit(state + 1);
  void incTwice() {
    emit(state + 1);
    emit(state + 1);
  }
}

void main() {
  group('shardTest helper', () {
    test('build → expect with no act', () async {
      await shardTest<_CounterShard, int>(
        build: () => _CounterShard(),
        expect: [],
      );
    });

    test('build → act → expect single emit', () async {
      await shardTest<_CounterShard, int>(
        build: () => _CounterShard(),
        act: (s) async => s.inc(),
        expect: [1],
      );
    });

    test('build → act → expect multiple emits', () async {
      await shardTest<_CounterShard, int>(
        build: () => _CounterShard(),
        act: (s) async => s.incTwice(),
        expect: [1, 2],
      );
    });

    test('mismatch surfaces as ShardAssertionError', () async {
      await expectLater(
        shardTest<_CounterShard, int>(
          build: () => _CounterShard(),
          act: (s) async => s.inc(),
          expect: [99],
        ),
        throwsA(isA<ShardAssertionError>()),
      );
    });
  });
}
