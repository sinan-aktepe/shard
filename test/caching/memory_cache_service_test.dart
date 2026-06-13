import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

void main() {
  setUp(() async {
    // Singleton — clear data and reset config before each test.
    await MemoryCacheService().clearAll();
    MemoryCacheService().maxEntries = null;
  });

  group('MemoryCacheService', () {
    test('write and read roundtrip', () async {
      final cache = MemoryCacheService();
      final entry = CacheEntry(
        data: 'hi',
        expiryDate: DateTime.now().add(const Duration(hours: 1)),
      );
      await cache.write('k', entry);
      final read = await cache.read('k');
      expect(read?.data, 'hi');
    });

    test('read returns null for missing key', () async {
      final cache = MemoryCacheService();
      expect(await cache.read('missing'), isNull);
    });

    test('delete removes entry', () async {
      final cache = MemoryCacheService();
      await cache.write(
        'k',
        CacheEntry(data: 1, expiryDate: DateTime.now().add(const Duration(hours: 1))),
      );
      await cache.delete('k');
      expect(await cache.read('k'), isNull);
    });

    test('clearAll empties storage', () async {
      final cache = MemoryCacheService();
      await cache.write(
        'a',
        CacheEntry(data: 1, expiryDate: DateTime.now().add(const Duration(hours: 1))),
      );
      await cache.write(
        'b',
        CacheEntry(data: 2, expiryDate: DateTime.now().add(const Duration(hours: 1))),
      );
      await cache.clearAll();
      expect(await cache.read('a'), isNull);
      expect(await cache.read('b'), isNull);
    });

    test('is a singleton', () {
      expect(identical(MemoryCacheService(), MemoryCacheService()), isTrue);
    });

    test('expired entries are still readable, but isExpired is true', () async {
      final cache = MemoryCacheService();
      await cache.write(
        'k',
        CacheEntry(
          data: 1,
          expiryDate: DateTime.now().subtract(const Duration(seconds: 1)),
        ),
      );
      final read = await cache.read('k');
      expect(read, isNotNull);
      expect(read!.isExpired, isTrue);
    });

    CacheEntry fresh(Object? v) => CacheEntry(
          data: v,
          expiryDate: DateTime.now().add(const Duration(hours: 1)),
        );

    test('evictExpired removes only expired entries and returns the count',
        () async {
      final cache = MemoryCacheService();
      await cache.write('fresh', fresh(1));
      await cache.write(
        'stale',
        CacheEntry(
          data: 2,
          expiryDate: DateTime.now().subtract(const Duration(seconds: 1)),
        ),
      );

      final removed = cache.evictExpired();

      expect(removed, 1);
      expect(await cache.read('fresh'), isNotNull);
      expect(await cache.read('stale'), isNull);
    });

    test('maxEntries evicts the oldest entry on write', () async {
      final cache = MemoryCacheService();
      cache.maxEntries = 2;

      await cache.write('a', fresh(1));
      await cache.write('b', fresh(2));
      await cache.write('c', fresh(3)); // exceeds the limit; 'a' is oldest

      expect(await cache.read('a'), isNull);
      expect((await cache.read('b'))?.data, 2);
      expect((await cache.read('c'))?.data, 3);
    });

    test('null maxEntries keeps the cache unbounded', () async {
      final cache = MemoryCacheService();
      for (var i = 0; i < 50; i++) {
        await cache.write('k$i', fresh(i));
      }
      expect(cache.entryCount, 50);
    });
  });
}
