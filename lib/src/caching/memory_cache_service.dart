import 'package:shard/src/caching/cache_entry.dart';
import 'package:shard/src/caching/cache_service.dart';

/// An in-memory implementation of [CacheService].
///
/// This is a singleton class that stores cache entries in memory.
/// Data is lost when the app restarts.
///
/// ## Usage
///
/// ```dart
/// final cacheService = MemoryCacheService();
///
/// // Write
/// await cacheService.write('key', CacheEntry(
///   data: {'name': 'John'},
///   expiryDate: DateTime.now().add(Duration(hours: 1)),
/// ));
///
/// // Read
/// final entry = await cacheService.read('key');
/// if (entry != null && !entry.isExpired) {
///   print(entry.data);
/// }
/// ```
///
/// ## Bounding memory growth
///
/// Expired entries are kept on [read] (so stale-while-revalidate flows like
/// [CacheMixin]'s `onErrorReturnOldCache` still work). To stop the map from
/// growing without bound, either set [maxEntries] to cap the number of retained
/// entries, or call [evictExpired] periodically to drop stale entries.
///
/// ## Note
///
/// For persistent caching, implement your own [CacheService] using
/// SharedPreferences, Hive, or any other storage solution.
class MemoryCacheService implements CacheService {
  static final MemoryCacheService _instance = MemoryCacheService._internal();

  /// Returns the singleton instance of [MemoryCacheService].
  factory MemoryCacheService() => _instance;
  MemoryCacheService._internal();

  final Map<String, CacheEntry> _storage = {};

  /// Maximum number of entries to retain, or `null` for an unbounded cache.
  ///
  /// When set, [write] evicts the oldest entries (by insertion order) once the
  /// count would exceed this limit. Updating an existing key does not change
  /// its age. Defaults to `null` (unbounded). A value of `0` keeps nothing.
  int? maxEntries;

  /// The number of entries currently held (including expired ones).
  int get entryCount => _storage.length;

  @override
  Future<void> write(String key, CacheEntry entry) async {
    _storage[key] = entry;
    _enforceMaxEntries();
  }

  @override
  Future<CacheEntry?> read(String key) async {
    return _storage[key];
  }

  @override
  Future<void> delete(String key) async {
    _storage.remove(key);
  }

  @override
  Future<void> clearAll() async {
    _storage.clear();
  }

  /// Removes every entry whose [CacheEntry.isExpired] is `true`.
  ///
  /// Returns the number of entries removed. Useful for periodic cleanup, since
  /// [read] deliberately keeps expired entries available for stale fallbacks.
  int evictExpired() {
    final expiredKeys = [
      for (final entry in _storage.entries)
        if (entry.value.isExpired) entry.key,
    ];
    for (final key in expiredKeys) {
      _storage.remove(key);
    }
    return expiredKeys.length;
  }

  void _enforceMaxEntries() {
    final limit = maxEntries;
    if (limit == null) return;
    while (_storage.length > limit) {
      _storage.remove(_storage.keys.first);
    }
  }
}
