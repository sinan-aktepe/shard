import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/src/testing/shard_tester.dart';

class _CounterShard extends Shard<int> {
  _CounterShard() : super(0);
  void inc() => emit(state + 1);
  void setTo(int v) => emit(v);
}

void main() {
  group('ShardTester — waitForNext', () {
    test('returns the next emission', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      Future.delayed(const Duration(milliseconds: 10), shard.inc);
      final state = await tester.waitForNext();
      expect(state, 1);
      await tester.dispose();
      shard.dispose();
    });

    test('throws ShardTimeoutError on timeout', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      await expectLater(
        tester.waitForNext(timeout: const Duration(milliseconds: 30)),
        throwsA(isA<ShardTimeoutError>()),
      );
      await tester.dispose();
      shard.dispose();
    });

    test('does not return historical states', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      shard.inc(); // historical emission, before waitForNext
      Future.delayed(const Duration(milliseconds: 10), shard.inc);
      final state = await tester.waitForNext();
      expect(state, 2); // not 1
      await tester.dispose();
      shard.dispose();
    });
  });

  group('ShardTester — waitFor', () {
    test('returns current shard state if it already matches', () async {
      final shard = _CounterShard();
      shard.setTo(5); // emit before the tester is even created
      final tester = ShardTester(shard);
      final state = await tester.waitFor((s) => s >= 5);
      expect(state, 5);
      await tester.dispose();
      shard.dispose();
    });

    test('waits for matching future emission', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      Future.delayed(const Duration(milliseconds: 10), () => shard.setTo(2));
      Future.delayed(const Duration(milliseconds: 20), () => shard.setTo(7));
      final state = await tester.waitFor((s) => s >= 7);
      expect(state, 7);
      await tester.dispose();
      shard.dispose();
    });

    test('throws ShardTimeoutError when no match within timeout', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      Future.delayed(const Duration(milliseconds: 10), shard.inc);
      await expectLater(
        tester.waitFor(
          (s) => s > 100,
          timeout: const Duration(milliseconds: 30),
        ),
        throwsA(isA<ShardTimeoutError>()),
      );
      await tester.dispose();
      shard.dispose();
    });
  });
}
