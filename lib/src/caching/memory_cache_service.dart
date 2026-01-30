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

  @override
  Future<void> write(String key, CacheEntry entry) async {
    _storage[key] = entry;
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
}
