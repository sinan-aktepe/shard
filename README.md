<p align="center">
  <img src="https://shard-68cbe.web.app/logo.png" alt="Shard" width="96" />
</p>

<h3 align="center">Shard</h3>

<p align="center">
  A lightweight, zero-dependency state management solution for Flutter.<br/>
  Persistence, async, caching, debounce, throttle & service locator — all in one package.
</p>

---

## Documentation

For full documentation, tutorials, and best practices visit the official docs:

| Section | Link |
|---------|------|
| Getting Started | [Introduction · Installation · Quick Start](https://shard-68cbe.web.app/en/getting-started/introduction) |
| Essentials | [Core Concepts · Widgets · Async · Caching · Observer · Locator](https://shard-68cbe.web.app/en/essentials/core-concepts) |
| Shard Types | [FutureShard · StreamShard · PersistentShard](https://shard-68cbe.web.app/en/all-shards/future-shard) |
| Examples | [Todo App · Infinite Scroll · Best Practices](https://shard-68cbe.web.app/en/examples/todo-app) |

---

## Table of Contents

- [Why Shard?](#why-shard)
- [Quick Start](#quick-start)
- [What's Included](#whats-included)
- [Core Concepts](#core-concepts)
- [Usage Examples](#usage-examples)
  - [FutureShard + Caching](#futureshard--caching)
  - [StreamShard](#streamshard)
  - [Persistence](#persistence)
  - [Debounce & Throttle](#debounce--throttle)
  - [ShardSelector](#shardselector)
  - [MultiShardProvider](#multishardprovider)
  - [ShardLocator (DI)](#shardlocator-di)
  - [CacheMixin (Repository-Level Caching)](#cachemixin-repository-level-caching)
  - [ShardObserver (Global Logging)](#shardobserver-global-logging)
- [Requirements](#requirements)
- [License](#license)

---

## Why Shard?

No code generation. No extra dependencies. A single package that covers everything you need:

- **Persistent state** — Automatically save and load state across app restarts with built-in serializers.
- **Cache support** — TTL-based in-memory caching for async shards and repositories.
- **Helpers** — Debounce, throttle, global observer, and `AsyncValue` for handling loading/error states gracefully.
- **Service locator** — Register and resolve singletons effortlessly with `ShardLocator`.

---

## Quick Start

Add Shard to your project:

```yaml
# pubspec.yaml
dependencies:
  shard: ^1.0.1
```

Define your state, provide it, and use it — three simple steps:

```dart
// 1. Define your state
class CounterShard extends Shard<int> {
  CounterShard() : super(0);

  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);
}

// 2. Provide it
class CounterApp extends StatelessWidget {
  const CounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShardProvider<CounterShard>(
      create: () => CounterShard(),
      child: MaterialApp(home: CounterScreen()),
    );
  }
}

// 3. Use it
class CounterScreen extends StatelessWidget {
  const CounterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Rebuild only when state changes
        ShardBuilder<CounterShard, int>(
          builder: (context, count) => Text('Count: $count'),
        ),
        ElevatedButton(
          onPressed: () => context.read<CounterShard>().increment(),
          child: Text('+'),
        ),
      ],
    );
  }
}
```

---

## What's Included

| Area | What You Get |
|------|--------------|
| **State** | `Shard<T>` — `emit()`, `emitForce()`, lifecycle hooks, equality, observer |
| **Async** | `FutureShard<T>`, `StreamShard<T>` — loading / data / error with `AsyncValue<T>` |
| **Persistence** | `PersistentShard<T,K>`, `SimplePersistentShard<T>` — auto save / load with built-in serializers |
| **Performance** | `DebounceMixin`, `ThrottleMixin` — rate limiting built into `Shard` |
| **Cache** | `CacheService`, `MemoryCacheService`, `CacheMixin` — TTL-based caching for shards & repos |
| **Widgets** | `ShardBuilder`, `ShardSelector`, `AsyncShardBuilder`, `MultiShardProvider` |
| **DI** | `ShardLocator` — eager & lazy singletons, `isRegistered()`, `reset()` for tests |
| **Observability** | `ShardObserver` — global `onChange` / `onError` hooks |

---

## Core Concepts

Shard follows a straightforward data flow:

```
ShardProvider            → Injects a Shard into the widget tree
    ↓
ShardBuilder / Selector  → Rebuilds UI when state changes
    ↓
Shard.emit()             → Pushes new state, notifies listeners
```

Here's a breakdown of the key building blocks:

- **`Shard<T>`** — Holds typed state. Call `emit()` (equality-checked) or `emitForce()` (always notifies).
- **`ShardProvider`** — Provides a shard to descendants. Use `.value()` constructor for existing instances.
- **`ShardBuilder`** — Rebuilds its child whenever the shard's state changes.
- **`ShardSelector`** — Rebuilds only when a *selected slice* of state changes.
- **`FutureShard<T>`** — Wraps a `Future` with automatic loading → data → error transitions and caching.
- **`StreamShard<T>`** — Wraps a `Stream` with the same `AsyncValue` pattern.
- **`PersistentShard<T,K>`** — Persists state to storage with full control over serialization.
- **`context.read<T>()`** — Access a shard without subscribing (ideal for callbacks & event handlers).

---

## Usage Examples

### FutureShard + Caching

Fetch data asynchronously with built-in caching — no boilerplate required:

```dart
class UserShard extends FutureShard<User> {
  final String userId;
  UserShard({required this.userId});

  @override
  String get cacheKey => 'user_$userId';

  @override
  Duration get cacheTTL => Duration(minutes: 30);

  @override
  Future<User> build() => api.getUser(userId);
}

class UserScreen extends StatelessWidget {
  const UserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AsyncShardBuilder<UserShard, User>(
      onLoading: (c) => CircularProgressIndicator(),
      onData: (c, user) => Text(user.name),
      onError: (c, e, _) => Text('$e'),
    );
  }
}
```

### StreamShard

Subscribe to real-time data streams with the familiar `AsyncValue` pattern:

```dart
class MessagesStream extends StreamShard<List<Message>> {
  final String chatId;
  MessagesStream({required this.chatId});

  @override
  Stream<List<Message>> build() => repository.watchMessages(chatId);
}
```

### Persistence

Keep state alive across app restarts — just pick a serializer and a storage backend:

```dart
class CounterShard extends SimplePersistentShard<int> {
  CounterShard() : super(0,
    storageFactory: () => SharedPreferencesStorage.getInstance(),
    serializer: IntSerializer(),
  );

  @override
  String get persistenceKey => 'counter';

  void increment() => emit(state + 1);
}
```

### Debounce & Throttle

Rate-limit expensive operations directly inside your shard:

```dart
class SearchShard extends Shard<String> {
  SearchShard() : super('');

  void onQueryChanged(String query) {
    emit(query);
    debounce(
      'search',
      () => performSearch(query),
      duration: Duration(milliseconds: 500),
    );
  }

  Future<void> performSearch(String query) async { /* ... */ }
}

class FeedShard extends Shard<int> {
  FeedShard() : super(0);

  void onScrollNearEnd() {
    throttle(
      'loadMore',
      () => loadMore(),
      duration: Duration(seconds: 1),
    );
  }

  void loadMore() => emit(state + 1);
}
```

### ShardSelector

Optimize rebuilds by selecting only the slice of state you care about:

```dart
class UserNameText extends StatelessWidget {
  const UserNameText({super.key});

  @override
  Widget build(BuildContext context) {
    return ShardSelector<UserShard, UserState, String>(
      selector: (s) => s.name,
      builder: (context, name) => Text('Hello, $name'),
    );
  }
}
```

### MultiShardProvider

Provide multiple shards at once without deep nesting:

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiShardProvider(
      providers: [
        ShardProvider<AuthShard>(create: () => AuthShard()),
        ShardProvider<SettingsShard>(create: () => SettingsShard()),
        ShardProvider<ThemeShard>(create: () => ThemeShard()),
      ],
      child: MaterialApp(home: HomeScreen()),
    );
  }
}
```

### ShardLocator (DI)

A simple service locator for dependency injection — supports eager and lazy singletons:

```dart
class AppBootstrap {
  static void init() {
    ShardLocator.registerSingleton<ApiClient>(ApiClient());
    ShardLocator.registerLazySingleton<UserRepo>(
      () => UserRepo(ShardLocator.get<ApiClient>()),
    );
  }
}

class SomeService {
  UserRepo get repo => ShardLocator.get<UserRepo>();
}
```

### CacheMixin (Repository-Level Caching)

Add caching to your repositories with a single mixin — includes stale-while-revalidate support:

```dart
class UserRepository with CacheMixin {
  @override
  CacheService get cacheService => MemoryCacheService();

  final UserApi _api;
  UserRepository(this._api);

  Future<User> getUser(String id) => resolve<User>(
    key: 'user_$id',
    fetcher: () => _api.fetchUser(id),
    ttl: Duration(minutes: 30),
    onErrorReturnOldCache: true,
  );
}
```

### ShardObserver (Global Logging)

Track every state change and error across your entire app:

```dart
class AppObserver extends ShardObserver {
  @override
  void onChange(Shard shard, Object? previousState, Object? currentState) {
    print('${shard.runtimeType}: $previousState → $currentState');
  }

  @override
  void onError(Shard shard, Object error, StackTrace? stackTrace) {
    print('${shard.runtimeType} error: $error');
  }
}

void main() {
  Shard.observer = AppObserver();
  runApp(MyApp());
}
```

---

## Requirements

- Dart `^3.10.3`
- Flutter `>=1.17.0`
- **Zero** external dependencies

---

## License

MIT — see [LICENSE](LICENSE).
