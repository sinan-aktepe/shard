import 'dart:async';

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

class _PendingShard extends FutureShard<int> {
  _PendingShard({required this.fake, required this.completer});
  final FakeCacheService fake;
  final Completer<int> completer;

  @override
  CacheService get cacheService => fake;

  @override
  Future<int> build() => completer.future;
}

/// Builds via a fresh completer each call, so each `build()` invocation can be
/// resolved independently and counted.
class _SlowShard extends FutureShard<int> {
  _SlowShard({required this.fake});
  final FakeCacheService fake;
  int buildCount = 0;
  final List<Completer<int>> completers = [];

  @override
  CacheService get cacheService => fake;

  @override
  Future<int> build() {
    buildCount++;
    final completer = Completer<int>();
    completers.add(completer);
    return completer.future;
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

  test('dispose mid-fetch is safe', () async {
    final completer = Completer<int>();
    final shard = _PendingShard(fake: FakeCacheService(), completer: completer);
    final tester = ShardTester(shard);
    addTearDown(tester.dispose);
    // Note: no addTearDown(shard.dispose) — this test disposes the shard
    // explicitly mid-fetch, and Shard.dispose is not idempotent.

    shard.onInit();
    // build() is awaiting the completer — no emit has happened yet.
    expect(shard.state, isA<AsyncLoading<int>>());
    expect(tester.recordedStates, isEmpty);

    // Dispose while build() is still pending.
    shard.dispose();

    // Late-resolve the build. The isDisposed guard in _fetch must skip the
    // emit; emitting on a disposed ChangeNotifier would throw.
    completer.complete(42);

    await tester.expectNoMoreStates(window: const Duration(milliseconds: 50));
  });

  test(
    'refresh during the initial fetch does not start a second build',
    () async {
      final shard = _SlowShard(fake: FakeCacheService());
      final tester = ShardTester(shard);
      addTearDown(tester.dispose);
      addTearDown(shard.dispose);

      shard.onInit();
      // Let the cache read resolve so build() is invoked exactly once.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(shard.buildCount, 1);

      // A refresh while the first fetch is still in flight must be ignored,
      // not spawn a concurrent second build.
      shard.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(shard.buildCount, 1);

      // Finish the single in-flight build cleanly.
      shard.completers.first.complete(7);
      await tester.waitFor((s) => s is AsyncData<int>);
      expect((shard.state as AsyncData<int>).data, 7);
    },
  );

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
