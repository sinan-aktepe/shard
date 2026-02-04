/// Shard - A powerful, lightweight state management solution for Flutter.
///
/// Shard provides a simple and intuitive API for managing application state
/// with built-in support for persistence, debounce, throttle, and seamless
/// widget integration. Use [ShardLocator] to register and resolve singletons
/// without a separate package.
///
/// ## Getting Started
///
/// Import this library to access all Shard features:
///
/// ```dart
/// import 'package:shard/shard.dart';
/// ```
///
/// ## Core Components
///
/// ### State Management
/// - [Shard] - Base class for state management
/// - [PersistentShard] - Shard with built-in persistence
/// - [ShardObserver] - Observer for monitoring shard events
///
/// ### Widgets
/// - [ShardProvider] - Provides shard instances to the widget tree
/// - [ShardBuilder] - Rebuilds when shard state changes
/// - [ShardSelector] - Rebuilds only when selected value changes
///
/// ### Persistence
/// - [StateStorage] - Interface for storage backends
/// - [StateSerializer] - Interface for state serialization
/// - [StatePersistenceMixin] - Mixin for adding persistence to shards
///
/// ### Service locator
/// - [ShardLocator] - Register and resolve singletons (registerSingleton, registerLazySingleton, get, reset)
///
/// ## Example
///
/// ```dart
/// // Define a shard
/// class CounterShard extends Shard<int> {
///   CounterShard() : super(0);
///
///   void increment() => emit(state + 1);
///   void decrement() => emit(state - 1);
/// }
///
/// // Use in your app
/// ShardProvider<CounterShard>(
///   create: () => CounterShard(),
///   child: ShardBuilder<CounterShard, int>(
///     builder: (context, count) => Text('Count: $count'),
///   ),
/// )
/// ```
///
/// See the [documentation](https://github.com/sinanaktepe/shard) for more details.
library;

export 'src/src.dart';
