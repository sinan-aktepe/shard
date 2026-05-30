import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/src/testing/fake_cache_service.dart';

void main() {
  group('FakeCacheService', () {
    test('write and read roundtrip', () async {
      final cache = FakeCacheService();
      final entry = CacheEntry(
        data: 42,
        expiryDate: DateTime.now().add(const Duration(hours: 1)),
      );
      await cache.write('k', entry);
      final read = await cache.read('k');
      expect(read?.data, 42);
    });

    test('read returns null for missing key', () async {
      final cache = FakeCacheService();
      expect(await cache.read('missing'), isNull);
    });

    test('seed pre-populates with fresh entry', () async {
      final cache = FakeCacheService();
      cache.seed('k', 99);
      final read = await cache.read('k');
      expect(read?.data, 99);
      expect(read?.isExpired, isFalse);
    });

    test('seedExpired pre-populates with already-expired entry', () async {
      final cache = FakeCacheService();
      cache.seedExpired('k', 'stale');
      final read = await cache.read('k');
      expect(read?.data, 'stale');
      expect(read?.isExpired, isTrue);
    });

    test('delete removes entry', () async {
      final cache = FakeCacheService();
      cache.seed('k', 1);
      await cache.delete('k');
      expect(await cache.read('k'), isNull);
      expect(cache.deleteCount, 1);
    });

    test('clearAll empties everything', () async {
      final cache = FakeCacheService();
      cache.seed('a', 1);
      cache.seed('b', 2);
      await cache.clearAll();
      expect(cache.entries, isEmpty);
    });

    test('counters and key lists update', () async {
      final cache = FakeCacheService();
      await cache.write('a', CacheEntry(data: 1, expiryDate: DateTime.now()));
      await cache.read('a');
      await cache.read('b');
      expect(cache.writeCount, 1);
      expect(cache.readCount, 2);
      expect(cache.writeKeys, ['a']);
      expect(cache.readKeys, ['a', 'b']);
    });

    test('readError throws on read', () async {
      final cache = FakeCacheService()..readError = StateError('boom');
      await expectLater(cache.read('k'), throwsA(isA<StateError>()));
    });

    test('writeError throws on write', () async {
      final cache = FakeCacheService()..writeError = StateError('boom');
      await expectLater(
        cache.write('k', CacheEntry(data: 1, expiryDate: DateTime.now())),
        throwsA(isA<StateError>()),
      );
    });

    test('deleteError throws on delete', () async {
      final cache = FakeCacheService()..deleteError = StateError('boom');
      await expectLater(cache.delete('k'), throwsA(isA<StateError>()));
    });

    test('clearError throws on clearAll', () async {
      final cache = FakeCacheService()..clearError = StateError('boom');
      await expectLater(cache.clearAll(), throwsA(isA<StateError>()));
    });

    test('reset clears data, counters, errors, delays', () async {
      final cache = FakeCacheService()
        ..readError = StateError('x')
        ..readDelay = const Duration(seconds: 1);
      cache.seed('k', 1);
      cache.reset();
      expect(cache.entries, isEmpty);
      expect(cache.readCount, 0);
      expect(cache.readKeys, isEmpty);
      expect(cache.writeKeys, isEmpty);
      expect(cache.readError, isNull);
      expect(cache.readDelay, isNull);
    });

    test('clear wipes data but keeps counters and key lists', () async {
      final cache = FakeCacheService();
      await cache.write('k', CacheEntry(data: 1, expiryDate: DateTime.now()));
      cache.clear();
      expect(cache.entries, isEmpty);
      expect(cache.writeCount, 1);
      expect(cache.writeKeys, ['k']);
    });
  });
}
