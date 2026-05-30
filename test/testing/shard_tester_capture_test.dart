import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/src/testing/shard_tester.dart';

class _CounterShard extends Shard<int> {
  _CounterShard() : super(0);
  void inc() => emit(state + 1);
}

void main() {
  group('ShardTester — capture', () {
    test('recordedStates is empty initially', () {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      expect(tester.recordedStates, isEmpty);
      expect(tester.hasStates, isFalse);
      expect(tester.lastState, isNull);
      tester.dispose();
      shard.dispose();
    });

    test('records emissions in order', () {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      shard.inc();
      shard.inc();
      shard.inc();
      expect(tester.recordedStates, [1, 2, 3]);
      expect(tester.hasStates, isTrue);
      expect(tester.lastState, 3);
      tester.dispose();
      shard.dispose();
    });

    test('initial state is excluded', () {
      final shard = _CounterShard();
      // shard.state == 0 here.
      final tester = ShardTester(shard);
      shard.inc();
      expect(tester.recordedStates, [1]);
      tester.dispose();
      shard.dispose();
    });

    test('clear empties recordedStates without unsubscribing', () {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      shard.inc();
      tester.clear();
      shard.inc();
      expect(tester.recordedStates, [2]);
      tester.dispose();
      shard.dispose();
    });

    test('dispose stops further recording', () {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      tester.dispose();
      shard.inc();
      expect(tester.recordedStates, isEmpty);
      shard.dispose();
    });

    test('recordedStates is unmodifiable', () {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      expect(() => tester.recordedStates.add(99), throwsUnsupportedError);
      tester.dispose();
      shard.dispose();
    });

    test('tester.dispose() after shard.dispose() does not throw', () {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      shard.dispose();
      // Should NOT throw, even though ChangeNotifier.removeListener would
      // normally assert after dispose.
      expect(tester.dispose, returnsNormally);
    });

    test('scope creates and disposes tester', () async {
      final shard = _CounterShard();
      final result = await ShardTester.scope<int, int>(shard, (tester) async {
        shard.inc();
        shard.inc();
        return tester.recordedStates.length;
      });
      expect(result, 2);
      shard.dispose();
    });

    test('scope restores even when body throws', () async {
      final shard = _CounterShard();
      await expectLater(
        ShardTester.scope<int, void>(shard, (_) async => throw StateError('x')),
        throwsA(isA<StateError>()),
      );
      // No exception from dispose; shard is still usable.
      shard.inc();
      shard.dispose();
    });
  });
}
