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
