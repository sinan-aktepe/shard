import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/shard_test.dart';

class _OkShard extends FutureShard<int> {
  _OkShard({required this.fake, this.value = 42, this.cacheKeyOverride});

  final FakeCacheService fake;
  final int value;
  final String? cacheKeyOverride;
  int buildCount = 0;

  @override
  CacheService get cacheService => fake;

  @override
  String get cacheKey => cacheKeyOverride ?? super.cacheKey;

  @override
  Future<int> build() async {
    buildCount++;
    return value;
  }
}

class _NoCacheShard extends _OkShard {
  _NoCacheShard({required super.fake}) : super(value: 7);

  @override
  bool get allowCache => false;
}

class _ErrShard extends FutureShard<int> {
  _ErrShard({required this.fake});
  final FakeCacheService fake;

  @override
  CacheService get cacheService => fake;

  @override
  Future<int> build() async {
    throw StateError('build failed');
  }
}

void main() {
  setUp(() {
    Shard.observer = null;
  });

  test('onInit emits Loading then Data', () async {
    final shard = _OkShard(fake: FakeCacheService());
    final tester = ShardTester(shard);
    addTearDown(tester.dispose);
    addTearDown(shard.dispose);

    shard.onInit();

    await tester.expectStates([
      AsyncData<int>(42),
    ], timeout: const Duration(seconds: 1));
    expect(shard.buildCount, 1);
  });

  test('build error emits AsyncError', () async {
    final shard = _ErrShard(fake: FakeCacheService());
    final tester = ShardTester(shard);
    addTearDown(tester.dispose);
    addTearDown(shard.dispose);

    shard.onInit();

    await tester.waitFor((s) => s is AsyncError<int>);
    expect(tester.lastState, isA<AsyncError<int>>());
  });

  test('cached value short-circuits build', () async {
    final cache = FakeCacheService()..seed('_OkShard', 99);
    final shard = _OkShard(fake: cache);
    final tester = ShardTester(shard);
    addTearDown(tester.dispose);
    addTearDown(shard.dispose);

    shard.onInit();

    await tester.expectStates([AsyncData<int>(99)]);
    expect(shard.buildCount, 0);
  });

  test('expired cache forces refetch', () async {
    final cache = FakeCacheService()..seedExpired('_OkShard', 99);
    final shard = _OkShard(fake: cache);
    final tester = ShardTester(shard);
    addTearDown(tester.dispose);
    addTearDown(shard.dispose);

    shard.onInit();

    await tester.expectStates([AsyncData<int>(42)]);
    expect(shard.buildCount, 1);
  });

  test('allowCache: false bypasses cache layer', () async {
    final cache = FakeCacheService()..seed('_NoCacheShard', 99);
    final shard = _NoCacheShard(fake: cache);
    final tester = ShardTester(shard);
    addTearDown(tester.dispose);
    addTearDown(shard.dispose);

    shard.onInit();

    await tester.expectStates([AsyncData<int>(7)]);
    expect(shard.buildCount, 1);
    expect(cache.writeCount, 0);
  });

  test('refresh invalidates cache and re-runs build', () async {
    final cache = FakeCacheService();
    final shard = _OkShard(fake: cache);
    final tester = ShardTester(shard);
    addTearDown(tester.dispose);
    addTearDown(shard.dispose);

    shard.onInit();
    await tester.waitFor((s) => s is AsyncData<int>);
    expect(shard.buildCount, 1);

    tester.clear();
    shard.refresh();
    await tester.waitFor((s) => s is AsyncData<int>);
    expect(shard.buildCount, 2);
    expect(cache.deleteCount, 1);
  });

  test('cacheKey override is used', () async {
    final cache = FakeCacheService()..seed('custom_key', 123);
    final shard = _OkShard(fake: cache, cacheKeyOverride: 'custom_key');
    final tester = ShardTester(shard);
    addTearDown(tester.dispose);
    addTearDown(shard.dispose);

    shard.onInit();
    await tester.expectStates([AsyncData<int>(123)]);
    expect(shard.buildCount, 0);
  });
}
