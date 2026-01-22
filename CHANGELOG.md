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
