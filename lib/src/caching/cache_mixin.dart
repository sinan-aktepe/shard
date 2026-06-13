import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

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

  /// Whether cache hit/miss/error events are logged.
  ///
  /// Defaults to [kDebugMode], so release builds stay silent and never emit
  /// cache keys (which may contain user identifiers) to logs. Override to
  /// force logging on or off:
  ///
  /// ```dart
  /// @override
  /// bool get logCacheEvents => false;
  /// ```
  bool get logCacheEvents => kDebugMode;

  /// Sink for cache log lines.
  ///
  /// Only invoked when [logCacheEvents] is `true`. Defaults to
  /// `dart:developer.log(name: 'shard.cache')`, which surfaces in the Flutter
  /// DevTools Logging tab. Override to route messages elsewhere (a custom
  /// logger, a test recorder, etc.).
  @protected
  void onCacheLog(String message) =>
      developer.log(message, name: 'shard.cache');

  void _log(String message) {
    if (logCacheEvents) onCacheLog(message);
  }

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
          _log('[CACHE HIT] $key');
          return cachedEntry.data as T;
        }
      } catch (e) {
        _log('Error while reading cache: $e');
      }
    }

    late final T data;

    try {
      _log('[API CALL] $key');
      data = await fetcher();
    } catch (error, _) {
      _log('[API ERROR] $key: $error');
      if (onErrorReturnOldCache) {
        final oldEntry = await cacheService.read(key);
        if (oldEntry != null) {
          _log('[FALLBACK] returning cached data');
          return oldEntry.data as T;
        }
      }
      rethrow;
    }

    try {
      final entry = CacheEntry(data: data, expiryDate: DateTime.now().add(ttl));
      await cacheService.write(key, entry);
    } catch (e) {
      _log('[CACHE WRITE ERROR]: $e');
    }

    return data;
  }
}
