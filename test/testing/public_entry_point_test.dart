import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/shard_test.dart';

class _CounterShard extends Shard<int> {
  _CounterShard() : super(0);
  void inc() => emit(state + 1);
}

void main() {
  test('public entry point exposes all utilities', () async {
    final shard = _CounterShard();
    final tester = ShardTester(shard);
    final storage = FakeStateStorage();
    final cache = FakeCacheService();

    await MockShardObserver.scope((observer) async {
      shard.inc();
      await tester.expectStates([1]);
      await storage.save('k', 'v');
      cache.seed('k', 1);
      expect(observer.recordedChanges, hasLength(1));
    });

    await tester.dispose();
    shard.dispose();
  });

  test('shardTest helper is exported', () async {
    await shardTest<_CounterShard, int>(
      build: () => _CounterShard(),
      act: (s) async => s.inc(),
      expect: [1],
    );
  });
}
