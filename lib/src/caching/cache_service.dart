import 'package:shard/src/caching/cache_entry.dart';

/// Abstract interface for cache storage implementations.
///
/// Implement this class to create custom cache backends such as
/// SharedPreferences, Hive, SQLite, or any other storage solution.
///
/// ## Built-in Implementation
///
/// Shard provides [MemoryCacheService] as a ready-to-use in-memory implementation.
///
/// ## Custom Implementation Example
///
/// ```dart
/// class SharedPrefsCacheService implements CacheService {
///   final SharedPreferences _prefs;
///
///   SharedPrefsCacheService(this._prefs);
///
///   @override
///   Future<void> write(String key, CacheEntry entry) async {
///     await _prefs.setString(key, jsonEncode(entry.toJson()));
///   }
///
///   @override
///   Future<CacheEntry?> read(String key) async {
///     final json = _prefs.getString(key);
///     if (json == null) return null;
///     return CacheEntry.fromJson(jsonDecode(json));
///   }
///
///   @override
///   Future<void> delete(String key) async {
///     await _prefs.remove(key);
///   }
///
///   @override
///   Future<void> clearAll() async {
///     await _prefs.clear();
///   }
/// }
/// ```
abstract class CacheService {
  /// Writes a cache entry with the given key.
  Future<void> write(String key, CacheEntry entry);

  /// Reads a cache entry by key. Returns null if not found.
  Future<CacheEntry?> read(String key);

  /// Deletes a cache entry by key.
  Future<void> delete(String key);

  /// Clears all cached entries.
  Future<void> clearAll();
}
