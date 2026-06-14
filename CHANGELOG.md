## 2.0.0-dev.1

First 2.x development release. Three breaking changes (all with a clear migration path — see [docs/superpowers/specs/2026-06-13-shard-2.0-migration.md](docs/superpowers/specs/2026-06-13-shard-2.0-migration.md)) plus a wave of additive features and fixes. The "zero runtime dependencies" guarantee is unchanged.

### Breaking changes

* **BREAKING**: `AsyncValue<T>` gained a fourth state, `AsyncIdle<T>` (the not-yet-started state). Any exhaustive `switch` over an `AsyncValue` in your code must now handle `AsyncIdle` (or switch to the new `when`/`maybeWhen`). `FutureShard`/`StreamShard` are unaffected (they begin loading), and `AsyncShardBuilder` keeps working via a new optional `onIdle:` builder that defaults to the loading widget.
* **BREAKING**: `StateStorage` gains a required `delete(String key)` method (per-key removal). Custom `StateStorage` implementations must add it — e.g. `await prefs.remove(key)` / `await box.delete(key)`. The bundled `FakeStateStorage` implements it.
* **BREAKING**: persisted state is now stored in a version envelope (`{"__shard_v":N,"__shard_p":"…"}`) instead of the bare payload. Reads are legacy-tolerant — data written by 1.x is treated as version 1 — so **upgrades keep their data**. Only a 2.0→1.x *downgrade* cannot read 2.0-written data.

### Async (`AsyncValue` / commands)

* **New**: `AsyncValue.when` / `maybeWhen` — exhaustive and partial pattern matching over idle/loading/data/error (loading and error receive `previousData`).
* **New**: `AsyncValue.mapData` / `whenData` — transform or read the success value while preserving the variant.
* **New**: `AsyncValue.guard(future, {previousData})` — runs a future and captures the outcome as `AsyncData`/`AsyncError`.
* **New**: `AsyncShardBuilder.onIdle` — optional builder for the idle state.
* **New**: `CommandShard<Arg, Res>` — a `Shard<AsyncValue<Res>>` for one-shot async actions (form submit, create/update/delete). Starts in `AsyncIdle`; `execute(arg)` runs the action (`AsyncLoading` → `AsyncData`/`AsyncError`) with a double-submit guard and dispose-safety, returning the result or null. `reset()` returns to idle. Renders with `AsyncShardBuilder` via `onIdle:`.

### Shards & composition

* **New**: `computedShard(sources, compute)` and `ComputedShard<T>` — a derived shard that listens to one or more `Listenable` sources and recomputes when any notifies. The function form is the recommended default; the subclass form gives a named type for `ShardProvider`.
* **New**: `HistoryMixin<T>` — undo/redo for a `Shard` (`undo()`, `redo()`, `canUndo`, `canRedo`, `clearHistory()`, configurable `maxHistory`). Records via `onChange` and restores via `setStateInternal`, so restores notify listeners/observers without being re-recorded.
* **New**: `Shard.stream` — a lazily-created broadcast `Stream<T>` of state changes (does not replay the current value; closes on dispose). Enables `StreamBuilder`, `await for`, and `emitsInOrder` stream assertions without a dependency.
* **New**: `StreamShard.pause()` / `resume()` / `isPaused` — pause and resume the underlying stream subscription (e.g. while a screen is backgrounded). Events are buffered while paused per `StreamSubscription` semantics.
* **New**: `deepEquals(a, b)` — structural equality for `List` / `Set` / `Map` / `Iterable` (recursive), with a `==` fallback for scalars. Useful in `buildWhen` / `listenWhen`, inside a `ShardSelector`, or anywhere collection-aware comparison helps.
* **New**: `DeepEqualityMixin<T>` — a `Shard` mixin that makes `emit` dedupe state with `deepEquals` instead of `==`, so rebuilding a collection with identical contents no longer notifies listeners.

### Widgets

* **New**: `ShardListener` / `MultiShardListener` — listener-only widgets for side effects (navigation, snackbars) that invoke a callback on state changes without rebuilding. `MultiShardListener` nests several via the `SingleChildShardListener` interface, like `MultiShardProvider`.

### Persistence

* **New**: `StatePersistenceMixin.clearPersistence()` (inherited by `PersistentShard`) — deletes this shard's persisted slice via `StateStorage.delete` (cancelling any pending debounced save), for logout/wipe flows. Leaves in-memory state untouched.
* **New**: schema versioning — `enablePersistence` and `PersistentShard`/`SimplePersistentShard` accept `version` (default 1) and `migrate(fromVersion, payload)`. `migrate` runs once when the stored version is older than `version`; it owns chaining intermediate migrations.
* **New**: `flushOnPause` — `enablePersistence` and `PersistentShard`/`SimplePersistentShard` accept `flushOnPause` (default false). When enabled, a `WidgetsBindingObserver` flushes a save on `AppLifecycleState.paused`/`detached`, so a backgrounded app doesn't lose the last change inside the debounce window. The observer is removed on `disablePersistence`/dispose.

### Caching

* **New**: `MemoryCacheService` memory bounding:
  * `maxEntries` — caps the number of retained entries (default `null`, unbounded); the oldest entries are evicted on `write` once the limit is exceeded.
  * `evictExpired()` — removes all expired entries on demand and returns the count removed.
  * `entryCount` — the number of entries currently held.
  * `read` still returns expired entries, so stale-while-revalidate flows (`CacheMixin`'s `onErrorReturnOldCache`) keep working.
* **New**: `CacheMixin.logCacheEvents` and `CacheMixin.onCacheLog(message)` — toggle cache logging and redirect log lines (to a custom logger, a test recorder, etc.). The default sink is `dart:developer.log(name: 'shard.cache')`.

### Observability

* **New**: `LoggingObserver` — a `ShardObserver` subclass that logs state changes and errors via `dart:developer.log(name: 'shard')` for DevTools integration. Defaults to `kDebugMode` so it's inert in release builds. Configurable `printer`, `shouldLog` predicate, `includeStackTrace`, and independent toggles for `logChanges` / `logErrors`.

### Testing

* **New**: `package:shard/shard_test.dart` — a separate public entry point for test utilities. Production builds do not link this code.
  * `ShardTester<T>` for capturing and asserting state sequences (`recordedStates`, `expectStates`, `expectNoMoreStates`, `waitForNext`, `waitFor`, `clear`, `dispose`, plus a `scope` static helper).
  * `shardTest<S, T>()` declarative helper for one-shot `build → act → expect` tests.
  * `FakeStateStorage` and `FakeCacheService` — in-memory implementations of the `StateStorage` / `CacheService` interfaces with failure injection, latency simulation, and call inspection.
  * `MockShardObserver` (plus `ObservedChange<T>` / `ObservedError` records) with a `scope` helper that safely installs/restores the global `Shard.observer` in a `finally` block.
  * `ShardAssertionError` / `ShardTimeoutError` — the error types `ShardTester` throws on failure.

### Fixes

* **Fix**: `StatePersistenceMixin.disposePersistenceIfEnabled` previously reset `_saveQueue` to a fresh future and then called `saveState()`, which short-circuited because `_isDisposed` was already true. As a result, a pending debounced save was silently dropped on disposal. Disposal now flushes the final write by chaining it onto the existing save queue and bypassing the `isDisposed` guard.
* **Fix**: `ShardSelector` now rebuilds correctly when the selected value is `null`. Previously a selector returning `null` (for example selecting a nullable field) left the widget stuck on `SizedBox.shrink()` and never invoked `builder`.
* **Fix**: `ShardBuilder` and `ShardSelector` now rebind their listener when a different instance is supplied to the `shard:` parameter (via `didUpdateWidget`). Previously they kept listening to the originally-provided instance.
* **Fix**: `FutureShard` no longer starts a second concurrent `build()` when `refresh()` is called while the initial fetch is still in flight. The initial fetch now participates in the same in-progress guard as `refresh()`.
* **Fix**: `CacheMixin` no longer logs in release builds. Cache hit/miss/error logging is gated behind the new `logCacheEvents` getter (defaults to `kDebugMode`), so cache keys — which may contain user identifiers — are not emitted to release logs.

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
