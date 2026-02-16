# Shard

A powerful, lightweight state management solution for Flutter. Built-in persistence, async support, debounce & throttle, and a service locator—all in one package, no heavy frameworks.

## Quick Start

### 1. Add to `pubspec.yaml`

```yaml
dependencies:
  shard: ^1.0.0
```

### 2. Create a Shard

```dart
import 'package:shard/shard.dart';

class CounterShard extends Shard<int> {
  CounterShard() : super(0);
  
  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);
}
```

### 3. Provide and Use

```dart
// Wrap your app
ShardProvider<CounterShard>(
  create: () => CounterShard(),
  child: MaterialApp(
    home: CounterScreen(),
  ),
)

// In your widget
ShardBuilder<CounterShard, int>(
  builder: (context, count) => Text('Count: $count'),
)

// In callbacks
ElevatedButton(
  onPressed: () => context.read<CounterShard>().increment(),
  child: Text('+'),
)
```

**That's it!** You're ready to go.

## What is Shard?

Shard is a state management solution built on Flutter's `ChangeNotifier`. It provides:

- **Simple API** — `emit()` to update state, `onChange()` for lifecycle hooks
- **Type-safe** — Full Dart type safety, no code generation
- **Persistence** — Automatic state persistence with `PersistentShard`
- **Async support** — `FutureShard` and `StreamShard` for async operations
- **Performance** — Built-in debounce, throttle, and response caching
- **Widgets** — `ShardBuilder`, `ShardSelector`, `AsyncShardBuilder`
- **Service locator** — `ShardLocator` for singletons (no GetIt needed)

## Why Shard?

- **Zero boilerplate** — Simple API, less code
- **Built-in features** — Persistence, caching, debounce/throttle included
- **Type-safe** — Full Dart type system, no code generation
- **Lightweight** — Minimal dependencies, no heavy frameworks
- **Testable** — Clear separation of concerns
- **Production-ready** — Stable API (1.0.0)

## Key Features

| Feature | Description |
|---------|-------------|
| **Shard** | Base state management with `emit()`, lifecycle hooks |
| **FutureShard** | Async state from `Future` with automatic caching |
| **StreamShard** | Async state from `Stream` for real-time data |
| **PersistentShard** | Automatic state persistence across app restarts |
| **ShardBuilder** | Widget that rebuilds on state changes |
| **ShardSelector** | Optimized widget that rebuilds only when selected value changes |
| **AsyncShardBuilder** | Widget for async states (loading/data/error) |
| **DebounceMixin** | Delay execution until inactivity period |
| **ThrottleMixin** | Limit execution to once per time period |
| **ShardLocator** | Simple service locator for singletons |

## Examples

### Async State with FutureShard

```dart
class UserShard extends FutureShard<User> {
  final String userId;
  
  UserShard({required this.userId});
  
  @override
  Future<User> build() => api.getUser(userId);
  
  @override
  bool get allowCache => true; // Enable caching
}

// In UI
AsyncShardBuilder<UserShard, User>(
  onLoading: (context) => CircularProgressIndicator(),
  onData: (context, user) => Text('Hello, ${user.name}'),
  onError: (context, error, _) => Text('Error: $error'),
)
```

### Persistence

```dart
class CounterShard extends SimplePersistentShard<int> {
  CounterShard() : super(
    0,
    storageFactory: () => SharedPreferencesStorage.getInstance(),
    serializer: IntSerializer(),
  );
  
  @override
  String get persistenceKey => 'counter';
  
  void increment() => emit(state + 1);
}
```

### Debounce & Throttle

```dart
class SearchShard extends Shard<SearchState> {
  void updateQuery(String query) {
    emit(state.copyWith(query: query));
    
    // Debounce search API call
    debounce('search', () => performSearch(query), 
      duration: Duration(milliseconds: 500));
  }
}

class ScrollShard extends Shard<ScrollState> {
  void onScroll() {
    // Throttle load-more to once per second
    throttle('loadMore', () => loadMore(), 
      duration: Duration(seconds: 1));
  }
}
```

### Service Locator

```dart
void main() {
  // Register singletons
  ShardLocator.registerSingleton<ApiClient>(ApiClient());
  ShardLocator.registerLazySingleton<Repository>(
    () => Repository(ShardLocator.get<ApiClient>()),
  );
  
  runApp(MyApp());
}

// Use anywhere
final repo = ShardLocator.get<Repository>();
```

## Documentation

**[Full Documentation](https://shard-68cbe.web.app/getting-started/introduction)**

- [Installation](https://shard-68cbe.web.app/getting-started/installation)
- [Quick Start](https://shard-68cbe.web.app/getting-started/quick-start)
- [Core Concepts](https://shard-68cbe.web.app/essentials/core-concepts)
- [All Shards](https://shard-68cbe.web.app/all-shards/future-shard)
- [Examples](https://shard-68cbe.web.app/examples/todo-app)

## License

See [LICENSE](LICENSE) file for details.
