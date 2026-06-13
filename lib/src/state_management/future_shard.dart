import 'package:flutter/material.dart';

import '../caching/cache_entry.dart';
import '../caching/cache_service.dart';
import '../caching/memory_cache_service.dart';
import 'async_value.dart';
import 'shard.dart';

/// A [Shard] that manages asynchronous state from a [Future].
///
/// [FutureShard] automatically executes [build] when initialized and
/// manages the loading, data, and error states through [AsyncValue].
///
/// ## Creating a FutureShard
///
/// ```dart
/// class UserShard extends FutureShard<User> {
///   final String userId;
///   final UserRepository repository;
///
///   UserShard({required this.userId, required this.repository});
///
///   @override
///   Future<User> build() async {
///     return await repository.getUser(userId);
///   }
/// }
/// ```
///
/// ## Usage in UI
///
/// ```dart
/// AsyncShardBuilder<UserShard, User>(
///   onLoading: (context) => CircularProgressIndicator(),
///   onData: (context, user) => Text('Hello, ${user.name}'),
///   onError: (context, error, stackTrace) => Text('Error: $error'),
/// )
/// ```
///
/// ## Refreshing Data
///
/// Call [refresh] to re-execute the [build] method:
///
/// ```dart
/// final userShard = context.read<UserShard>();
/// userShard.refresh();
/// ```
///
/// ## Caching
///
/// Caching is enabled by default. Customize the cache key or disable caching:
///
/// ```dart
/// class UserShard extends FutureShard<User> {
///   final String userId;
///
///   UserShard({required this.userId});
///
///   @override
///   String get cacheKey => 'user_$userId'; // Optional: customize cache key
///
///   @override
///   Future<User> build() async => api.getUser(userId);
/// }
/// ```
///
/// To disable caching, override [allowCache]:
///
/// ```dart
/// @override
/// bool get allowCache => false;
/// ```
///
/// The data is cached directly as-is, without any serialization. This works for any type
/// that can be stored in memory (or disk if using a persistent cache service).
///
/// See also:
/// - [StreamShard] for Stream-based async state management
/// - [AsyncValue] for the state representation
/// - [AsyncShardBuilder] for building UI based on async state
/// - [CacheService] for cache storage implementations
abstract class FutureShard<T> extends Shard<AsyncValue<T>> {
  bool _isRefreshing = false;
  bool _forceRefresh = false;

  /// Creates a [FutureShard] with an initial loading state.
  FutureShard() : super(AsyncLoading<T>());

  /// Whether caching is enabled for this shard.
  ///
  /// When `true`, the shard will cache fetched data using [cacheService].
  /// Override this getter to disable caching:
  ///
  /// ```dart
  /// @override
  /// bool get allowCache => false;
  /// ```
  ///
  /// Defaults to `true`.
  bool get allowCache => true;

  /// The cache service to use for storing cached data.
  ///
  /// Override this getter to provide a custom cache service.
  /// Defaults to [MemoryCacheService] singleton.
  ///
  /// ```dart
  /// @override
  /// CacheService get cacheService => MyCustomCacheService();
  /// ```
  CacheService get cacheService => MemoryCacheService();

  /// The cache key used to store and retrieve cached data.
  ///
  /// Defaults to the runtime type name.
  ///
  /// > **Important:** the default key is shared by every instance of the same
  /// > type. For a *parameterized* shard — same type, different inputs — this
  /// > means two instances would read and write the same cache entry and serve
  /// > each other's data. Always override [cacheKey] to include the parameters
  /// > that distinguish one instance from another:
  /// >
  /// > ```dart
  /// > @override
  /// > String get cacheKey => 'user_$userId';
  /// > ```
  /// >
  /// > The default also relies on `runtimeType.toString()`, which is not stable
  /// > under release-build obfuscation/tree-shaking. If a shard's cache must
  /// > survive obfuscation, override [cacheKey] with an explicit literal.
  String get cacheKey => runtimeType.toString();

  /// The time-to-live duration for cached data.
  ///
  /// Override this getter to customize cache expiration.
  /// Defaults to 1 hour.
  ///
  /// ```dart
  /// @override
  /// Duration get cacheTTL => Duration(hours: 2);
  /// ```
  Duration get cacheTTL => const Duration(hours: 1);

  /// Builds and returns the [Future] that produces the data.
  ///
  /// This method is called automatically when the shard is initialized
  /// and when [refresh] is called.
  ///
  /// Override this method to define how data should be fetched:
  ///
  /// ```dart
  /// @override
  /// Future<User> build() async {
  ///   return await api.fetchUser(userId);
  /// }
  /// ```
  @protected
  Future<T> build();

  /// Re-executes [build] to refresh the data.
  ///
  /// The state transitions to [AsyncLoading] (retaining previous data)
  /// before executing [build] again.
  ///
  /// If a refresh is already in progress, this method does nothing.
  ///
  /// When caching is enabled, this method invalidates the cache and
  /// fetches fresh data.
  ///
  /// ```dart
  /// void onRefreshPressed() {
  ///   myShard.refresh();
  /// }
  /// ```
  void refresh({bool invalidateCache = true}) {
    if (_isRefreshing || isDisposed) return;
    _isRefreshing = true;
    _forceRefresh = invalidateCache;

    if (invalidateCache && allowCache) {
      cacheService.delete(cacheKey).catchError((_) {});
    }

    emit(AsyncLoading<T>(previousData: state.dataOrNull));
    _fetch();
  }

  /// Called when the shard is initialized.
  ///
  /// Automatically starts fetching data by calling [build].
  @override
  @mustCallSuper
  void onInit() {
    super.onInit();
    // Mark the initial fetch as in-progress so a [refresh] triggered before it
    // completes is ignored instead of racing a second concurrent [build].
    _isRefreshing = true;
    _fetch();
  }

  Future<void> _fetch() async {
    // Try to load from cache if enabled and not forcing refresh
    if (allowCache && !_forceRefresh) {
      try {
        final cachedEntry = await cacheService.read(cacheKey);
        if (cachedEntry != null && !cachedEntry.isExpired) {
          try {
            final cachedData = cachedEntry.data as T;
            if (isDisposed) return;
            emit(AsyncData<T>(cachedData));
            _isRefreshing = false;
            return;
          } catch (e) {
            // Type cast failed, continue to fetch fresh data
          }
        }
      } catch (e) {
        // Cache read failed, continue to fetch fresh data
      }
    }

    // Fetch fresh data
    try {
      final result = await build();
      if (isDisposed) return;

      // Save to cache if enabled
      if (allowCache) {
        try {
          final entry = CacheEntry(
            data: result,
            expiryDate: DateTime.now().add(cacheTTL),
          );
          await cacheService.write(cacheKey, entry);
        } catch (e) {
          // Cache write failed, but don't fail the fetch
        }
      }

      emit(AsyncData<T>(result));
    } catch (e, st) {
      if (isDisposed) return;
      addError(e, st);
      emit(AsyncError<T>(e, st, state.dataOrNull));
    } finally {
      _isRefreshing = false;
      _forceRefresh = false;
    }
  }
}
