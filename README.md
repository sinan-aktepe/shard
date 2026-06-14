<p align="center">
  <img src="https://shard-68cbe.web.app/logo.png" alt="Shard" width="96" />
</p>

<h3 align="center">Shard</h3>

<p align="center">
  A lightweight, zero-dependency state management solution for Flutter.<br/>
  State, async, persistence, caching, DI, debounce/throttle — all in one package.
</p>

<p align="center">
  <a href="https://pub.dev/packages/shard"><img src="https://img.shields.io/pub/v/shard.svg" alt="pub version" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="license" /></a>
</p>

---

## Why Shard?

No code generation. No external dependencies. One package that covers what most apps reach for:

- **State** — typed, equality-checked state with intent-named mutators.
- **Async** — `Future`, `Stream`, and one-shot command shards with built-in loading/data/error handling.
- **Persistence** — auto save/load across restarts, with schema versioning and migrations.
- **Caching** — TTL-based caching for async shards and repositories (stale-while-revalidate).
- **DI** — a tiny service locator for eager and lazy singletons.

## Install

```bash
flutter pub add shard
```

## Quick Start

```dart
// 1. Define your state
class CounterShard extends Shard<int> {
  CounterShard() : super(0);

  void increment() => emit(state + 1);
}

// 2. Provide it
ShardProvider<CounterShard>(
  create: () => CounterShard(),
  child: MaterialApp(home: CounterScreen()),
);

// 3. Use it — rebuilds only when state changes
ShardBuilder<CounterShard, int>(
  builder: (context, count) => Text('Count: $count'),
);

// Read without subscribing (callbacks, event handlers)
context.read<CounterShard>().increment();
```

## What's Included

| Area | What You Get |
|------|--------------|
| **State** | `Shard<T>` — `emit()` / `emitForce()`, lifecycle hooks, `Shard.stream`, `HistoryMixin` (undo/redo), `DeepEqualityMixin` |
| **Async** | `FutureShard<T>`, `StreamShard<T>`, `CommandShard<Arg, Res>` — idle / loading / data / error via `AsyncValue<T>` (`when` · `maybeWhen` · `guard`) |
| **Derived** | `computedShard()` / `ComputedShard<T>` — state derived from one or more sources |
| **Persistence** | `PersistentShard<T, K>`, `SimplePersistentShard<T>` — auto save/load, schema `version` + `migrate`, `clearPersistence()`, `flushOnPause` |
| **Performance** | `DebounceMixin`, `ThrottleMixin` — rate limiting built into `Shard` |
| **Cache** | `CacheService`, `MemoryCacheService` (bounded), `CacheMixin` — TTL caching for shards & repositories |
| **Widgets** | `ShardProvider`, `ShardBuilder`, `ShardSelector`, `AsyncShardBuilder`, `ShardListener`, `MultiShardProvider` / `MultiShardListener` |
| **DI** | `ShardLocator` — eager & lazy singletons, `isRegistered()`, `reset()` |
| **Observability** | `ShardObserver`, `LoggingObserver` — global `onChange` / `onError`, debug logger out of the box |
| **Testing** | `package:shard/shard_test.dart` — `ShardTester`, `shardTest()`, `FakeStateStorage`, `FakeCacheService`, `MockShardObserver` |

## Documentation

Full guides, tutorials, and the complete API reference live in the docs:

| Section | Link |
|---------|------|
| Getting Started | [Introduction · Installation · Quick Start](https://shard-68cbe.web.app/en/getting-started/introduction) |
| Essentials | [Core Concepts · Widgets · Async · Caching · Observer · Locator](https://shard-68cbe.web.app/en/essentials/core-concepts) |
| Shard Types | [FutureShard · StreamShard · PersistentShard](https://shard-68cbe.web.app/en/all-shards/future-shard) |
| Examples | [Todo App · Infinite Scroll · Best Practices](https://shard-68cbe.web.app/en/examples/todo-app) |

## Requirements

- Dart `^3.10.3`, Flutter `>=1.17.0`
- **Zero** external dependencies

## License

MIT — see [LICENSE](LICENSE).
