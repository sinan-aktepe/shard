## 1.1.0

* **New**: `LoggingObserver` — a `ShardObserver` subclass that logs state changes and errors via `dart:developer.log(name: 'shard')` for DevTools integration. Defaults to `kDebugMode` so it's inert in release builds. Configurable `printer`, `shouldLog` predicate, `includeStackTrace`, and independent toggles for `logChanges` / `logErrors`.
* **New**: `package:shard/shard_test.dart` — a separate public entry point for test utilities. Production builds do not link this code.
  * `ShardTester<T>` for capturing and asserting state sequences (`recordedStates`, `expectStates`, `expectNoMoreStates`, `waitForNext`, `waitFor`, `clear`, `dispose`, plus a `scope` static helper).
  * `shardTest<S, T>()` declarative helper for one-shot `build → act → expect` tests.
  * `FakeStateStorage` and `FakeCacheService` — in-memory implementations of the `StateStorage` / `CacheService` interfaces with failure injection, latency simulation, and call inspection.
  * `MockShardObserver` (plus `ObservedChange<T>` / `ObservedError` records) with a `scope` helper that safely installs/restores the global `Shard.observer` in a `finally` block.
  * `ShardAssertionError` / `ShardTimeoutError` — the error types `ShardTester` throws on failure.
* **Fix**: `StatePersistenceMixin.disposePersistenceIfEnabled` previously reset `_saveQueue` to a fresh future and then called `saveState()`, which short-circuited because `_isDisposed` was already true. As a result, a pending debounced save was silently dropped on disposal. Disposal now flushes the final write by chaining it onto the existing save queue and bypassing the `isDisposed` guard.

## 1.0.1

* Updated README with improved documentation and examples
* Added missing feature examples: `StreamShard`, `MultiShardProvider`, `CacheMixin`, `ShardObserver`

## 1.0.0

* **Stable release** – Public API is now frozen for 1.x.
* No API changes from 1.0.0-dev.1.

## 1.0.0-dev.1

* **New**: [ShardLocator] for singleton registration
  * `registerSingleton<T>(T instance)` - Register an existing instance
  * `registerLazySingleton<T>(T Function() factory)` - Register a factory, instantiated on first [get]
  * `get<T>()` - Resolve the registered singleton
  * `isRegistered<T>()` - Check if a type is registered
  * `reset()` - Clear all registrations (e.g. in test setUp)
* **New**: `stateSerializer<T>()` factory function for JSON-based serialization
  * Eliminates the need to create separate serializer classes
  * Works with any object that has `toJson()` and `fromJson()` methods
  * Supports lists, maps, and nested objects
* **New**: [StringSerializer] for simple string state persistence

## 0.3.0

* **New**: Built-in caching support for [FutureShard]
* **New**: [CacheService] interface for cache storage backends
* **New**: [MemoryCacheService] singleton for in-memory caching
* **New**: [CacheEntry] class for cache entries with expiration
* **New**: [CacheMixin] for repository-level caching with `resolve` method

## 0.2.0

* **BREAKING CHANGE**: `PersistentShard<T>` is now `PersistentShard<T, K>`
  * `T` - Full state type
  * `K` - Persistence data type (can be a subset of T)
  * Allows persisting only the data you need, excluding loading states, errors, etc.
* **BREAKING CHANGE**: `StatePersistenceMixin<T>` is now `StatePersistenceMixin<T, K>`
* **BREAKING CHANGE**: Added `onLoadComplete(K? data)` callback
  * Called when load operation completes (replaces automatic state update)
  * Receives the loaded data as parameter
  * `null` is passed when storage is empty (first launch)
  * Developers have full control over how loaded data is merged into state
* **BREAKING CHANGE**: New abstract method `toPersistence(T state)` required
  * Extracts the data to persist from the current state
* **BREAKING CHANGE**: `StateSerializer<T>` is now `StateSerializer<K>` in persistence config
* **BREAKING CHANGE**: Removed `clear()` method from `StateStorage` interface
  * The `clear()` method was removed because it cleared all storage data, which is not useful for developers
  * Developers can reset state by using `emit(initialState)` - auto-save will automatically sync to storage
* **BREAKING CHANGE**: Removed `clearStorage()` method from `StatePersistenceMixin`
* **BREAKING CHANGE**: Removed `clear()` method from `PersistentShard`
  * Developers now have full control over state reset using `emit()` method
* **New**: `SimplePersistentShard<T>` class for simple cases
  * Use when state type and persistence type are the same
  * No need to override `toPersistence` or `onLoadComplete`
  * Reduces boilerplate for simple use cases

## 0.1.0

* Added **MultiShardProvider** widget. Simplifies providing multiple shards to the widget tree
* **Type-safety improvements**
  * Removed unsafe `dynamic` casts in widget layer
  * Improved generic type preservation throughout the widget tree
  * Better compile-time type checking
* **Development improvements**
  * Added `flutter_lints` as dev dependency for better code quality

## 0.0.2

* Updated package metadata and documentation links
* Added homepage URL pointing to documentation site
* Added issue tracker link
* Added documentation URL
* Added package topics for better discoverability
* Removed flutter_lints dependency from dev_dependencies

## 0.0.1

* Initial release of Shard - A powerful, lightweight state management solution for Flutter
* Core state management with [Shard] class
* Built-in persistence support with [PersistentShard]
* Async state management with [FutureShard] and [StreamShard]
* Debounce and throttle mixins
* Widget integration with [ShardProvider], [ShardBuilder], and [ShardSelector]
* Observer pattern for global state monitoring
