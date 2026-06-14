import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/shard_test.dart';

class _Repo with CacheMixin {
  _Repo(this._cache);
  final CacheService _cache;

  @override
  CacheService get cacheService => _cache;

  int fetchCount = 0;
  bool shouldFail = false;

  Future<int> getValue(String id) {
    return resolve<int>(
      key: 'v_$id',
      fetcher: () async {
        fetchCount++;
        if (shouldFail) throw StateError('fetch failed');
        return id.length;
      },
      ttl: const Duration(minutes: 5),
    );
  }

  Future<int> getValueWithStaleFallback(String id) {
    return resolve<int>(
      key: 'v_$id',
      fetcher: () async {
        fetchCount++;
        if (shouldFail) throw StateError('fetch failed');
        return id.length;
      },
      onErrorReturnOldCache: true,
    );
  }
}

class _RecordingRepo with CacheMixin {
  _RecordingRepo(this._cache, {required this.logEvents});
  final CacheService _cache;
  final bool logEvents;
  final List<String> logs = [];

  @override
  CacheService get cacheService => _cache;

  @override
  bool get logCacheEvents => logEvents;

  @override
  void onCacheLog(String message) => logs.add(message);

  Future<int> getValue(String id) =>
      resolve<int>(key: 'v_$id', fetcher: () async => id.length);
}

void main() {
  test('cache hit returns cached value without calling fetcher', () async {
    final cache = FakeCacheService()..seed('v_abc', 99);
    final repo = _Repo(cache);
    final v = await repo.getValue('abc');
    expect(v, 99);
    expect(repo.fetchCount, 0);
  });

  test('cache miss calls fetcher and writes', () async {
    final cache = FakeCacheService();
    final repo = _Repo(cache);
    final v = await repo.getValue('abc');
    expect(v, 3);
    expect(repo.fetchCount, 1);
    expect(cache.writeCount, 1);
  });

  test('expired cache triggers refetch', () async {
    final cache = FakeCacheService()..seedExpired('v_abc', 99);
    final repo = _Repo(cache);
    final v = await repo.getValue('abc');
    expect(v, 3); // fresh, not 99
    expect(repo.fetchCount, 1);
  });

  test('forceRefresh: true bypasses cache', () async {
    final cache = FakeCacheService()..seed('v_abc', 99);
    final repo = _Repo(cache);
    final v = await repo.resolve<int>(
      key: 'v_abc',
      fetcher: () async {
        repo.fetchCount++;
        return 77;
      },
      forceRefresh: true,
    );
    expect(v, 77);
    expect(repo.fetchCount, 1);
  });

  test('onErrorReturnOldCache returns stale on fetcher error', () async {
    final cache = FakeCacheService()..seedExpired('v_abc', 50);
    final repo = _Repo(cache)..shouldFail = true;
    final v = await repo.getValueWithStaleFallback('abc');
    expect(v, 50);
  });

  test('rethrows when no cached entry exists and fetcher fails', () async {
    final cache = FakeCacheService();
    final repo = _Repo(cache)..shouldFail = true;
    await expectLater(
      repo.getValueWithStaleFallback('abc'),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'routes cache events to onCacheLog when logCacheEvents is true',
    () async {
      final repo = _RecordingRepo(FakeCacheService(), logEvents: true);
      await repo.getValue('abc');
      expect(repo.logs, isNotEmpty);
    },
  );

  test('suppresses cache logging when logCacheEvents is false', () async {
    final repo = _RecordingRepo(FakeCacheService(), logEvents: false);
    await repo.getValue('abc');
    expect(repo.logs, isEmpty);
  });
}
