import 'dart:developer' show log;

import 'package:shard/src/caching/cache_entry.dart';
import 'package:shard/src/caching/cache_service.dart';
import 'package:shard/src/caching/memory_cache_service.dart';

/// A mixin that provides convenient caching capabilities for repositories.
///
/// Use this mixin in your repository classes to easily cache API responses
/// or expensive computations with automatic expiration handling.
///
/// ## Setup
///
/// Implement the [cacheService] getter to provide your cache backend:
///
/// ```dart
/// class UserRepository with CacheMixin {
///   @override
///   CacheService get cacheService => MemoryCacheService();
///
///   final UserApi _api;
///   UserRepository(this._api);
/// }
/// ```
///
/// ## Usage
///
/// Use [resolve] to cache API calls:
///
/// ```dart
/// Future<User> getUser(String id) => resolve<User>(
///   key: 'user_$id',
///   fetcher: () => _api.fetchUser(id),
///   ttl: Duration(minutes: 30),
///   forceRefresh: false, // Set true to bypass cache
///   onErrorReturnOldCache: true, // Fallback to stale data on error
/// );
/// ```
mixin CacheMixin {
  CacheService get cacheService => MemoryCacheService();

  Future<T> resolve<T>({
    required String key,
    required Future<T> Function() fetcher,
    Duration ttl = const Duration(hours: 1),
    bool forceRefresh = false,
    bool onErrorReturnOldCache = false,
  }) async {
    if (!forceRefresh) {
      try {
        final cachedEntry = await cacheService.read(key);
        if (cachedEntry != null && !cachedEntry.isExpired) {
          log('[CACHE HIT] $key');
          return cachedEntry.data as T;
        }
      } catch (e) {
        log('Error while reading cache: $e');
      }
    }

    late final T data;

    try {
      log('[API CALL] $key');
      data = await fetcher();
    } catch (error, _) {
      log('[API ERROR] $key: $error');
      if (onErrorReturnOldCache) {
        final oldEntry = await cacheService.read(key);
        if (oldEntry != null) {
          log('[FALLBACK] returning cached data');
          return oldEntry.data as T;
        }
      }
      rethrow;
    }

    try {
      final entry = CacheEntry(data: data, expiryDate: DateTime.now().add(ttl));
      await cacheService.write(key, entry);
    } catch (e) {
      log('[CACHE WRITE ERROR]: $e');
    }

    return data;
  }
}
