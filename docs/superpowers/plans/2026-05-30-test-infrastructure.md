# Test Infrastructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a public test-utility entry point (`lib/shard_test.dart`), a debug-friendly `LoggingObserver` in the main library, and a complete internal test suite for the `shard` package — all without introducing any runtime dependencies.

**Architecture:** New code lives in two places: (1) `lib/src/observability/logging_observer.dart` plus a one-line re-export from `lib/shard.dart`, (2) `lib/src/testing/` re-exported solely through a new `lib/shard_test.dart` entry point so production builds never link the test code. The package's own tests go under `test/` mirroring `lib/src/`. Timing-bound tests use `package:fake_async` (dev-only).

**Tech Stack:** Dart 3.10.3+, Flutter ≥1.17.0, `flutter_test` (dev-dep, exists), `fake_async` (new dev-dep), `flutter_lints` (exists). No new runtime dependencies.

**Spec:** [docs/superpowers/specs/2026-05-30-test-infrastructure-design.md](../specs/2026-05-30-test-infrastructure-design.md)

---

## File Structure

### New files in `lib/`

| Path | Responsibility |
|---|---|
| `lib/shard_test.dart` | Public entry point for testing utilities; re-exports `lib/src/testing/testing.dart`. Never imported by `lib/shard.dart`. |
| `lib/src/observability/logging_observer.dart` | `LoggingObserver` — debug-build `ShardObserver` that logs state changes and errors via `dart:developer`. |
| `lib/src/testing/testing.dart` | Bundle export of all testing utilities. |
| `lib/src/testing/shard_tester.dart` | `ShardTester<T>`, `ShardAssertionError`, `ShardTimeoutError`, and `shardTest()` declarative helper. |
| `lib/src/testing/fake_state_storage.dart` | `FakeStateStorage` — in-memory `StateStorage` with failure injection. |
| `lib/src/testing/fake_cache_service.dart` | `FakeCacheService` — in-memory `CacheService` with failure injection. |
| `lib/src/testing/mock_shard_observer.dart` | `MockShardObserver`, `ObservedChange<T>`, `ObservedError`. |

### Modified files in `lib/`

| Path | Change |
|---|---|
| `lib/shard.dart` | Add one line: `export 'src/observability/logging_observer.dart';` |

### New test files under `test/`

```
test/
  state_management/
    shard_test.dart
    future_shard_test.dart
    stream_shard_test.dart
    async_value_test.dart
    debounce_throttle_test.dart
    shard_observer_test.dart
  persistence/
    state_persistence_test.dart
    persistent_shard_test.dart
    primitive_serializers_test.dart
    state_serializer_test.dart
  caching/
    memory_cache_service_test.dart
    cache_mixin_test.dart
    cache_entry_test.dart
  locator/
    shard_locator_test.dart
  widgets/
    shard_provider_test.dart
    shard_builder_test.dart
    shard_selector_test.dart
    async_shard_builder_test.dart
    multi_shard_provider_test.dart
    context_extensions_test.dart
```

### Modified files outside `lib/`

| Path | Change |
|---|---|
| `pubspec.yaml` | Add `fake_async: ^1.3.1` under `dev_dependencies`. |
| `README.md` | Add a "Testing your shards" section with a `package:shard/shard_test.dart` snippet. Add a `LoggingObserver` entry under "What's Included". |

---

## Phase 1 — Foundation

### Task 1: Add `fake_async` dev dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Open pubspec.yaml and add fake_async to dev_dependencies**

Modify the `dev_dependencies` block:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  fake_async: ^1.3.1
```

- [ ] **Step 2: Fetch the new dependency**

Run: `flutter pub get`
Expected: succeeds; `.dart_tool/package_config.json` now includes `fake_async`.

- [ ] **Step 3: Verify it is dev-only**

Run: `flutter pub deps --no-dev --style=compact`
Expected output: `fake_async` is NOT listed. Only `flutter`, `sky_engine`, and standard SDK packages appear.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add fake_async dev dependency for timing tests"
```

---

### Task 2: Implement `LoggingObserver`

**Files:**
- Create: `lib/src/observability/logging_observer.dart`
- Modify: `lib/shard.dart`
- Test: `test/observability/logging_observer_test.dart`

- [ ] **Step 1: Create the test file with failing tests**

Create `test/observability/logging_observer_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

class _CounterShard extends Shard<int> {
  _CounterShard() : super(0);
  void increment() => emit(state + 1);
  void fail() => addError(Exception('boom'), StackTrace.current);
}

void main() {
  setUp(() {
    Shard.observer = null;
  });

  group('LoggingObserver', () {
    test('logs onChange to custom printer', () {
      final lines = <String>[];
      Shard.observer = LoggingObserver(
        enabled: true,
        printer: lines.add,
      );

      final shard = _CounterShard();
      shard.increment();

      expect(lines, hasLength(1));
      expect(lines.first, contains('_CounterShard'));
      expect(lines.first, contains('0'));
      expect(lines.first, contains('1'));

      shard.dispose();
    });

    test('logs onError to custom printer', () {
      final lines = <String>[];
      Shard.observer = LoggingObserver(
        enabled: true,
        printer: lines.add,
      );

      final shard = _CounterShard();
      shard.fail();

      expect(lines, hasLength(1));
      expect(lines.first, contains('ERROR'));
      expect(lines.first, contains('boom'));

      shard.dispose();
    });

    test('disabled observer logs nothing', () {
      final lines = <String>[];
      Shard.observer = LoggingObserver(
        enabled: false,
        printer: lines.add,
      );

      final shard = _CounterShard();
      shard.increment();
      shard.fail();

      expect(lines, isEmpty);
      shard.dispose();
    });

    test('logChanges: false suppresses change logs only', () {
      final lines = <String>[];
      Shard.observer = LoggingObserver(
        enabled: true,
        logChanges: false,
        printer: lines.add,
      );

      final shard = _CounterShard();
      shard.increment();
      shard.fail();

      expect(lines, hasLength(1));
      expect(lines.first, contains('ERROR'));
      shard.dispose();
    });

    test('logErrors: false suppresses error logs only', () {
      final lines = <String>[];
      Shard.observer = LoggingObserver(
        enabled: true,
        logErrors: false,
        printer: lines.add,
      );

      final shard = _CounterShard();
      shard.increment();
      shard.fail();

      expect(lines, hasLength(1));
      expect(lines.first, isNot(contains('ERROR')));
      shard.dispose();
    });

    test('shouldLog predicate filters shards', () {
      final lines = <String>[];
      Shard.observer = LoggingObserver(
        enabled: true,
        shouldLog: (s) => false,
        printer: lines.add,
      );

      final shard = _CounterShard();
      shard.increment();
      shard.fail();

      expect(lines, isEmpty);
      shard.dispose();
    });

    test('includeStackTrace appends trace to error logs', () {
      final lines = <String>[];
      Shard.observer = LoggingObserver(
        enabled: true,
        includeStackTrace: true,
        printer: lines.add,
      );

      final shard = _CounterShard();
      shard.fail();

      expect(lines, hasLength(1));
      expect(lines.first.split('\n').length, greaterThan(1));
      shard.dispose();
    });
  });
}
```

- [ ] **Step 2: Run tests; they must fail with import error**

Run: `flutter test test/observability/logging_observer_test.dart`
Expected: FAIL — `LoggingObserver` is undefined.

- [ ] **Step 3: Create `lib/src/observability/logging_observer.dart`**

```dart
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../state_management/shard.dart';
import '../state_management/shard_observer.dart';

/// A [ShardObserver] that logs state changes and errors during debug builds.
///
/// By default, [enabled] is set to [kDebugMode], so the observer is inert in
/// release builds — no formatting cost and no risk of leaking PII-containing
/// state values through logs. Pass `enabled: true` to force logging on.
///
/// The default sink is `dart:developer.log(name: 'shard')`, which integrates
/// with the Flutter DevTools Logging tab. Provide a [printer] to route messages
/// to a custom sink (Crashlytics, Sentry, file logger, etc.).
///
/// ## Usage
///
/// ```dart
/// void main() {
///   Shard.observer = LoggingObserver();
///   runApp(MyApp());
/// }
/// ```
///
/// Filter specific shards:
///
/// ```dart
/// Shard.observer = LoggingObserver(
///   shouldLog: (shard) => shard is! NoisyShard,
/// );
/// ```
class LoggingObserver extends ShardObserver {
  /// Creates a [LoggingObserver].
  ///
  /// - [enabled] - If null, defaults to [kDebugMode]. Pass true to force on.
  /// - [logChanges] - Whether to log `onChange` events. Default `true`.
  /// - [logErrors] - Whether to log `onError` events. Default `true`.
  /// - [includeStackTrace] - Append stack trace to error logs. Default `false`.
  /// - [printer] - Optional custom sink. Default uses `dart:developer.log`.
  /// - [shouldLog] - Optional predicate; return false to skip a shard.
  LoggingObserver({
    bool? enabled,
    this.logChanges = true,
    this.logErrors = true,
    this.includeStackTrace = false,
    this.printer,
    this.shouldLog,
  }) : enabled = enabled ?? kDebugMode;

  /// Whether this observer emits any log lines.
  final bool enabled;

  /// Whether `onChange` events are logged.
  final bool logChanges;

  /// Whether `onError` events are logged.
  final bool logErrors;

  /// Whether to append the stack trace to error log lines.
  final bool includeStackTrace;

  /// Custom log sink. When null, uses `dart:developer.log(name: 'shard')`.
  final void Function(String message)? printer;

  /// Optional filter; return false to skip logging a specific shard.
  final bool Function(Shard shard)? shouldLog;

  @override
  void onChange<T>(Shard<T> shard, T previousState, T currentState) {
    if (!enabled || !logChanges) return;
    if (shouldLog != null && !shouldLog!(shard)) return;
    _write('[${shard.runtimeType}] $previousState → $currentState');
  }

  @override
  void onError<T>(Shard<T> shard, Object error, StackTrace? stackTrace) {
    if (!enabled || !logErrors) return;
    if (shouldLog != null && !shouldLog!(shard)) return;
    final trace = includeStackTrace && stackTrace != null ? '\n$stackTrace' : '';
    _write('[${shard.runtimeType}] ERROR: $error$trace');
  }

  void _write(String message) {
    if (printer != null) {
      printer!(message);
    } else {
      developer.log(message, name: 'shard');
    }
  }
}
```

- [ ] **Step 4: Re-export `LoggingObserver` from `lib/shard.dart`**

Open `lib/shard.dart`. It currently contains a single export. Add one line so it reads:

```dart
export 'src/src.dart';
export 'src/observability/logging_observer.dart';
```

- [ ] **Step 5: Run tests; they should pass**

Run: `flutter test test/observability/logging_observer_test.dart`
Expected: PASS — all 7 tests green.

- [ ] **Step 6: Verify lint is clean**

Run: `dart analyze lib/src/observability/`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/src/observability/logging_observer.dart lib/shard.dart test/observability/logging_observer_test.dart
git commit -m "feat: add LoggingObserver for debug-build state observability"
```

---

## Phase 2 — Testing Utilities

### Task 3: Implement `FakeStateStorage`

**Files:**
- Create: `lib/src/testing/fake_state_storage.dart`
- Test: `test/testing/fake_state_storage_test.dart`

- [ ] **Step 1: Create failing tests**

Create `test/testing/fake_state_storage_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/src/testing/fake_state_storage.dart';

void main() {
  group('FakeStateStorage', () {
    test('save and load roundtrip', () async {
      final storage = FakeStateStorage();
      await storage.save('k', 'v');
      expect(await storage.load('k'), 'v');
    });

    test('load returns null for missing key', () async {
      final storage = FakeStateStorage();
      expect(await storage.load('missing'), isNull);
    });

    test('constructor seeds initial data', () async {
      final storage = FakeStateStorage(initialData: {'k': 'v'});
      expect(await storage.load('k'), 'v');
      expect(storage.rawValue('k'), 'v');
    });

    test('seed adds data after construction', () async {
      final storage = FakeStateStorage();
      storage.seed('k', 'v');
      expect(await storage.load('k'), 'v');
    });

    test('saveCount increments per save', () async {
      final storage = FakeStateStorage();
      await storage.save('a', '1');
      await storage.save('b', '2');
      await storage.save('a', '3');
      expect(storage.saveCount, 3);
      expect(storage.savedKeys, ['a', 'b', 'a']);
    });

    test('loadCount increments per load', () async {
      final storage = FakeStateStorage();
      await storage.load('a');
      await storage.load('a');
      expect(storage.loadCount, 2);
    });

    test('loadError throws on load', () async {
      final storage = FakeStateStorage()..loadError = StateError('boom');
      await expectLater(storage.load('k'), throwsA(isA<StateError>()));
    });

    test('saveError throws on save', () async {
      final storage = FakeStateStorage()..saveError = StateError('boom');
      await expectLater(storage.save('k', 'v'), throwsA(isA<StateError>()));
    });

    test('loadDelay delays load completion', () async {
      final storage = FakeStateStorage()..loadDelay = const Duration(milliseconds: 50);
      final sw = Stopwatch()..start();
      await storage.load('k');
      sw.stop();
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(40));
    });

    test('hasKey reflects current state', () async {
      final storage = FakeStateStorage();
      expect(storage.hasKey('k'), isFalse);
      await storage.save('k', 'v');
      expect(storage.hasKey('k'), isTrue);
    });

    test('data returns unmodifiable map', () async {
      final storage = FakeStateStorage();
      await storage.save('k', 'v');
      final view = storage.data;
      expect(() => view['x'] = 'y', throwsUnsupportedError);
    });

    test('clear wipes data, keeps counters', () async {
      final storage = FakeStateStorage();
      await storage.save('k', 'v');
      storage.clear();
      expect(await storage.load('k'), isNull);
      expect(storage.saveCount, 1);
    });

    test('reset wipes data, counters, errors, delays', () async {
      final storage = FakeStateStorage()
        ..loadError = StateError('x')
        ..saveDelay = const Duration(seconds: 1);
      await storage.save('k', 'v');
      storage.reset();
      expect(storage.saveCount, 0);
      expect(storage.loadError, isNull);
      expect(storage.saveDelay, isNull);
      expect(await storage.load('k'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run; fail with missing import**

Run: `flutter test test/testing/fake_state_storage_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement `FakeStateStorage`**

Create `lib/src/testing/fake_state_storage.dart`:

```dart
import '../persistence/storage.dart';

/// An in-memory [StateStorage] implementation for use in tests.
///
/// Supports seeded initial data, failure injection, latency simulation,
/// and call inspection (counts and recorded keys).
///
/// ```dart
/// final storage = FakeStateStorage()
///   ..seed('user', '{"id":1}')
///   ..loadError = Exception('disk read failed');
/// ```
class FakeStateStorage implements StateStorage {
  /// Creates a [FakeStateStorage], optionally pre-populated with [initialData].
  FakeStateStorage({Map<String, String>? initialData}) {
    if (initialData != null) _data.addAll(initialData);
  }

  final Map<String, String> _data = {};
  final List<String> _savedKeys = [];

  /// If non-null, [load] throws this object instead of returning a value.
  Object? loadError;

  /// If non-null, [save] throws this object instead of recording the write.
  Object? saveError;

  /// If non-null, [load] awaits this duration before completing.
  Duration? loadDelay;

  /// If non-null, [save] awaits this duration before completing.
  Duration? saveDelay;

  /// Total number of [load] calls since construction (or last [reset]).
  int loadCount = 0;

  /// Total number of [save] calls since construction (or last [reset]).
  int saveCount = 0;

  /// All keys passed to [save], in order, including duplicates.
  List<String> get savedKeys => List.unmodifiable(_savedKeys);

  /// An unmodifiable view of the underlying key→value map.
  Map<String, String> get data => Map.unmodifiable(_data);

  /// Whether [key] is currently present in storage.
  bool hasKey(String key) => _data.containsKey(key);

  /// The raw serialized value for [key], or null if missing.
  String? rawValue(String key) => _data[key];

  /// Writes [value] into the in-memory map without counting as a [save] call.
  void seed(String key, String value) {
    _data[key] = value;
  }

  /// Wipes stored data; preserves counters, errors, and delays.
  void clear() {
    _data.clear();
  }

  /// Wipes all internal state — data, counters, errors, and delays.
  void reset() {
    _data.clear();
    _savedKeys.clear();
    loadCount = 0;
    saveCount = 0;
    loadError = null;
    saveError = null;
    loadDelay = null;
    saveDelay = null;
  }

  @override
  Future<void> save(String key, String value) async {
    saveCount++;
    _savedKeys.add(key);
    if (saveDelay != null) await Future<void>.delayed(saveDelay!);
    if (saveError != null) throw saveError!;
    _data[key] = value;
  }

  @override
  Future<String?> load(String key) async {
    loadCount++;
    if (loadDelay != null) await Future<void>.delayed(loadDelay!);
    if (loadError != null) throw loadError!;
    return _data[key];
  }
}
```

- [ ] **Step 4: Run; tests pass**

Run: `flutter test test/testing/fake_state_storage_test.dart`
Expected: PASS — all 13 tests green.

- [ ] **Step 5: Commit**

```bash
git add lib/src/testing/fake_state_storage.dart test/testing/fake_state_storage_test.dart
git commit -m "feat(testing): add FakeStateStorage for persistence tests"
```

---

### Task 4: Implement `FakeCacheService`

**Files:**
- Create: `lib/src/testing/fake_cache_service.dart`
- Test: `test/testing/fake_cache_service_test.dart`

- [ ] **Step 1: Create failing tests**

Create `test/testing/fake_cache_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/src/testing/fake_cache_service.dart';

void main() {
  group('FakeCacheService', () {
    test('write and read roundtrip', () async {
      final cache = FakeCacheService();
      final entry = CacheEntry(
        data: 42,
        expiryDate: DateTime.now().add(const Duration(hours: 1)),
      );
      await cache.write('k', entry);
      final read = await cache.read('k');
      expect(read?.data, 42);
    });

    test('read returns null for missing key', () async {
      final cache = FakeCacheService();
      expect(await cache.read('missing'), isNull);
    });

    test('seed pre-populates with fresh entry', () async {
      final cache = FakeCacheService();
      cache.seed('k', 99);
      final read = await cache.read('k');
      expect(read?.data, 99);
      expect(read?.isExpired, isFalse);
    });

    test('seedExpired pre-populates with already-expired entry', () async {
      final cache = FakeCacheService();
      cache.seedExpired('k', 'stale');
      final read = await cache.read('k');
      expect(read?.data, 'stale');
      expect(read?.isExpired, isTrue);
    });

    test('delete removes entry', () async {
      final cache = FakeCacheService();
      cache.seed('k', 1);
      await cache.delete('k');
      expect(await cache.read('k'), isNull);
      expect(cache.deleteCount, 1);
    });

    test('clearAll empties everything', () async {
      final cache = FakeCacheService();
      cache.seed('a', 1);
      cache.seed('b', 2);
      await cache.clearAll();
      expect(cache.entries, isEmpty);
    });

    test('counters and key lists update', () async {
      final cache = FakeCacheService();
      await cache.write('a', CacheEntry(data: 1, expiryDate: DateTime.now()));
      await cache.read('a');
      await cache.read('b');
      expect(cache.writeCount, 1);
      expect(cache.readCount, 2);
      expect(cache.writeKeys, ['a']);
      expect(cache.readKeys, ['a', 'b']);
    });

    test('readError throws on read', () async {
      final cache = FakeCacheService()..readError = StateError('boom');
      await expectLater(cache.read('k'), throwsA(isA<StateError>()));
    });

    test('writeError throws on write', () async {
      final cache = FakeCacheService()..writeError = StateError('boom');
      await expectLater(
        cache.write('k', CacheEntry(data: 1, expiryDate: DateTime.now())),
        throwsA(isA<StateError>()),
      );
    });

    test('deleteError throws on delete', () async {
      final cache = FakeCacheService()..deleteError = StateError('boom');
      await expectLater(cache.delete('k'), throwsA(isA<StateError>()));
    });

    test('clearError throws on clearAll', () async {
      final cache = FakeCacheService()..clearError = StateError('boom');
      await expectLater(cache.clearAll(), throwsA(isA<StateError>()));
    });

    test('reset clears data, counters, errors, delays', () async {
      final cache = FakeCacheService()
        ..readError = StateError('x')
        ..readDelay = const Duration(seconds: 1);
      cache.seed('k', 1);
      cache.reset();
      expect(cache.entries, isEmpty);
      expect(cache.readCount, 0);
      expect(cache.readError, isNull);
      expect(cache.readDelay, isNull);
    });

    test('clear wipes data but keeps counters', () async {
      final cache = FakeCacheService();
      await cache.write('k', CacheEntry(data: 1, expiryDate: DateTime.now()));
      cache.clear();
      expect(cache.entries, isEmpty);
      expect(cache.writeCount, 1);
    });
  });
}
```

- [ ] **Step 2: Run; fail**

Run: `flutter test test/testing/fake_cache_service_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement `FakeCacheService`**

Create `lib/src/testing/fake_cache_service.dart`:

```dart
import '../caching/cache_entry.dart';
import '../caching/cache_service.dart';

/// An in-memory [CacheService] implementation for use in tests.
///
/// Supports seeded initial entries (fresh or expired), failure injection
/// for read/write/delete/clearAll, latency simulation, and call inspection.
///
/// ```dart
/// final cache = FakeCacheService()
///   ..seed('user_1', User(id: 1, name: 'Alice'))
///   ..readError = Exception('cache offline');
/// ```
class FakeCacheService implements CacheService {
  /// Creates a [FakeCacheService], optionally pre-populated with [initialData].
  FakeCacheService({Map<String, CacheEntry>? initialData}) {
    if (initialData != null) _data.addAll(initialData);
  }

  final Map<String, CacheEntry> _data = {};
  final List<String> _readKeys = [];
  final List<String> _writeKeys = [];

  /// If non-null, [read] throws instead of returning.
  Object? readError;

  /// If non-null, [write] throws.
  Object? writeError;

  /// If non-null, [delete] throws.
  Object? deleteError;

  /// If non-null, [clearAll] throws.
  Object? clearError;

  /// If non-null, [read] awaits this duration before completing.
  Duration? readDelay;

  /// If non-null, [write] awaits this duration before completing.
  Duration? writeDelay;

  /// Number of [read] calls since construction (or last [reset]).
  int readCount = 0;

  /// Number of [write] calls.
  int writeCount = 0;

  /// Number of [delete] calls.
  int deleteCount = 0;

  /// Keys passed to [read], in order.
  List<String> get readKeys => List.unmodifiable(_readKeys);

  /// Keys passed to [write], in order.
  List<String> get writeKeys => List.unmodifiable(_writeKeys);

  /// Unmodifiable view of stored entries.
  Map<String, CacheEntry> get entries => Map.unmodifiable(_data);

  /// Whether [key] is currently present in the cache.
  bool hasKey(String key) => _data.containsKey(key);

  /// Pre-populates a fresh entry that expires in [ttl] (default 1 hour).
  void seed(String key, Object? data, {Duration ttl = const Duration(hours: 1)}) {
    _data[key] = CacheEntry(data: data, expiryDate: DateTime.now().add(ttl));
  }

  /// Pre-populates an entry already expired (expiry at epoch 0).
  void seedExpired(String key, Object? data) {
    _data[key] = CacheEntry(
      data: data,
      expiryDate: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  /// Wipes stored entries; preserves counters, errors, and delays.
  void clear() {
    _data.clear();
  }

  /// Wipes everything — data, counters, errors, delays.
  void reset() {
    _data.clear();
    _readKeys.clear();
    _writeKeys.clear();
    readCount = 0;
    writeCount = 0;
    deleteCount = 0;
    readError = null;
    writeError = null;
    deleteError = null;
    clearError = null;
    readDelay = null;
    writeDelay = null;
  }

  @override
  Future<void> write(String key, CacheEntry entry) async {
    writeCount++;
    _writeKeys.add(key);
    if (writeDelay != null) await Future<void>.delayed(writeDelay!);
    if (writeError != null) throw writeError!;
    _data[key] = entry;
  }

  @override
  Future<CacheEntry?> read(String key) async {
    readCount++;
    _readKeys.add(key);
    if (readDelay != null) await Future<void>.delayed(readDelay!);
    if (readError != null) throw readError!;
    return _data[key];
  }

  @override
  Future<void> delete(String key) async {
    deleteCount++;
    if (deleteError != null) throw deleteError!;
    _data.remove(key);
  }

  @override
  Future<void> clearAll() async {
    if (clearError != null) throw clearError!;
    _data.clear();
  }
}
```

- [ ] **Step 4: Run; pass**

Run: `flutter test test/testing/fake_cache_service_test.dart`
Expected: PASS — all 13 tests green.

- [ ] **Step 5: Commit**

```bash
git add lib/src/testing/fake_cache_service.dart test/testing/fake_cache_service_test.dart
git commit -m "feat(testing): add FakeCacheService for caching tests"
```

---

### Task 5: Implement `MockShardObserver`

**Files:**
- Create: `lib/src/testing/mock_shard_observer.dart`
- Test: `test/testing/mock_shard_observer_test.dart`

- [ ] **Step 1: Create failing tests**

Create `test/testing/mock_shard_observer_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/src/testing/mock_shard_observer.dart';

class _CounterShard extends Shard<int> {
  _CounterShard() : super(0);
  void inc() => emit(state + 1);
  void fail() => addError(Exception('boom'), StackTrace.current);
}

class _StringShard extends Shard<String> {
  _StringShard() : super('');
  void set(String v) => emit(v);
}

void main() {
  setUp(() {
    Shard.observer = null;
  });

  group('MockShardObserver', () {
    test('records onChange events', () {
      final observer = MockShardObserver();
      Shard.observer = observer;

      final shard = _CounterShard();
      shard.inc();
      shard.inc();

      expect(observer.recordedChanges, hasLength(2));
      expect(observer.recordedChanges[0].previousState, 0);
      expect(observer.recordedChanges[0].currentState, 1);
      expect(observer.recordedChanges[1].previousState, 1);
      expect(observer.recordedChanges[1].currentState, 2);

      shard.dispose();
    });

    test('records onError events', () {
      final observer = MockShardObserver();
      Shard.observer = observer;

      final shard = _CounterShard();
      shard.fail();

      expect(observer.recordedErrors, hasLength(1));
      expect(observer.recordedErrors.first.error, isA<Exception>());

      shard.dispose();
    });

    test('changesFor filters by shard identity', () {
      final observer = MockShardObserver();
      Shard.observer = observer;

      final a = _CounterShard();
      final b = _CounterShard();
      a.inc();
      b.inc();
      a.inc();

      expect(observer.changesFor(a), hasLength(2));
      expect(observer.changesFor(b), hasLength(1));

      a.dispose();
      b.dispose();
    });

    test('changesOfType filters by generic state type', () {
      final observer = MockShardObserver();
      Shard.observer = observer;

      final counter = _CounterShard();
      final text = _StringShard();
      counter.inc();
      text.set('hi');

      expect(observer.changesOfType<int>(), hasLength(1));
      expect(observer.changesOfType<String>(), hasLength(1));

      counter.dispose();
      text.dispose();
    });

    test('errorsFor filters by shard identity', () {
      final observer = MockShardObserver();
      Shard.observer = observer;

      final a = _CounterShard();
      final b = _CounterShard();
      a.fail();
      b.fail();
      a.fail();

      expect(observer.errorsFor(a), hasLength(2));
      expect(observer.errorsFor(b), hasLength(1));

      a.dispose();
      b.dispose();
    });

    test('clear empties recorded lists', () {
      final observer = MockShardObserver();
      Shard.observer = observer;

      final shard = _CounterShard();
      shard.inc();
      shard.fail();
      observer.clear();

      expect(observer.recordedChanges, isEmpty);
      expect(observer.recordedErrors, isEmpty);

      shard.dispose();
    });

    test('scope installs and restores observer', () async {
      final previous = _SilentObserver();
      Shard.observer = previous;

      final result = await MockShardObserver.scope((mock) async {
        expect(Shard.observer, same(mock));
        final shard = _CounterShard();
        shard.inc();
        addTearDown(shard.dispose);
        return mock.recordedChanges.length;
      });

      expect(result, 1);
      expect(Shard.observer, same(previous));
    });

    test('scope restores observer even when body throws', () async {
      final previous = _SilentObserver();
      Shard.observer = previous;

      await expectLater(
        MockShardObserver.scope<void>((_) async => throw StateError('boom')),
        throwsA(isA<StateError>()),
      );
      expect(Shard.observer, same(previous));
    });
  });
}

class _SilentObserver extends ShardObserver {}
```

- [ ] **Step 2: Run; fail**

Run: `flutter test test/testing/mock_shard_observer_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement `MockShardObserver`**

Create `lib/src/testing/mock_shard_observer.dart`:

```dart
import '../state_management/shard.dart';
import '../state_management/shard_observer.dart';

/// A single observed `onChange` event captured by [MockShardObserver].
class ObservedChange<T> {
  /// Creates an [ObservedChange] record.
  const ObservedChange(this.shard, this.previousState, this.currentState);

  /// The shard whose state changed.
  final Shard<T> shard;

  /// The state before the change.
  final T previousState;

  /// The state after the change.
  final T currentState;

  @override
  String toString() =>
      'ObservedChange<$T>($shard, $previousState → $currentState)';
}

/// A single observed `onError` event captured by [MockShardObserver].
class ObservedError {
  /// Creates an [ObservedError] record.
  const ObservedError(this.shard, this.error, this.stackTrace);

  /// The shard that reported the error.
  final Shard shard;

  /// The error object.
  final Object error;

  /// The stack trace, if provided.
  final StackTrace? stackTrace;

  @override
  String toString() => 'ObservedError($shard, $error)';
}

/// A [ShardObserver] that records all events for inspection in tests.
///
/// Because `Shard.observer` is a global static, prefer [scope] over manual
/// install/uninstall to avoid cross-test pollution.
///
/// ```dart
/// await MockShardObserver.scope((observer) async {
///   final shard = MyShard();
///   addTearDown(shard.dispose);
///   shard.doSomething();
///   expect(observer.changesFor(shard), hasLength(1));
/// });
/// ```
class MockShardObserver extends ShardObserver {
  /// Creates a fresh [MockShardObserver] with empty recordings.
  MockShardObserver();

  final List<ObservedChange> _changes = [];
  final List<ObservedError> _errors = [];

  /// All recorded change events, in order.
  List<ObservedChange> get recordedChanges => List.unmodifiable(_changes);

  /// All recorded error events, in order.
  List<ObservedError> get recordedErrors => List.unmodifiable(_errors);

  /// Recorded changes whose shard is [shard] (identity comparison).
  List<ObservedChange<T>> changesFor<T>(Shard<T> shard) {
    return _changes
        .where((c) => identical(c.shard, shard))
        .cast<ObservedChange<T>>()
        .toList(growable: false);
  }

  /// Recorded errors whose shard is [shard] (identity comparison).
  List<ObservedError> errorsFor(Shard shard) {
    return _errors
        .where((e) => identical(e.shard, shard))
        .toList(growable: false);
  }

  /// All recorded changes for any `Shard<T>` of the given state type.
  List<ObservedChange<T>> changesOfType<T>() {
    return _changes.whereType<ObservedChange<T>>().toList(growable: false);
  }

  /// All recorded errors whose shard is of runtime type [S].
  List<ObservedError> errorsOfType<S extends Shard>() {
    return _errors.where((e) => e.shard is S).toList(growable: false);
  }

  /// Clears all recorded events.
  void clear() {
    _changes.clear();
    _errors.clear();
  }

  /// Installs a fresh [MockShardObserver] as the global observer for the
  /// duration of [body], then restores whatever observer was previously set
  /// (including null) in a `finally` block.
  static Future<R> scope<R>(
    Future<R> Function(MockShardObserver observer) body,
  ) async {
    final previous = Shard.observer;
    final observer = MockShardObserver();
    Shard.observer = observer;
    try {
      return await body(observer);
    } finally {
      Shard.observer = previous;
    }
  }

  @override
  void onChange<T>(Shard<T> shard, T previousState, T currentState) {
    _changes.add(ObservedChange<T>(shard, previousState, currentState));
  }

  @override
  void onError<T>(Shard<T> shard, Object error, StackTrace? stackTrace) {
    _errors.add(ObservedError(shard, error, stackTrace));
  }
}
```

- [ ] **Step 4: Run; pass**

Run: `flutter test test/testing/mock_shard_observer_test.dart`
Expected: PASS — all 8 tests green.

- [ ] **Step 5: Commit**

```bash
git add lib/src/testing/mock_shard_observer.dart test/testing/mock_shard_observer_test.dart
git commit -m "feat(testing): add MockShardObserver with scope helper"
```

---

### Task 6: Implement `ShardTester` — capture, dispose, scope

**Files:**
- Create: `lib/src/testing/shard_tester.dart`
- Test: `test/testing/shard_tester_capture_test.dart`

- [ ] **Step 1: Create failing tests for basic capture**

Create `test/testing/shard_tester_capture_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/src/testing/shard_tester.dart';

class _CounterShard extends Shard<int> {
  _CounterShard() : super(0);
  void inc() => emit(state + 1);
}

void main() {
  group('ShardTester — capture', () {
    test('recordedStates is empty initially', () {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      expect(tester.recordedStates, isEmpty);
      expect(tester.hasStates, isFalse);
      expect(tester.lastState, isNull);
      tester.dispose();
      shard.dispose();
    });

    test('records emissions in order', () {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      shard.inc();
      shard.inc();
      shard.inc();
      expect(tester.recordedStates, [1, 2, 3]);
      expect(tester.hasStates, isTrue);
      expect(tester.lastState, 3);
      tester.dispose();
      shard.dispose();
    });

    test('initial state is excluded', () {
      final shard = _CounterShard();
      // shard.state == 0 here.
      final tester = ShardTester(shard);
      shard.inc();
      expect(tester.recordedStates, [1]);
      tester.dispose();
      shard.dispose();
    });

    test('clear empties recordedStates without unsubscribing', () {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      shard.inc();
      tester.clear();
      shard.inc();
      expect(tester.recordedStates, [2]);
      tester.dispose();
      shard.dispose();
    });

    test('dispose stops further recording', () {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      tester.dispose();
      shard.inc();
      expect(tester.recordedStates, isEmpty);
      shard.dispose();
    });

    test('recordedStates is unmodifiable', () {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      expect(() => tester.recordedStates.add(99), throwsUnsupportedError);
      tester.dispose();
      shard.dispose();
    });

    test('scope creates and disposes tester', () async {
      final shard = _CounterShard();
      final result = await ShardTester.scope<int, int>(shard, (tester) async {
        shard.inc();
        shard.inc();
        return tester.recordedStates.length;
      });
      expect(result, 2);
      // After scope, listener was removed; further changes are not recorded by it.
      shard.dispose();
    });

    test('scope restores even when body throws', () async {
      final shard = _CounterShard();
      await expectLater(
        ShardTester.scope<int, void>(shard, (_) async => throw StateError('x')),
        throwsA(isA<StateError>()),
      );
      // No exception from dispose; shard is still usable.
      shard.inc();
      shard.dispose();
    });
  });
}
```

- [ ] **Step 2: Run; fail**

Run: `flutter test test/testing/shard_tester_capture_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement minimal `ShardTester` (capture-only)**

Create `lib/src/testing/shard_tester.dart`:

```dart
import 'dart:async';

import '../state_management/shard.dart';

/// Thrown by [ShardTester] when an assertion fails.
class ShardAssertionError extends Error {
  /// Creates a [ShardAssertionError] with a human-readable [message].
  ShardAssertionError(this.message);

  /// The failure message, including expected vs. actual when applicable.
  final String message;

  @override
  String toString() => 'ShardAssertionError: $message';
}

/// Thrown by [ShardTester] when an async wait exceeds its timeout.
class ShardTimeoutError extends Error {
  /// Creates a [ShardTimeoutError] with a human-readable [message].
  ShardTimeoutError(this.message);

  /// The timeout failure message.
  final String message;

  @override
  String toString() => 'ShardTimeoutError: $message';
}

/// A helper for testing [Shard] subclasses by capturing emissions, waiting
/// for specific states, and asserting state sequences.
///
/// ```dart
/// final shard = CounterShard();
/// final tester = ShardTester(shard);
/// addTearDown(tester.dispose);
/// addTearDown(shard.dispose);
///
/// shard.increment();
/// shard.increment();
/// await tester.expectStates([1, 2]);
/// ```
///
/// `ShardTester` does not depend on `flutter_test` matchers; it raises
/// [ShardAssertionError] / [ShardTimeoutError] which the surrounding test
/// framework treats as failures.
class ShardTester<T> {
  /// Subscribes to [shard] and starts recording emissions.
  ///
  /// The initial state (`shard.state` at construction time) is NOT recorded;
  /// only emissions after construction are captured.
  ShardTester(this._shard) {
    _shard.addListener(_onChange);
  }

  final Shard<T> _shard;
  final List<T> _states = [];
  final List<_PendingWait<T>> _waiters = [];
  bool _isDisposed = false;

  /// The shard being observed.
  Shard<T> get shard => _shard;

  /// All states emitted since construction, in order.
  List<T> get recordedStates => List.unmodifiable(_states);

  /// The most recent recorded state, or null if none.
  T? get lastState => _states.isEmpty ? null : _states.last;

  /// Whether at least one state has been recorded.
  bool get hasStates => _states.isNotEmpty;

  /// Empties [recordedStates] without unsubscribing.
  ///
  /// Useful for multi-phase tests where each phase asserts a fresh subset.
  void clear() {
    _states.clear();
  }

  /// Removes the listener and fails any pending waiters.
  ///
  /// Safe to call multiple times. Safe to call after the underlying [Shard]
  /// has already been disposed — the listener removal is skipped in that
  /// case because `ChangeNotifier.removeListener` after `dispose()` throws.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    if (!_shard.isDisposed) {
      _shard.removeListener(_onChange);
    }
    for (final w in _waiters) {
      if (!w.completer.isCompleted) {
        w.completer.completeError(
          StateError('ShardTester disposed while waiting'),
        );
      }
    }
    _waiters.clear();
  }

  /// Creates a [ShardTester] around [shard], runs [body], and disposes the
  /// tester in a `finally` block. Returns whatever [body] returns.
  ///
  /// Type parameter `S` is the shard's state type (named `S` to avoid
  /// shadowing the outer class's `T` in this static method).
  static Future<R> scope<S, R>(
    Shard<S> shard,
    Future<R> Function(ShardTester<S> tester) body,
  ) async {
    final tester = ShardTester<S>(shard);
    try {
      return await body(tester);
    } finally {
      await tester.dispose();
    }
  }

  void _onChange() {
    if (_isDisposed) return;
    final newState = _shard.state;
    _states.add(newState);
    final satisfied = <_PendingWait<T>>[];
    for (final w in _waiters) {
      if (w.predicate == null || w.predicate!(newState)) {
        if (!w.completer.isCompleted) w.completer.complete(newState);
        satisfied.add(w);
      }
    }
    _waiters.removeWhere(satisfied.contains);
  }
}

class _PendingWait<T> {
  _PendingWait(this.completer, {this.predicate});
  final Completer<T> completer;
  final bool Function(T)? predicate;
}
```

- [ ] **Step 4: Run; pass**

Run: `flutter test test/testing/shard_tester_capture_test.dart`
Expected: PASS — all 8 tests green.

- [ ] **Step 5: Commit**

```bash
git add lib/src/testing/shard_tester.dart test/testing/shard_tester_capture_test.dart
git commit -m "feat(testing): add ShardTester core (capture/dispose/scope)"
```

---

### Task 7: Add `expectStates` and `expectNoMoreStates` to `ShardTester`

**Files:**
- Modify: `lib/src/testing/shard_tester.dart`
- Test: `test/testing/shard_tester_assertions_test.dart`

- [ ] **Step 1: Create failing assertion tests**

Create `test/testing/shard_tester_assertions_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/src/testing/shard_tester.dart';

class _CounterShard extends Shard<int> {
  _CounterShard() : super(0);
  void inc() => emit(state + 1);
}

void main() {
  group('ShardTester — expectStates', () {
    test('passes on prefix match (default)', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      shard.inc();
      shard.inc();
      shard.inc();
      await tester.expectStates([1, 2]); // extra state allowed
      await tester.dispose();
      shard.dispose();
    });

    test('passes on exact match when exactMatch: true', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      shard.inc();
      shard.inc();
      await tester.expectStates([1, 2], exactMatch: true);
      await tester.dispose();
      shard.dispose();
    });

    test('fails on mismatch with full diff in message', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      shard.inc();
      shard.inc();
      try {
        await tester.expectStates([1, 99]);
        fail('expected ShardAssertionError');
      } on ShardAssertionError catch (e) {
        expect(e.message, contains('[1, 99]'));
        expect(e.message, contains('[1, 2]'));
      }
      await tester.dispose();
      shard.dispose();
    });

    test('fails on exact match when extra states exist', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      shard.inc();
      shard.inc();
      shard.inc();
      await expectLater(
        tester.expectStates([1, 2], exactMatch: true),
        throwsA(isA<ShardAssertionError>()),
      );
      await tester.dispose();
      shard.dispose();
    });

    test('waits up to timeout for expected count', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      Future.delayed(const Duration(milliseconds: 30), shard.inc);
      Future.delayed(const Duration(milliseconds: 60), shard.inc);
      await tester.expectStates(
        [1, 2],
        timeout: const Duration(milliseconds: 500),
      );
      await tester.dispose();
      shard.dispose();
    });

    test('fails on timeout with partial states', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      shard.inc();
      await expectLater(
        tester.expectStates(
          [1, 2, 3],
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(isA<ShardAssertionError>()),
      );
      await tester.dispose();
      shard.dispose();
    });

    test('empty expected with exactMatch: true requires no emissions', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      await tester.expectStates(
        [],
        exactMatch: true,
        timeout: const Duration(milliseconds: 20),
      );
      await tester.dispose();
      shard.dispose();
    });

    test('empty expected with exactMatch: false is vacuously true', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      shard.inc(); // extra state, doesn't matter
      await tester.expectStates([]);
      await tester.dispose();
      shard.dispose();
    });
  });

  group('ShardTester — expectNoMoreStates', () {
    test('passes when no emissions occur within window', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      await tester.expectNoMoreStates(window: const Duration(milliseconds: 30));
      await tester.dispose();
      shard.dispose();
    });

    test('fails when a state arrives within window', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      Future.delayed(const Duration(milliseconds: 10), shard.inc);
      await expectLater(
        tester.expectNoMoreStates(window: const Duration(milliseconds: 50)),
        throwsA(isA<ShardAssertionError>()),
      );
      await tester.dispose();
      shard.dispose();
    });
  });
}
```

- [ ] **Step 2: Run; fail with missing methods**

Run: `flutter test test/testing/shard_tester_assertions_test.dart`
Expected: FAIL — `expectStates` / `expectNoMoreStates` not defined.

- [ ] **Step 3: Add `expectStates` and `expectNoMoreStates` to `ShardTester`**

Open `lib/src/testing/shard_tester.dart`. Inside the `ShardTester<T>` class, before the `_onChange` method, add:

```dart
  /// Asserts the recorded state sequence matches [expected] in order.
  ///
  /// By default the comparison is a prefix match: if [expected] has length N,
  /// only the first N entries of [recordedStates] are checked. Pass
  /// `exactMatch: true` to additionally require `recordedStates.length` to
  /// equal `expected.length`.
  ///
  /// If fewer than `expected.length` states have been recorded, waits up to
  /// [timeout] for more to arrive. After the timeout (or once enough states
  /// are collected) the comparison runs.
  ///
  /// Throws [ShardAssertionError] with full expected/actual diff on mismatch.
  Future<void> expectStates(
    List<T> expected, {
    Duration timeout = const Duration(seconds: 1),
    bool exactMatch = false,
  }) async {
    if (expected.isNotEmpty) {
      await _waitForCount(expected.length, timeout);
    } else if (exactMatch) {
      // Wait the full window to confirm no emissions arrived.
      await Future<void>.delayed(timeout);
    }

    if (exactMatch && _states.length != expected.length) {
      throw ShardAssertionError(
        'Expected exactly ${expected.length} states but recorded '
        '${_states.length}.\n'
        'Expected: $expected\n'
        'Actual:   $_states',
      );
    }
    if (_states.length < expected.length) {
      throw ShardAssertionError(
        'Expected at least ${expected.length} states but recorded only '
        '${_states.length}.\n'
        'Expected: $expected\n'
        'Actual:   $_states',
      );
    }
    for (var i = 0; i < expected.length; i++) {
      if (_states[i] != expected[i]) {
        throw ShardAssertionError(
          'State at index $i mismatch.\n'
          'Expected[$i]: ${expected[i]}\n'
          'Actual[$i]:   ${_states[i]}\n'
          'Expected: $expected\n'
          'Actual:   $_states',
        );
      }
    }
  }

  /// Asserts no states are emitted within [window].
  ///
  /// Useful for verifying debounce/throttle behavior or that a no-op did
  /// nothing. Snapshots `recordedStates.length` at call time and asserts
  /// that no new entries arrive before [window] elapses.
  Future<void> expectNoMoreStates({
    Duration window = const Duration(milliseconds: 100),
  }) async {
    final snapshot = _states.length;
    await Future<void>.delayed(window);
    if (_states.length > snapshot) {
      throw ShardAssertionError(
        'Expected no more states within $window but recorded '
        '${_states.length - snapshot} new state(s): '
        '${_states.sublist(snapshot)}',
      );
    }
  }

  Future<void> _waitForCount(int n, Duration timeout) async {
    if (_states.length >= n) return;
    final deadline = DateTime.now().add(timeout);
    while (_states.length < n) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) return;
      try {
        await _waitForNextInternal(remaining);
      } on ShardTimeoutError {
        return; // proceed to assertion, which will report the shortfall
      }
    }
  }

  Future<T> _waitForNextInternal(Duration timeout) async {
    if (_isDisposed) {
      throw StateError('ShardTester has been disposed');
    }
    final completer = Completer<T>();
    final wait = _PendingWait<T>(completer);
    _waiters.add(wait);
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _waiters.remove(wait);
        throw ShardTimeoutError(
          'Timed out waiting for next state after ${timeout.inMilliseconds}ms',
        );
      },
    );
  }
```

- [ ] **Step 4: Run; pass**

Run: `flutter test test/testing/shard_tester_assertions_test.dart`
Expected: PASS — all 10 tests green.

- [ ] **Step 5: Run the previous test file again to verify no regression**

Run: `flutter test test/testing/shard_tester_capture_test.dart`
Expected: PASS — all 8 tests still green.

- [ ] **Step 6: Commit**

```bash
git add lib/src/testing/shard_tester.dart test/testing/shard_tester_assertions_test.dart
git commit -m "feat(testing): add expectStates and expectNoMoreStates to ShardTester"
```

---

### Task 8: Add `waitForNext` and `waitFor` to `ShardTester`

**Files:**
- Modify: `lib/src/testing/shard_tester.dart`
- Test: `test/testing/shard_tester_wait_test.dart`

- [ ] **Step 1: Create failing tests**

Create `test/testing/shard_tester_wait_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/src/testing/shard_tester.dart';

class _CounterShard extends Shard<int> {
  _CounterShard() : super(0);
  void inc() => emit(state + 1);
  void setTo(int v) => emit(v);
}

void main() {
  group('ShardTester — waitForNext', () {
    test('returns the next emission', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      Future.delayed(const Duration(milliseconds: 10), shard.inc);
      final state = await tester.waitForNext();
      expect(state, 1);
      await tester.dispose();
      shard.dispose();
    });

    test('throws ShardTimeoutError on timeout', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      await expectLater(
        tester.waitForNext(timeout: const Duration(milliseconds: 30)),
        throwsA(isA<ShardTimeoutError>()),
      );
      await tester.dispose();
      shard.dispose();
    });

    test('does not return historical states', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      shard.inc(); // historical emission, before waitForNext
      Future.delayed(const Duration(milliseconds: 10), shard.inc);
      final state = await tester.waitForNext();
      expect(state, 2); // not 1
      await tester.dispose();
      shard.dispose();
    });
  });

  group('ShardTester — waitFor', () {
    test('returns current shard state if it already matches', () async {
      final shard = _CounterShard();
      shard.setTo(5); // emit before the tester is even created
      final tester = ShardTester(shard);
      final state = await tester.waitFor((s) => s >= 5);
      expect(state, 5);
      await tester.dispose();
      shard.dispose();
    });

    test('waits for matching future emission', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      Future.delayed(const Duration(milliseconds: 10), () => shard.setTo(2));
      Future.delayed(const Duration(milliseconds: 20), () => shard.setTo(7));
      final state = await tester.waitFor((s) => s >= 7);
      expect(state, 7);
      await tester.dispose();
      shard.dispose();
    });

    test('throws ShardTimeoutError when no match within timeout', () async {
      final shard = _CounterShard();
      final tester = ShardTester(shard);
      Future.delayed(const Duration(milliseconds: 10), shard.inc);
      await expectLater(
        tester.waitFor(
          (s) => s > 100,
          timeout: const Duration(milliseconds: 30),
        ),
        throwsA(isA<ShardTimeoutError>()),
      );
      await tester.dispose();
      shard.dispose();
    });
  });
}
```

- [ ] **Step 2: Run; fail with missing methods**

Run: `flutter test test/testing/shard_tester_wait_test.dart`
Expected: FAIL — `waitForNext` / `waitFor` not defined.

- [ ] **Step 3: Add `waitForNext` and `waitFor` to `ShardTester`**

In `lib/src/testing/shard_tester.dart`, add these methods inside the `ShardTester<T>` class, after `expectNoMoreStates`:

```dart
  /// Waits for the next emission and returns it.
  ///
  /// Does NOT return the current `shard.state` or any historical recorded
  /// state — only the next emission after this call. Throws
  /// [ShardTimeoutError] if no emission arrives within [timeout].
  Future<T> waitForNext({
    Duration timeout = const Duration(seconds: 1),
  }) {
    return _waitForNextInternal(timeout);
  }

  /// Waits for a state that satisfies [predicate] and returns it.
  ///
  /// Checks the current `shard.state` synchronously; if it already satisfies
  /// the predicate, returns it immediately. Otherwise subscribes and returns
  /// the first future emission for which `predicate(state)` is true. Throws
  /// [ShardTimeoutError] if no satisfying state arrives within [timeout].
  Future<T> waitFor(
    bool Function(T state) predicate, {
    Duration timeout = const Duration(seconds: 1),
  }) async {
    if (_isDisposed) {
      throw StateError('ShardTester has been disposed');
    }
    if (predicate(_shard.state)) {
      return _shard.state;
    }
    final completer = Completer<T>();
    final wait = _PendingWait<T>(completer, predicate: predicate);
    _waiters.add(wait);
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _waiters.remove(wait);
        throw ShardTimeoutError(
          'Timed out waiting for matching state after '
          '${timeout.inMilliseconds}ms',
        );
      },
    );
  }
```

- [ ] **Step 4: Run; pass**

Run: `flutter test test/testing/shard_tester_wait_test.dart`
Expected: PASS — all 6 tests green.

- [ ] **Step 5: Re-run all ShardTester tests to verify no regression**

Run: `flutter test test/testing/shard_tester_capture_test.dart test/testing/shard_tester_assertions_test.dart test/testing/shard_tester_wait_test.dart`
Expected: PASS — all 24 tests green.

- [ ] **Step 6: Commit**

```bash
git add lib/src/testing/shard_tester.dart test/testing/shard_tester_wait_test.dart
git commit -m "feat(testing): add waitForNext and waitFor to ShardTester"
```

---

### Task 9: Add `shardTest()` declarative helper

**Files:**
- Modify: `lib/src/testing/shard_tester.dart`
- Test: `test/testing/shard_test_helper_test.dart`

- [ ] **Step 1: Create failing tests**

Create `test/testing/shard_test_helper_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/src/testing/shard_tester.dart';

class _CounterShard extends Shard<int> {
  _CounterShard() : super(0);
  void inc() => emit(state + 1);
  void incTwice() {
    emit(state + 1);
    emit(state + 1);
  }
}

void main() {
  group('shardTest helper', () {
    test('build → expect with no act', () async {
      await shardTest<_CounterShard, int>(
        build: () => _CounterShard(),
        expect: [],
      );
    });

    test('build → act → expect single emit', () async {
      await shardTest<_CounterShard, int>(
        build: () => _CounterShard(),
        act: (s) async => s.inc(),
        expect: [1],
      );
    });

    test('build → act → expect multiple emits', () async {
      await shardTest<_CounterShard, int>(
        build: () => _CounterShard(),
        act: (s) async => s.incTwice(),
        expect: [1, 2],
      );
    });

    test('mismatch surfaces as ShardAssertionError', () async {
      await expectLater(
        shardTest<_CounterShard, int>(
          build: () => _CounterShard(),
          act: (s) async => s.inc(),
          expect: [99],
        ),
        throwsA(isA<ShardAssertionError>()),
      );
    });
  });
}
```

- [ ] **Step 2: Run; fail**

Run: `flutter test test/testing/shard_test_helper_test.dart`
Expected: FAIL — `shardTest` not defined.

- [ ] **Step 3: Add `shardTest` top-level function**

At the bottom of `lib/src/testing/shard_tester.dart` (outside the `ShardTester` class), add:

```dart
/// A thin declarative wrapper around [ShardTester].
///
/// Builds [S], optionally invokes [act] on it, asserts the recorded emissions
/// match [expect] (prefix-match, like [ShardTester.expectStates]), then
/// disposes both the tester and the shard.
///
/// This is a function, not a test registrar; wrap it in your framework's
/// `test()` call:
///
/// ```dart
/// test('increments by 1', () async {
///   await shardTest<CounterShard, int>(
///     build: () => CounterShard(),
///     act: (s) async => s.increment(),
///     expect: [1],
///   );
/// });
/// ```
Future<void> shardTest<S extends Shard<T>, T>({
  required S Function() build,
  required List<T> expect,
  Future<void> Function(S shard)? act,
  Duration timeout = const Duration(seconds: 1),
}) async {
  final shard = build();
  final tester = ShardTester<T>(shard);
  try {
    if (act != null) {
      await act(shard);
    }
    await tester.expectStates(expect, timeout: timeout);
  } finally {
    await tester.dispose();
    shard.dispose();
  }
}
```

- [ ] **Step 4: Run; pass**

Run: `flutter test test/testing/shard_test_helper_test.dart`
Expected: PASS — all 4 tests green.

- [ ] **Step 5: Commit**

```bash
git add lib/src/testing/shard_tester.dart test/testing/shard_test_helper_test.dart
git commit -m "feat(testing): add declarative shardTest helper"
```

---

### Task 10: Wire up `lib/shard_test.dart` entry point

**Files:**
- Create: `lib/src/testing/testing.dart`
- Create: `lib/shard_test.dart`
- Test: `test/testing/public_entry_point_test.dart`

- [ ] **Step 1: Create the bundle export**

Create `lib/src/testing/testing.dart`:

```dart
/// Internal bundle export of all testing utilities. Re-exported through
/// `package:shard/shard_test.dart`.
library shard.testing;

export 'shard_tester.dart';
export 'fake_state_storage.dart';
export 'fake_cache_service.dart';
export 'mock_shard_observer.dart';
```

- [ ] **Step 2: Create the public entry point**

Create `lib/shard_test.dart`:

```dart
/// Public testing utilities for the shard package.
///
/// Import from your test code:
///
/// ```dart
/// import 'package:shard/shard_test.dart';
/// ```
///
/// This entry point is intentionally separate from `package:shard/shard.dart`
/// so production builds do not link the test utilities. Nothing in
/// `lib/shard.dart`'s import graph imports this file.
library shard.test;

export 'src/testing/testing.dart';
```

- [ ] **Step 3: Create a smoke test that imports the public entry point**

Create `test/testing/public_entry_point_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/shard_test.dart';

class _CounterShard extends Shard<int> {
  _CounterShard() : super(0);
  void inc() => emit(state + 1);
}

void main() {
  test('public entry point exposes all utilities', () async {
    final shard = _CounterShard();
    final tester = ShardTester(shard);
    final storage = FakeStateStorage();
    final cache = FakeCacheService();

    await MockShardObserver.scope((observer) async {
      shard.inc();
      await tester.expectStates([1]);
      await storage.save('k', 'v');
      cache.seed('k', 1);
      expect(observer.recordedChanges, hasLength(1));
    });

    await tester.dispose();
    shard.dispose();
  });

  test('shardTest helper is exported', () async {
    await shardTest<_CounterShard, int>(
      build: () => _CounterShard(),
      act: (s) async => s.inc(),
      expect: [1],
    );
  });
}
```

- [ ] **Step 4: Run all testing-utility tests**

Run: `flutter test test/testing/`
Expected: PASS — all tests including the new smoke test (~50 tests across files).

- [ ] **Step 5: Verify production import graph is clean**

Run: `dart analyze lib/`
Expected: `No issues found!`

Run: `grep -r "shard_test" lib/`
Expected: ONLY one line — `lib/shard_test.dart` itself; no reference from any other lib file.

- [ ] **Step 6: Commit**

```bash
git add lib/shard_test.dart lib/src/testing/testing.dart test/testing/public_entry_point_test.dart
git commit -m "feat(testing): add lib/shard_test.dart public entry point"
```

---

## Phase 3 — Package-internal tests

This phase has no production-code changes (with one possible exception noted below). Each task adds a test file that exercises the existing implementation, using utilities from Phase 2. Tasks are ordered roughly bottom-up (no inter-task dependencies beyond the utilities already in place).

### Task 11: Tests for `AsyncValue`

**Files:**
- Test: `test/state_management/async_value_test.dart`

- [ ] **Step 1: Create the test file**

Create `test/state_management/async_value_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

void main() {
  group('AsyncLoading', () {
    test('default equals default', () {
      expect(AsyncLoading<int>(), AsyncLoading<int>());
    });

    test('with same previousData are equal', () {
      expect(
        AsyncLoading<int>(previousData: 42),
        AsyncLoading<int>(previousData: 42),
      );
    });

    test('with different previousData are not equal', () {
      expect(
        AsyncLoading<int>(previousData: 1) == AsyncLoading<int>(previousData: 2),
        isFalse,
      );
    });

    test('isLoading is true, others false', () {
      const v = AsyncLoading<int>();
      expect(v.isLoading, isTrue);
      expect(v.hasData, isFalse);
      expect(v.hasError, isFalse);
    });

    test('dataOrNull is previousData', () {
      expect(AsyncLoading<int>().dataOrNull, isNull);
      expect(AsyncLoading<int>(previousData: 9).dataOrNull, 9);
    });

    test('errorOrNull and stackTraceOrNull are null', () {
      const v = AsyncLoading<int>(previousData: 9);
      expect(v.errorOrNull, isNull);
      expect(v.stackTraceOrNull, isNull);
    });
  });

  group('AsyncData', () {
    test('with same data are equal', () {
      expect(AsyncData<int>(42), AsyncData<int>(42));
    });

    test('with different data are not equal', () {
      expect(AsyncData<int>(1) == AsyncData<int>(2), isFalse);
    });

    test('hasData is true, others false', () {
      const v = AsyncData<int>(7);
      expect(v.hasData, isTrue);
      expect(v.isLoading, isFalse);
      expect(v.hasError, isFalse);
    });

    test('dataOrNull is the data', () {
      expect(AsyncData<int>(7).dataOrNull, 7);
    });
  });

  group('AsyncError', () {
    test('with same error and previousData are equal', () {
      final err = Exception('boom');
      expect(
        AsyncError<int>(err, null, 5),
        AsyncError<int>(err, null, 5),
      );
    });

    test('with different errors are not equal', () {
      expect(
        AsyncError<int>(Exception('a'), null, 1) ==
            AsyncError<int>(Exception('b'), null, 1),
        isFalse,
      );
    });

    test('hasError is true, others false', () {
      final v = AsyncError<int>(Exception('x'));
      expect(v.hasError, isTrue);
      expect(v.isLoading, isFalse);
      expect(v.hasData, isFalse);
    });

    test('dataOrNull is previousData', () {
      expect(AsyncError<int>(Exception('x'), null, 9).dataOrNull, 9);
      expect(AsyncError<int>(Exception('x')).dataOrNull, isNull);
    });

    test('errorOrNull is the error', () {
      final err = Exception('boom');
      expect(AsyncError<int>(err).errorOrNull, same(err));
    });

    test('stackTraceOrNull is the stack trace', () {
      final st = StackTrace.current;
      expect(AsyncError<int>(Exception('x'), st).stackTraceOrNull, same(st));
    });
  });
}
```

- [ ] **Step 2: Run; pass (we are testing existing code)**

Run: `flutter test test/state_management/async_value_test.dart`
Expected: PASS — all 16 tests green.

- [ ] **Step 3: Commit**

```bash
git add test/state_management/async_value_test.dart
git commit -m "test: add unit tests for AsyncValue sealed class"
```

---

### Task 12: Tests for the base `Shard<T>` class

**Files:**
- Test: `test/state_management/shard_test.dart`

- [ ] **Step 1: Create the test file**

Create `test/state_management/shard_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/shard_test.dart';

class _CounterShard extends Shard<int> {
  _CounterShard([int initial = 0]) : super(initial);
  void inc() => emit(state + 1);
  void setTo(int v) => emit(v);
  void force(int v) => emitForce(v);
  void boom() => addError(Exception('boom'), StackTrace.current);
}

void main() {
  setUp(() {
    Shard.observer = null;
  });

  group('Shard base behavior', () {
    test('initial state is set from constructor', () {
      final s = _CounterShard(7);
      expect(s.state, 7);
      s.dispose();
    });

    test('emit triggers notifyListeners', () {
      final s = _CounterShard();
      var notifications = 0;
      s.addListener(() => notifications++);
      s.inc();
      s.inc();
      expect(notifications, 2);
      s.dispose();
    });

    test('emit skips no-op when state equals current', () async {
      final s = _CounterShard(5);
      await shardTest<_CounterShard, int>(
        build: () => _CounterShard(5),
        act: (shard) async => shard.setTo(5),
        expect: [],
      );
      s.dispose();
    });

    test('emitForce bypasses equality and notifies', () async {
      await shardTest<_CounterShard, int>(
        build: () => _CounterShard(5),
        act: (shard) async => shard.force(5),
        expect: [5],
      );
    });

    test('dispose flips isDisposed', () {
      final s = _CounterShard();
      expect(s.isDisposed, isFalse);
      s.dispose();
      expect(s.isDisposed, isTrue);
    });

    test('post-dispose emit is a no-op', () async {
      final s = _CounterShard();
      final tester = ShardTester(s);
      s.dispose();
      // Calling inc() will hit ChangeNotifier's disposed check; wrap in
      // try to ignore the assertion error and verify no state recorded.
      try {
        s.inc();
      } catch (_) {}
      expect(tester.recordedStates, isEmpty);
      await tester.dispose();
    });

    test('addError calls onError', () async {
      await MockShardObserver.scope((observer) async {
        final s = _CounterShard();
        addTearDown(s.dispose);
        s.boom();
        expect(observer.errorsFor(s), hasLength(1));
        expect(observer.errorsFor(s).first.error, isA<Exception>());
      });
    });

    test('observer receives onChange events', () async {
      await MockShardObserver.scope((observer) async {
        final s = _CounterShard();
        addTearDown(s.dispose);
        s.inc();
        s.inc();
        expect(observer.changesFor(s), hasLength(2));
        expect(observer.changesFor(s).first.previousState, 0);
        expect(observer.changesFor(s).first.currentState, 1);
      });
    });
  });
}
```

- [ ] **Step 2: Run; pass**

Run: `flutter test test/state_management/shard_test.dart`
Expected: PASS — all 8 tests green.

- [ ] **Step 3: Commit**

```bash
git add test/state_management/shard_test.dart
git commit -m "test: add unit tests for Shard base class"
```

---

### Task 13: Tests for `DebounceMixin` and `ThrottleMixin`

**Files:**
- Test: `test/state_management/debounce_throttle_test.dart`

- [ ] **Step 1: Create the test file**

Create `test/state_management/debounce_throttle_test.dart`:

```dart
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

class _DebounceShard extends Shard<int> {
  _DebounceShard() : super(0);

  int callCount = 0;
  void run(String key, {Duration duration = const Duration(milliseconds: 100)}) {
    debounce(key, () => callCount++, duration: duration);
  }

  void cancel(String key) => cancelDebounce(key);
  void cancelAll() => cancelAllDebounce();
}

class _ThrottleShard extends Shard<int> {
  _ThrottleShard() : super(0);

  int callCount = 0;
  bool run(String key, {Duration duration = const Duration(milliseconds: 100)}) {
    return throttle(key, () => callCount++, duration: duration);
  }

  void cancel(String key) => cancelThrottle(key);
  void cancelAll() => cancelAllThrottle();
}

void main() {
  group('DebounceMixin', () {
    test('delays callback until duration elapses', () {
      fakeAsync((async) {
        final s = _DebounceShard();
        s.run('k');
        async.elapse(const Duration(milliseconds: 50));
        expect(s.callCount, 0);
        async.elapse(const Duration(milliseconds: 60));
        expect(s.callCount, 1);
        s.dispose();
      });
    });

    test('consecutive calls reset the timer', () {
      fakeAsync((async) {
        final s = _DebounceShard();
        s.run('k');
        async.elapse(const Duration(milliseconds: 80));
        s.run('k');
        async.elapse(const Duration(milliseconds: 80));
        expect(s.callCount, 0);
        async.elapse(const Duration(milliseconds: 30));
        expect(s.callCount, 1);
        s.dispose();
      });
    });

    test('different keys are independent', () {
      fakeAsync((async) {
        final s = _DebounceShard();
        s.run('a');
        s.run('b');
        async.elapse(const Duration(milliseconds: 110));
        expect(s.callCount, 2);
        s.dispose();
      });
    });

    test('cancelDebounce cancels a specific key', () {
      fakeAsync((async) {
        final s = _DebounceShard();
        s.run('a');
        s.run('b');
        s.cancel('a');
        async.elapse(const Duration(milliseconds: 110));
        expect(s.callCount, 1);
        s.dispose();
      });
    });

    test('dispose cancels all pending debounces', () {
      fakeAsync((async) {
        final s = _DebounceShard();
        s.run('a');
        s.run('b');
        s.dispose();
        async.elapse(const Duration(milliseconds: 200));
        expect(s.callCount, 0);
      });
    });
  });

  group('ThrottleMixin', () {
    test('first call executes immediately', () {
      fakeAsync((async) {
        final s = _ThrottleShard();
        final executed = s.run('k');
        expect(executed, isTrue);
        expect(s.callCount, 1);
        s.dispose();
      });
    });

    test('subsequent calls within window are ignored', () {
      fakeAsync((async) {
        final s = _ThrottleShard();
        s.run('k');
        final second = s.run('k');
        expect(second, isFalse);
        expect(s.callCount, 1);
        s.dispose();
      });
    });

    test('calls after window execute again', () {
      fakeAsync((async) {
        final s = _ThrottleShard();
        s.run('k');
        async.elapse(const Duration(milliseconds: 150));
        s.run('k');
        expect(s.callCount, 2);
        s.dispose();
      });
    });

    test('different keys are independent', () {
      fakeAsync((async) {
        final s = _ThrottleShard();
        s.run('a');
        s.run('b');
        expect(s.callCount, 2);
        s.dispose();
      });
    });

    test('cancelThrottle resets the window', () {
      fakeAsync((async) {
        final s = _ThrottleShard();
        s.run('k');
        s.cancel('k');
        s.run('k');
        expect(s.callCount, 2);
        s.dispose();
      });
    });
  });
}
```

- [ ] **Step 2: Run; pass**

Run: `flutter test test/state_management/debounce_throttle_test.dart`
Expected: PASS — all 10 tests green.

- [ ] **Step 3: Commit**

```bash
git add test/state_management/debounce_throttle_test.dart
git commit -m "test: add unit tests for DebounceMixin and ThrottleMixin"
```

---

### Task 14: Tests for `ShardObserver`

**Files:**
- Test: `test/state_management/shard_observer_test.dart`

- [ ] **Step 1: Create the test file**

Create `test/state_management/shard_observer_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/shard_test.dart';

class _CounterShard extends Shard<int> {
  _CounterShard() : super(0);
  void inc() => emit(state + 1);
  void boom() => addError(Exception('x'), StackTrace.current);
}

void main() {
  setUp(() {
    Shard.observer = null;
  });

  test('default observer is null; no exceptions on change/error', () {
    final s = _CounterShard();
    s.inc();
    s.boom();
    s.dispose();
  });

  test('onChange fires on emit', () async {
    await MockShardObserver.scope((observer) async {
      final s = _CounterShard();
      addTearDown(s.dispose);
      s.inc();
      expect(observer.recordedChanges, hasLength(1));
    });
  });

  test('onError fires on addError', () async {
    await MockShardObserver.scope((observer) async {
      final s = _CounterShard();
      addTearDown(s.dispose);
      s.boom();
      expect(observer.recordedErrors, hasLength(1));
    });
  });

  test('multiple shards share the same observer', () async {
    await MockShardObserver.scope((observer) async {
      final a = _CounterShard();
      final b = _CounterShard();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      a.inc();
      b.inc();
      expect(observer.changesOfType<int>(), hasLength(2));
    });
  });

  test('swapping observers takes effect immediately', () {
    final firstChanges = <int>[];
    final secondChanges = <int>[];
    Shard.observer = _RecordingObserver(firstChanges);

    final s = _CounterShard();
    addTearDown(s.dispose);
    s.inc(); // recorded to first
    Shard.observer = _RecordingObserver(secondChanges);
    s.inc(); // recorded to second

    expect(firstChanges, [1]);
    expect(secondChanges, [2]);
  });
}

class _RecordingObserver extends ShardObserver {
  _RecordingObserver(this.target);
  final List<int> target;

  @override
  void onChange<T>(Shard<T> shard, T previousState, T currentState) {
    if (currentState is int) target.add(currentState);
  }
}
```

- [ ] **Step 2: Run; pass**

Run: `flutter test test/state_management/shard_observer_test.dart`
Expected: PASS — all 5 tests green.

- [ ] **Step 3: Commit**

```bash
git add test/state_management/shard_observer_test.dart
git commit -m "test: add unit tests for ShardObserver"
```

---

### Task 15: Tests for `FutureShard`

**Files:**
- Test: `test/state_management/future_shard_test.dart`

- [ ] **Step 1: Create the test file**

Create `test/state_management/future_shard_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/shard_test.dart';

class _OkShard extends FutureShard<int> {
  _OkShard({required this.fake, this.value = 42, this.cacheKeyOverride});

  final FakeCacheService fake;
  final int value;
  final String? cacheKeyOverride;
  int buildCount = 0;

  @override
  CacheService get cacheService => fake;

  @override
  String get cacheKey => cacheKeyOverride ?? super.cacheKey;

  @override
  Future<int> build() async {
    buildCount++;
    return value;
  }
}

class _NoCacheShard extends _OkShard {
  _NoCacheShard({required super.fake}) : super(value: 7);

  @override
  bool get allowCache => false;
}

class _ErrShard extends FutureShard<int> {
  _ErrShard({required this.fake});
  final FakeCacheService fake;

  @override
  CacheService get cacheService => fake;

  @override
  Future<int> build() async {
    throw StateError('build failed');
  }
}

void main() {
  setUp(() {
    Shard.observer = null;
  });

  test('onInit emits Loading then Data', () async {
    final shard = _OkShard(fake: FakeCacheService());
    final tester = ShardTester(shard);
    addTearDown(tester.dispose);
    addTearDown(shard.dispose);

    shard.onInit();

    await tester.expectStates([
      AsyncData<int>(42),
    ], timeout: const Duration(seconds: 1));
    expect(shard.buildCount, 1);
  });

  test('build error emits AsyncError', () async {
    final shard = _ErrShard(fake: FakeCacheService());
    final tester = ShardTester(shard);
    addTearDown(tester.dispose);
    addTearDown(shard.dispose);

    shard.onInit();

    await tester.waitFor((s) => s is AsyncError<int>);
    expect(tester.lastState, isA<AsyncError<int>>());
  });

  test('cached value short-circuits build', () async {
    final cache = FakeCacheService()..seed('_OkShard', 99);
    final shard = _OkShard(fake: cache);
    final tester = ShardTester(shard);
    addTearDown(tester.dispose);
    addTearDown(shard.dispose);

    shard.onInit();

    await tester.expectStates([AsyncData<int>(99)]);
    expect(shard.buildCount, 0);
  });

  test('expired cache forces refetch', () async {
    final cache = FakeCacheService()..seedExpired('_OkShard', 99);
    final shard = _OkShard(fake: cache);
    final tester = ShardTester(shard);
    addTearDown(tester.dispose);
    addTearDown(shard.dispose);

    shard.onInit();

    await tester.expectStates([AsyncData<int>(42)]);
    expect(shard.buildCount, 1);
  });

  test('allowCache: false bypasses cache layer', () async {
    final cache = FakeCacheService()..seed('_NoCacheShard', 99);
    final shard = _NoCacheShard(fake: cache);
    final tester = ShardTester(shard);
    addTearDown(tester.dispose);
    addTearDown(shard.dispose);

    shard.onInit();

    await tester.expectStates([AsyncData<int>(7)]);
    expect(shard.buildCount, 1);
    expect(cache.writeCount, 0);
  });

  test('refresh invalidates cache and re-runs build', () async {
    final cache = FakeCacheService();
    final shard = _OkShard(fake: cache);
    final tester = ShardTester(shard);
    addTearDown(tester.dispose);
    addTearDown(shard.dispose);

    shard.onInit();
    await tester.waitFor((s) => s is AsyncData<int>);
    expect(shard.buildCount, 1);

    tester.clear();
    shard.refresh();
    await tester.waitFor((s) => s is AsyncData<int>);
    expect(shard.buildCount, 2);
    expect(cache.deleteCount, 1);
  });

  test('cacheKey override is used', () async {
    final cache = FakeCacheService()..seed('custom_key', 123);
    final shard = _OkShard(fake: cache, cacheKeyOverride: 'custom_key');
    final tester = ShardTester(shard);
    addTearDown(tester.dispose);
    addTearDown(shard.dispose);

    shard.onInit();
    await tester.expectStates([AsyncData<int>(123)]);
    expect(shard.buildCount, 0);
  });
}
```

- [ ] **Step 2: Run; pass**

Run: `flutter test test/state_management/future_shard_test.dart`
Expected: PASS — all 7 tests green.

- [ ] **Step 3: Commit**

```bash
git add test/state_management/future_shard_test.dart
git commit -m "test: add unit tests for FutureShard including cache integration"
```

---

### Task 16: Tests for `StreamShard`

**Files:**
- Test: `test/state_management/stream_shard_test.dart`

- [ ] **Step 1: Create the test file**

Create `test/state_management/stream_shard_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/shard_test.dart';

class _TickerShard extends StreamShard<int> {
  _TickerShard({required this.controller});
  final StreamController<int> controller;

  @override
  Stream<int> build() => controller.stream;
}

void main() {
  test('subscribes on onInit and emits Loading initially', () async {
    final ctrl = StreamController<int>();
    final shard = _TickerShard(controller: ctrl);
    addTearDown(shard.dispose);
    addTearDown(ctrl.close);

    shard.onInit();
    expect(shard.state, isA<AsyncLoading<int>>());
  });

  test('emits AsyncData for each stream value', () async {
    final ctrl = StreamController<int>();
    final shard = _TickerShard(controller: ctrl);
    final tester = ShardTester(shard);
    addTearDown(tester.dispose);
    addTearDown(shard.dispose);
    addTearDown(ctrl.close);

    shard.onInit();
    ctrl.add(1);
    ctrl.add(2);

    await tester.expectStates([
      AsyncData<int>(1),
      AsyncData<int>(2),
    ]);
  });

  test('emits AsyncError when stream errors', () async {
    final ctrl = StreamController<int>();
    final shard = _TickerShard(controller: ctrl);
    final tester = ShardTester(shard);
    addTearDown(tester.dispose);
    addTearDown(shard.dispose);
    addTearDown(ctrl.close);

    shard.onInit();
    ctrl.addError(StateError('boom'));

    await tester.waitFor((s) => s is AsyncError<int>);
    expect(tester.lastState, isA<AsyncError<int>>());
  });

  test('refresh cancels and re-subscribes', () async {
    final ctrl1 = StreamController<int>.broadcast();
    final shard = _TickerShard(controller: ctrl1);
    final tester = ShardTester(shard);
    addTearDown(tester.dispose);
    addTearDown(shard.dispose);
    addTearDown(ctrl1.close);

    shard.onInit();
    ctrl1.add(1);
    await tester.waitFor((s) => s is AsyncData<int>);

    tester.clear();
    shard.refresh();
    ctrl1.add(2);
    await tester.waitFor((s) => s is AsyncData<int> && (s).data == 2);
    expect((tester.lastState as AsyncData<int>).data, 2);
  });

  test('dispose cancels subscription', () async {
    final ctrl = StreamController<int>();
    final shard = _TickerShard(controller: ctrl);
    final tester = ShardTester(shard);
    addTearDown(tester.dispose);
    addTearDown(ctrl.close);

    shard.onInit();
    shard.dispose();

    ctrl.add(1);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(tester.recordedStates, isEmpty);
  });
}
```

- [ ] **Step 2: Run; pass**

Run: `flutter test test/state_management/stream_shard_test.dart`
Expected: PASS — all 5 tests green.

- [ ] **Step 3: Commit**

```bash
git add test/state_management/stream_shard_test.dart
git commit -m "test: add unit tests for StreamShard"
```

---

### Task 17: Tests for `CacheEntry`

**Files:**
- Test: `test/caching/cache_entry_test.dart`

- [ ] **Step 1: Create the test file**

Create `test/caching/cache_entry_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

void main() {
  group('CacheEntry', () {
    test('isExpired is true when expiryDate is in the past', () {
      final entry = CacheEntry(
        data: 1,
        expiryDate: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      expect(entry.isExpired, isTrue);
    });

    test('isExpired is false when expiryDate is in the future', () {
      final entry = CacheEntry(
        data: 1,
        expiryDate: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(entry.isExpired, isFalse);
    });

    test('stores data unchanged', () {
      final entry = CacheEntry(
        data: {'k': 'v'},
        expiryDate: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(entry.data, {'k': 'v'});
    });
  });
}
```

- [ ] **Step 2: Run; pass**

Run: `flutter test test/caching/cache_entry_test.dart`
Expected: PASS — 3 tests green.

- [ ] **Step 3: Commit**

```bash
git add test/caching/cache_entry_test.dart
git commit -m "test: add unit tests for CacheEntry"
```

---

### Task 18: Tests for `MemoryCacheService`

**Files:**
- Test: `test/caching/memory_cache_service_test.dart`

- [ ] **Step 1: Create the test file**

Create `test/caching/memory_cache_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

void main() {
  setUp(() async {
    // Singleton — clear before each test.
    await MemoryCacheService().clearAll();
  });

  group('MemoryCacheService', () {
    test('write and read roundtrip', () async {
      final cache = MemoryCacheService();
      final entry = CacheEntry(
        data: 'hi',
        expiryDate: DateTime.now().add(const Duration(hours: 1)),
      );
      await cache.write('k', entry);
      final read = await cache.read('k');
      expect(read?.data, 'hi');
    });

    test('read returns null for missing key', () async {
      final cache = MemoryCacheService();
      expect(await cache.read('missing'), isNull);
    });

    test('delete removes entry', () async {
      final cache = MemoryCacheService();
      await cache.write(
        'k',
        CacheEntry(data: 1, expiryDate: DateTime.now().add(const Duration(hours: 1))),
      );
      await cache.delete('k');
      expect(await cache.read('k'), isNull);
    });

    test('clearAll empties storage', () async {
      final cache = MemoryCacheService();
      await cache.write(
        'a',
        CacheEntry(data: 1, expiryDate: DateTime.now().add(const Duration(hours: 1))),
      );
      await cache.write(
        'b',
        CacheEntry(data: 2, expiryDate: DateTime.now().add(const Duration(hours: 1))),
      );
      await cache.clearAll();
      expect(await cache.read('a'), isNull);
      expect(await cache.read('b'), isNull);
    });

    test('is a singleton', () {
      expect(identical(MemoryCacheService(), MemoryCacheService()), isTrue);
    });

    test('expired entries are still readable, but isExpired is true', () async {
      final cache = MemoryCacheService();
      await cache.write(
        'k',
        CacheEntry(
          data: 1,
          expiryDate: DateTime.now().subtract(const Duration(seconds: 1)),
        ),
      );
      final read = await cache.read('k');
      expect(read, isNotNull);
      expect(read!.isExpired, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run; pass**

Run: `flutter test test/caching/memory_cache_service_test.dart`
Expected: PASS — 6 tests green.

- [ ] **Step 3: Commit**

```bash
git add test/caching/memory_cache_service_test.dart
git commit -m "test: add unit tests for MemoryCacheService"
```

---

### Task 19: Tests for `CacheMixin`

**Files:**
- Test: `test/caching/cache_mixin_test.dart`

- [ ] **Step 1: Create the test file**

Create `test/caching/cache_mixin_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/shard_test.dart';

class _Repo with CacheMixin {
  _Repo(this._cache);
  final CacheService _cache;

  @override
  CacheService get cacheService => _cache;

  int fetchCount = 0;
  bool shouldFail = false;

  Future<int> getValue(String id) {
    return resolve<int>(
      key: 'v_$id',
      fetcher: () async {
        fetchCount++;
        if (shouldFail) throw StateError('fetch failed');
        return id.length;
      },
      ttl: const Duration(minutes: 5),
    );
  }

  Future<int> getValueWithStaleFallback(String id) {
    return resolve<int>(
      key: 'v_$id',
      fetcher: () async {
        fetchCount++;
        if (shouldFail) throw StateError('fetch failed');
        return id.length;
      },
      onErrorReturnOldCache: true,
    );
  }
}

void main() {
  test('cache hit returns cached value without calling fetcher', () async {
    final cache = FakeCacheService()..seed('v_abc', 99);
    final repo = _Repo(cache);
    final v = await repo.getValue('abc');
    expect(v, 99);
    expect(repo.fetchCount, 0);
  });

  test('cache miss calls fetcher and writes', () async {
    final cache = FakeCacheService();
    final repo = _Repo(cache);
    final v = await repo.getValue('abc');
    expect(v, 3);
    expect(repo.fetchCount, 1);
    expect(cache.writeCount, 1);
  });

  test('expired cache triggers refetch', () async {
    final cache = FakeCacheService()..seedExpired('v_abc', 99);
    final repo = _Repo(cache);
    final v = await repo.getValue('abc');
    expect(v, 3); // fresh, not 99
    expect(repo.fetchCount, 1);
  });

  test('forceRefresh: true bypasses cache', () async {
    final cache = FakeCacheService()..seed('v_abc', 99);
    final repo = _Repo(cache);
    final v = await repo.resolve<int>(
      key: 'v_abc',
      fetcher: () async {
        repo.fetchCount++;
        return 77;
      },
      forceRefresh: true,
    );
    expect(v, 77);
    expect(repo.fetchCount, 1);
  });

  test('onErrorReturnOldCache returns stale on fetcher error', () async {
    final cache = FakeCacheService()..seedExpired('v_abc', 50);
    final repo = _Repo(cache)..shouldFail = true;
    final v = await repo.getValueWithStaleFallback('abc');
    expect(v, 50);
  });

  test('rethrows when no cached entry exists and fetcher fails', () async {
    final cache = FakeCacheService();
    final repo = _Repo(cache)..shouldFail = true;
    await expectLater(
      repo.getValueWithStaleFallback('abc'),
      throwsA(isA<StateError>()),
    );
  });
}
```

- [ ] **Step 2: Run; pass**

Run: `flutter test test/caching/cache_mixin_test.dart`
Expected: PASS — 6 tests green.

- [ ] **Step 3: Commit**

```bash
git add test/caching/cache_mixin_test.dart
git commit -m "test: add unit tests for CacheMixin"
```

---

### Task 20: Tests for `ShardLocator`

**Files:**
- Test: `test/locator/shard_locator_test.dart`

- [ ] **Step 1: Create the test file**

Create `test/locator/shard_locator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

class _ApiClient {}
class _Repo {
  _Repo(this.api);
  final _ApiClient api;
}

void main() {
  setUp(ShardLocator.reset);

  test('registerSingleton returns the same instance via get', () {
    final api = _ApiClient();
    ShardLocator.registerSingleton<_ApiClient>(api);
    expect(ShardLocator.get<_ApiClient>(), same(api));
  });

  test('registerLazySingleton invokes factory on first get and caches', () {
    var count = 0;
    ShardLocator.registerLazySingleton<_ApiClient>(() {
      count++;
      return _ApiClient();
    });
    final a = ShardLocator.get<_ApiClient>();
    final b = ShardLocator.get<_ApiClient>();
    expect(count, 1);
    expect(identical(a, b), isTrue);
  });

  test('lazy factory can use other registrations', () {
    ShardLocator.registerSingleton<_ApiClient>(_ApiClient());
    ShardLocator.registerLazySingleton<_Repo>(
      () => _Repo(ShardLocator.get<_ApiClient>()),
    );
    final repo = ShardLocator.get<_Repo>();
    expect(repo.api, same(ShardLocator.get<_ApiClient>()));
  });

  test('isRegistered reflects eager and lazy registrations', () {
    expect(ShardLocator.isRegistered<_ApiClient>(), isFalse);
    ShardLocator.registerSingleton<_ApiClient>(_ApiClient());
    expect(ShardLocator.isRegistered<_ApiClient>(), isTrue);
    ShardLocator.reset();
    ShardLocator.registerLazySingleton<_ApiClient>(_ApiClient.new);
    expect(ShardLocator.isRegistered<_ApiClient>(), isTrue);
  });

  test('reset clears all registrations', () {
    ShardLocator.registerSingleton<_ApiClient>(_ApiClient());
    ShardLocator.reset();
    expect(ShardLocator.isRegistered<_ApiClient>(), isFalse);
    expect(() => ShardLocator.get<_ApiClient>(), throwsStateError);
  });

  test('get throws StateError when nothing is registered', () {
    expect(() => ShardLocator.get<_ApiClient>(), throwsStateError);
  });

  test('eager registration replaces lazy', () {
    ShardLocator.registerLazySingleton<_ApiClient>(_ApiClient.new);
    final replacement = _ApiClient();
    ShardLocator.registerSingleton<_ApiClient>(replacement);
    expect(ShardLocator.get<_ApiClient>(), same(replacement));
  });

  test('lazy registration replaces eager', () {
    final original = _ApiClient();
    ShardLocator.registerSingleton<_ApiClient>(original);
    final replacement = _ApiClient();
    ShardLocator.registerLazySingleton<_ApiClient>(() => replacement);
    expect(ShardLocator.get<_ApiClient>(), same(replacement));
  });
}
```

- [ ] **Step 2: Run; pass**

Run: `flutter test test/locator/shard_locator_test.dart`
Expected: PASS — 8 tests green.

- [ ] **Step 3: Commit**

```bash
git add test/locator/shard_locator_test.dart
git commit -m "test: add unit tests for ShardLocator"
```

---

### Task 21: Tests for primitive serializers

**Files:**
- Test: `test/persistence/primitive_serializers_test.dart`

- [ ] **Step 1: Create the test file**

Create `test/persistence/primitive_serializers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

void main() {
  group('IntSerializer', () {
    const s = IntSerializer();

    test('roundtrips positive, zero, and negative', () {
      expect(s.deserialize(s.serialize(42)), 42);
      expect(s.deserialize(s.serialize(0)), 0);
      expect(s.deserialize(s.serialize(-7)), -7);
    });

    test('throws FormatException on malformed input', () {
      expect(() => s.deserialize('abc'), throwsFormatException);
    });
  });

  group('DoubleSerializer', () {
    const s = DoubleSerializer();

    test('roundtrips fractional and integral values', () {
      expect(s.deserialize(s.serialize(3.14)), closeTo(3.14, 1e-9));
      expect(s.deserialize(s.serialize(0.0)), 0.0);
      expect(s.deserialize(s.serialize(-1.5)), -1.5);
    });
  });

  group('BoolSerializer', () {
    const s = BoolSerializer();

    test('roundtrips true and false', () {
      expect(s.deserialize(s.serialize(true)), isTrue);
      expect(s.deserialize(s.serialize(false)), isFalse);
    });

    test('non-true strings deserialize to false', () {
      expect(s.deserialize('garbage'), isFalse);
    });
  });

  group('StringSerializer', () {
    const s = StringSerializer();

    test('preserves arbitrary strings including empty and unicode', () {
      expect(s.deserialize(s.serialize('')), '');
      expect(s.deserialize(s.serialize('hello, 世界 👋')), 'hello, 世界 👋');
      expect(s.deserialize(s.serialize('with\nnewlines')), 'with\nnewlines');
    });
  });
}
```

- [ ] **Step 2: Run; pass**

Run: `flutter test test/persistence/primitive_serializers_test.dart`
Expected: PASS — 6 tests green.

- [ ] **Step 3: Commit**

```bash
git add test/persistence/primitive_serializers_test.dart
git commit -m "test: add unit tests for primitive serializers"
```

---

### Task 22: Tests for `stateSerializer` factory

**Files:**
- Test: `test/persistence/state_serializer_test.dart`

- [ ] **Step 1: Create the test file**

Create `test/persistence/state_serializer_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

class _Todo {
  _Todo({required this.id, required this.title});
  factory _Todo.fromJson(Map<String, dynamic> json) =>
      _Todo(id: json['id'] as int, title: json['title'] as String);

  final int id;
  final String title;

  Map<String, dynamic> toJson() => {'id': id, 'title': title};

  @override
  bool operator ==(Object other) =>
      other is _Todo && other.id == id && other.title == title;

  @override
  int get hashCode => Object.hash(id, title);
}

void main() {
  test('roundtrips a single object', () {
    final s = stateSerializer<_Todo>(
      fromJson: (j) => _Todo.fromJson(j as Map<String, dynamic>),
      toJson: (t) => t.toJson(),
    );
    final todo = _Todo(id: 1, title: 'Buy milk');
    expect(s.deserialize(s.serialize(todo)), todo);
  });

  test('roundtrips a list of objects', () {
    final s = stateSerializer<List<_Todo>>(
      fromJson: (j) => (j as List)
          .map((e) => _Todo.fromJson(e as Map<String, dynamic>))
          .toList(),
      toJson: (xs) => xs.map((t) => t.toJson()).toList(),
    );
    final todos = [
      _Todo(id: 1, title: 'a'),
      _Todo(id: 2, title: 'b'),
    ];
    expect(s.deserialize(s.serialize(todos)), todos);
  });

  test('roundtrips nested structures', () {
    final s = stateSerializer<Map<String, _Todo>>(
      fromJson: (j) => (j as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, _Todo.fromJson(v as Map<String, dynamic>)),
      ),
      toJson: (m) => m.map((k, v) => MapEntry(k, v.toJson())),
    );
    final input = {'a': _Todo(id: 1, title: 'a')};
    expect(s.deserialize(s.serialize(input)), input);
  });

  test('malformed JSON throws on deserialize', () {
    final s = stateSerializer<_Todo>(
      fromJson: (j) => _Todo.fromJson(j as Map<String, dynamic>),
      toJson: (t) => t.toJson(),
    );
    expect(() => s.deserialize('not-json'), throwsFormatException);
  });
}
```

- [ ] **Step 2: Run; pass**

Run: `flutter test test/persistence/state_serializer_test.dart`
Expected: PASS — 4 tests green.

- [ ] **Step 3: Commit**

```bash
git add test/persistence/state_serializer_test.dart
git commit -m "test: add unit tests for stateSerializer factory"
```

---

### Task 23: Tests for `StatePersistenceMixin`

**Files:**
- Test: `test/persistence/state_persistence_test.dart`

- [ ] **Step 1: Create the test file**

Create `test/persistence/state_persistence_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/shard_test.dart';

class _MyShard extends Shard<int> with StatePersistenceMixin<int, int> {
  _MyShard() : super(0);
  void setTo(int v) => emit(v);
}

void main() {
  test('autoLoad calls onLoadComplete with stored value', () async {
    final storage = FakeStateStorage(initialData: {'k': '7'});
    final shard = _MyShard();
    int? loadedValue;
    shard.enablePersistence(
      key: 'k',
      storage: storage,
      serializer: const IntSerializer(),
      toPersistence: (s) => s,
      onLoadComplete: (data) => loadedValue = data,
    );

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(loadedValue, 7);
    shard.dispose();
  });

  test('autoLoad calls onLoadComplete with null on empty storage', () async {
    final storage = FakeStateStorage();
    final shard = _MyShard();
    bool called = false;
    int? loaded;
    shard.enablePersistence(
      key: 'k',
      storage: storage,
      serializer: const IntSerializer(),
      toPersistence: (s) => s,
      onLoadComplete: (data) {
        called = true;
        loaded = data;
      },
    );

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(called, isTrue);
    expect(loaded, isNull);
    shard.dispose();
  });

  test('emit triggers debounced save', () async {
    final storage = FakeStateStorage();
    final shard = _MyShard();
    shard.enablePersistence(
      key: 'k',
      storage: storage,
      serializer: const IntSerializer(),
      toPersistence: (s) => s,
      debounceDuration: const Duration(milliseconds: 50),
    );

    shard.setTo(1);
    shard.setTo(2);
    shard.setTo(3);

    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(storage.saveCount, 1);
    expect(storage.rawValue('k'), '3');
    shard.dispose();
  });

  test('onSaveError fires when storage save fails', () async {
    final storage = FakeStateStorage()..saveError = StateError('disk full');
    final shard = _MyShard();
    Object? capturedError;
    shard.enablePersistence(
      key: 'k',
      storage: storage,
      serializer: const IntSerializer(),
      toPersistence: (s) => s,
      autoLoad: false,
      debounceDuration: const Duration(milliseconds: 30),
      onSaveError: (e, st) => capturedError = e,
    );

    shard.setTo(1);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(capturedError, isA<StateError>());
    shard.dispose();
  });

  test('onLoadError fires when storage load fails', () async {
    final storage = FakeStateStorage()..loadError = StateError('disk read failed');
    final shard = _MyShard();
    Object? capturedError;
    shard.enablePersistence(
      key: 'k',
      storage: storage,
      serializer: const IntSerializer(),
      toPersistence: (s) => s,
      onLoadError: (e, st) => capturedError = e,
    );

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(capturedError, isA<StateError>());
    shard.dispose();
  });

  test('disablePersistence stops auto-save', () async {
    final storage = FakeStateStorage();
    final shard = _MyShard();
    shard.enablePersistence(
      key: 'k',
      storage: storage,
      serializer: const IntSerializer(),
      toPersistence: (s) => s,
      autoLoad: false,
      debounceDuration: const Duration(milliseconds: 30),
    );

    shard.disablePersistence();
    shard.setTo(1);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(storage.saveCount, 0);
    shard.dispose();
  });

  test('dispose flushes pending save', () async {
    final storage = FakeStateStorage();
    final shard = _MyShard();
    shard.enablePersistence(
      key: 'k',
      storage: storage,
      serializer: const IntSerializer(),
      toPersistence: (s) => s,
      autoLoad: false,
      debounceDuration: const Duration(seconds: 5), // long debounce
    );

    shard.setTo(42);
    shard.dispose();

    // Even though debounce was 5s, dispose should have triggered a save.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(storage.saveCount, 1);
    expect(storage.rawValue('k'), '42');
  });
}
```

- [ ] **Step 2: Run; pass**

Run: `flutter test test/persistence/state_persistence_test.dart`
Expected: PASS — 7 tests green.

- [ ] **Step 3: Commit**

```bash
git add test/persistence/state_persistence_test.dart
git commit -m "test: add unit tests for StatePersistenceMixin"
```

---

### Task 24: Tests for `PersistentShard` and `SimplePersistentShard`

**Files:**
- Test: `test/persistence/persistent_shard_test.dart`

- [ ] **Step 1: Create the test file**

Create `test/persistence/persistent_shard_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/shard_test.dart';

class _SimpleCounter extends SimplePersistentShard<int> {
  _SimpleCounter({required FakeStateStorage storage})
      : super(0, storage: storage, serializer: const IntSerializer());

  @override
  String get persistenceKey => 'counter';

  void inc() => emit(state + 1);
}

class _TodoState {
  _TodoState({required this.status, required this.todos});
  final String status;
  final List<String> todos;

  _TodoState copyWith({String? status, List<String>? todos}) =>
      _TodoState(status: status ?? this.status, todos: todos ?? this.todos);
}

class _TodoShard extends PersistentShard<_TodoState, List<String>> {
  _TodoShard({required FakeStateStorage storage})
      : super(
          _TodoState(status: 'loading', todos: const []),
          storage: storage,
          serializer: stateSerializer<List<String>>(
            fromJson: (j) => (j as List).cast<String>(),
            toJson: (xs) => xs,
          ),
        );

  @override
  String get persistenceKey => 'todos';

  @override
  List<String> toPersistence(_TodoState s) => s.todos;

  @override
  void onLoadComplete(List<String>? data) {
    emit(state.copyWith(status: 'loaded', todos: data ?? []));
  }

  void add(String t) => emit(state.copyWith(todos: [...state.todos, t]));
}

void main() {
  test('SimplePersistentShard restores prior value', () async {
    final storage = FakeStateStorage(initialData: {'counter': '5'});
    final s = _SimpleCounter(storage: storage);
    s.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(s.state, 5);
    s.dispose();
  });

  test('SimplePersistentShard persists value on emit', () async {
    final storage = FakeStateStorage();
    final s = _SimpleCounter(storage: storage);
    s.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    s.inc();
    s.inc();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(storage.rawValue('counter'), '2');
    s.dispose();
  });

  test('PersistentShard with T != K persists only the slice', () async {
    final storage = FakeStateStorage();
    final s = _TodoShard(storage: storage);
    s.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    s.add('a');
    s.add('b');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    // The persisted JSON is the list, not the full state.
    expect(storage.rawValue('todos'), '["a","b"]');
    s.dispose();
  });

  test('onLoadComplete merges loaded slice into full state', () async {
    final storage = FakeStateStorage(initialData: {'todos': '["x","y"]'});
    final s = _TodoShard(storage: storage);
    s.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(s.state.status, 'loaded');
    expect(s.state.todos, ['x', 'y']);
    s.dispose();
  });
}
```

- [ ] **Step 2: Run; pass**

Run: `flutter test test/persistence/persistent_shard_test.dart`
Expected: PASS — 4 tests green.

- [ ] **Step 3: Commit**

```bash
git add test/persistence/persistent_shard_test.dart
git commit -m "test: add unit tests for PersistentShard and SimplePersistentShard"
```

---

### Task 25: Tests for `ShardProvider`

**Files:**
- Test: `test/widgets/shard_provider_test.dart`

- [ ] **Step 1: Create the test file**

Create `test/widgets/shard_provider_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

class _LifecycleShard extends Shard<int> {
  _LifecycleShard() : super(0);
  int initCount = 0;
  int disposeCount = 0;

  @override
  void onInit() {
    super.onInit();
    initCount++;
  }

  @override
  void dispose() {
    disposeCount++;
    super.dispose();
  }
}

void main() {
  testWidgets('create constructor: onInit called, dispose called on removal',
      (tester) async {
    late _LifecycleShard captured;
    await tester.pumpWidget(
      MaterialApp(
        home: ShardProvider<_LifecycleShard>(
          create: () => _LifecycleShard(),
          child: Builder(builder: (context) {
            captured = ShardProvider.of<_LifecycleShard>(context, listen: false);
            return const SizedBox();
          }),
        ),
      ),
    );

    expect(captured.initCount, 1);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(captured.disposeCount, 1);
  });

  testWidgets('value constructor: dispose NOT called on removal',
      (tester) async {
    final external = _LifecycleShard();
    await tester.pumpWidget(
      MaterialApp(
        home: ShardProvider<_LifecycleShard>.value(
          value: external,
          child: const SizedBox(),
        ),
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(external.disposeCount, 0);
    expect(external.initCount, 0); // value constructor does NOT call onInit
    external.dispose();
  });

  testWidgets('of() throws when no provider above', (tester) async {
    Object? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(builder: (context) {
          try {
            ShardProvider.of<_LifecycleShard>(context);
          } catch (e) {
            captured = e;
          }
          return const SizedBox();
        }),
      ),
    );
    expect(captured, isA<AssertionError>());
  });
}
```

- [ ] **Step 2: Run; pass**

Run: `flutter test test/widgets/shard_provider_test.dart`
Expected: PASS — 3 tests green.

- [ ] **Step 3: Commit**

```bash
git add test/widgets/shard_provider_test.dart
git commit -m "test: add widget tests for ShardProvider lifecycle"
```

---

### Task 26: Tests for `ShardBuilder`

**Files:**
- Test: `test/widgets/shard_builder_test.dart`

- [ ] **Step 1: Create the test file**

Create `test/widgets/shard_builder_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

class _Counter extends Shard<int> {
  _Counter() : super(0);
  void inc() => emit(state + 1);
}

void main() {
  testWidgets('rebuilds on every state change', (tester) async {
    final shard = _Counter();
    addTearDown(shard.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ShardBuilder<_Counter, int>(
          shard: shard,
          builder: (context, count) => Text('$count', textDirection: TextDirection.ltr),
        ),
      ),
    );
    expect(find.text('0'), findsOneWidget);

    shard.inc();
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('buildWhen suppresses unwanted rebuilds', (tester) async {
    final shard = _Counter();
    addTearDown(shard.dispose);
    var builds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ShardBuilder<_Counter, int>(
          shard: shard,
          buildWhen: (prev, curr) => curr.isEven,
          builder: (context, count) {
            builds++;
            return Text('$count', textDirection: TextDirection.ltr);
          },
        ),
      ),
    );
    final initialBuilds = builds;

    shard.inc(); // 1 (odd) — should not rebuild
    await tester.pump();
    expect(builds, initialBuilds);

    shard.inc(); // 2 (even) — should rebuild
    await tester.pump();
    expect(builds, initialBuilds + 1);
  });

  testWidgets('listener fires on state change', (tester) async {
    final shard = _Counter();
    addTearDown(shard.dispose);
    final events = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ShardBuilder<_Counter, int>(
          shard: shard,
          listener: (prev, curr) => events.add(curr),
          builder: (_, __) => const SizedBox(),
        ),
      ),
    );

    shard.inc();
    await tester.pump();
    shard.inc();
    await tester.pump();
    expect(events, [1, 2]);
  });

  testWidgets('listenWhen filters listener calls', (tester) async {
    final shard = _Counter();
    addTearDown(shard.dispose);
    final events = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ShardBuilder<_Counter, int>(
          shard: shard,
          listenWhen: (prev, curr) => curr > 1,
          listener: (prev, curr) => events.add(curr),
          builder: (_, __) => const SizedBox(),
        ),
      ),
    );

    shard.inc(); // 1 — filtered
    await tester.pump();
    shard.inc(); // 2 — emitted
    await tester.pump();
    expect(events, [2]);
  });
}
```

- [ ] **Step 2: Run; pass**

Run: `flutter test test/widgets/shard_builder_test.dart`
Expected: PASS — 4 tests green.

- [ ] **Step 3: Commit**

```bash
git add test/widgets/shard_builder_test.dart
git commit -m "test: add widget tests for ShardBuilder"
```

---

### Task 27: Tests for `ShardSelector`

**Files:**
- Test: `test/widgets/shard_selector_test.dart`

- [ ] **Step 1: Create the test file**

Create `test/widgets/shard_selector_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

class _Person {
  _Person(this.name, this.age);
  String name;
  int age;
}

class _PersonShard extends Shard<_Person> {
  _PersonShard() : super(_Person('Alice', 30));
  void rename(String n) => emit(_Person(n, state.age));
  void age() => emit(_Person(state.name, state.age + 1));
}

void main() {
  testWidgets('rebuilds only when selected value changes', (tester) async {
    final shard = _PersonShard();
    addTearDown(shard.dispose);
    var builds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ShardSelector<_PersonShard, _Person, String>(
          shard: shard,
          selector: (p) => p.name,
          builder: (_, name) {
            builds++;
            return Text(name, textDirection: TextDirection.ltr);
          },
        ),
      ),
    );
    final initialBuilds = builds;
    expect(find.text('Alice'), findsOneWidget);

    shard.age(); // selected value (name) unchanged
    await tester.pump();
    expect(builds, initialBuilds);

    shard.rename('Bob');
    await tester.pump();
    expect(builds, initialBuilds + 1);
    expect(find.text('Bob'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run; pass**

Run: `flutter test test/widgets/shard_selector_test.dart`
Expected: PASS — 1 test green.

- [ ] **Step 3: Commit**

```bash
git add test/widgets/shard_selector_test.dart
git commit -m "test: add widget tests for ShardSelector"
```

---

### Task 28: Tests for `AsyncShardBuilder`

**Files:**
- Test: `test/widgets/async_shard_builder_test.dart`

- [ ] **Step 1: Create the test file**

Create `test/widgets/async_shard_builder_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

class _ManualAsyncShard extends Shard<AsyncValue<String>> {
  _ManualAsyncShard() : super(const AsyncLoading<String>());
  void setData(String d) => emit(AsyncData<String>(d));
  void setError(Object e) => emit(AsyncError<String>(e));
  void setLoading({String? previousData}) =>
      emit(AsyncLoading<String>(previousData: previousData));
}

void main() {
  testWidgets('shows onLoading widget initially', (tester) async {
    final shard = _ManualAsyncShard();
    addTearDown(shard.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AsyncShardBuilder<_ManualAsyncShard, String>(
          shard: shard,
          onLoading: (_) => const Text('LOADING', textDirection: TextDirection.ltr),
          onData: (_, d) => Text(d, textDirection: TextDirection.ltr),
        ),
      ),
    );
    expect(find.text('LOADING'), findsOneWidget);
  });

  testWidgets('shows onData widget after data', (tester) async {
    final shard = _ManualAsyncShard();
    addTearDown(shard.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AsyncShardBuilder<_ManualAsyncShard, String>(
          shard: shard,
          onData: (_, d) => Text(d, textDirection: TextDirection.ltr),
        ),
      ),
    );
    shard.setData('hello');
    await tester.pump();
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('shows onError widget after error', (tester) async {
    final shard = _ManualAsyncShard();
    addTearDown(shard.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AsyncShardBuilder<_ManualAsyncShard, String>(
          shard: shard,
          onData: (_, d) => Text(d, textDirection: TextDirection.ltr),
          onError: (_, e, st) => Text('ERR: $e', textDirection: TextDirection.ltr),
        ),
      ),
    );
    shard.setError(Exception('boom'));
    await tester.pump();
    expect(find.textContaining('ERR'), findsOneWidget);
  });

  testWidgets('showDataOnLoading: true shows previousData during reload',
      (tester) async {
    final shard = _ManualAsyncShard();
    addTearDown(shard.dispose);
    shard.setData('first');
    await tester.pumpWidget(
      MaterialApp(
        home: AsyncShardBuilder<_ManualAsyncShard, String>(
          shard: shard,
          onLoading: (_) => const Text('LOADING', textDirection: TextDirection.ltr),
          onData: (_, d) => Text(d, textDirection: TextDirection.ltr),
        ),
      ),
    );
    shard.setLoading(previousData: 'first');
    await tester.pump();
    expect(find.text('first'), findsOneWidget);
    expect(find.text('LOADING'), findsNothing);
  });

  testWidgets('default onLoading is CircularProgressIndicator', (tester) async {
    final shard = _ManualAsyncShard();
    addTearDown(shard.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AsyncShardBuilder<_ManualAsyncShard, String>(
          shard: shard,
          onData: (_, d) => Text(d, textDirection: TextDirection.ltr),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run; pass**

Run: `flutter test test/widgets/async_shard_builder_test.dart`
Expected: PASS — 5 tests green.

- [ ] **Step 3: Commit**

```bash
git add test/widgets/async_shard_builder_test.dart
git commit -m "test: add widget tests for AsyncShardBuilder"
```

---

### Task 29: Tests for `MultiShardProvider`

**Files:**
- Test: `test/widgets/multi_shard_provider_test.dart`

- [ ] **Step 1: Create the test file**

Create `test/widgets/multi_shard_provider_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

class _A extends Shard<int> {
  _A() : super(1);
}

class _B extends Shard<String> {
  _B() : super('hello');
}

void main() {
  testWidgets('provides multiple shards accessible from child', (tester) async {
    late _A a;
    late _B b;
    await tester.pumpWidget(
      MaterialApp(
        home: MultiShardProvider(
          providers: [
            ShardProvider<_A>(create: () => _A()),
            ShardProvider<_B>(create: () => _B()),
          ],
          child: Builder(builder: (context) {
            a = ShardProvider.of<_A>(context, listen: false);
            b = ShardProvider.of<_B>(context, listen: false);
            return const SizedBox();
          }),
        ),
      ),
    );
    expect(a.state, 1);
    expect(b.state, 'hello');
  });

  testWidgets('empty providers list returns child unchanged', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MultiShardProvider(
          providers: [],
          child: Text('OK', textDirection: TextDirection.ltr),
        ),
      ),
    );
    expect(find.text('OK'), findsOneWidget);
  });

  testWidgets('mixes create and value constructors', (tester) async {
    final external = _B();
    addTearDown(external.dispose);
    late _A a;
    late _B b;
    await tester.pumpWidget(
      MaterialApp(
        home: MultiShardProvider(
          providers: [
            ShardProvider<_A>(create: () => _A()),
            ShardProvider<_B>.value(value: external),
          ],
          child: Builder(builder: (context) {
            a = ShardProvider.of<_A>(context, listen: false);
            b = ShardProvider.of<_B>(context, listen: false);
            return const SizedBox();
          }),
        ),
      ),
    );
    expect(a.state, 1);
    expect(identical(b, external), isTrue);
  });
}
```

- [ ] **Step 2: Run; pass**

Run: `flutter test test/widgets/multi_shard_provider_test.dart`
Expected: PASS — 3 tests green.

- [ ] **Step 3: Commit**

```bash
git add test/widgets/multi_shard_provider_test.dart
git commit -m "test: add widget tests for MultiShardProvider"
```

---

### Task 30: Tests for `context.read`

**Files:**
- Test: `test/widgets/context_extensions_test.dart`

- [ ] **Step 1: Create the test file**

Create `test/widgets/context_extensions_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

class _Counter extends Shard<int> {
  _Counter() : super(0);
  void inc() => emit(state + 1);
}

void main() {
  testWidgets('context.read returns the provided shard', (tester) async {
    late _Counter captured;
    await tester.pumpWidget(
      MaterialApp(
        home: ShardProvider<_Counter>(
          create: () => _Counter(),
          child: Builder(builder: (context) {
            captured = context.read<_Counter>();
            return const SizedBox();
          }),
        ),
      ),
    );
    expect(captured.state, 0);
  });

  testWidgets('context.read does NOT cause rebuilds on emit', (tester) async {
    var builds = 0;
    late _Counter shard;

    await tester.pumpWidget(
      MaterialApp(
        home: ShardProvider<_Counter>(
          create: () => _Counter(),
          child: Builder(builder: (context) {
            builds++;
            shard = context.read<_Counter>();
            return const SizedBox();
          }),
        ),
      ),
    );
    final initial = builds;

    shard.inc();
    await tester.pump();
    expect(builds, initial); // no rebuild
  });
}
```

- [ ] **Step 2: Run; pass**

Run: `flutter test test/widgets/context_extensions_test.dart`
Expected: PASS — 2 tests green.

- [ ] **Step 3: Commit**

```bash
git add test/widgets/context_extensions_test.dart
git commit -m "test: add widget tests for context.read"
```

---

## Phase 4 — Documentation and verification

### Task 31: Update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add `LoggingObserver` to the "What's Included" table**

Open `README.md`. Find the "What's Included" table (around line 117). Replace the `Observability` row so it reads:

```markdown
| **Observability** | `ShardObserver`, `LoggingObserver` — global `onChange` / `onError` hooks; debug-build logger out of the box |
```

Add a new row to the same table immediately after `Observability`:

```markdown
| **Testing** | `package:shard/shard_test.dart` — `ShardTester`, `FakeStateStorage`, `FakeCacheService`, `MockShardObserver`, declarative `shardTest()` helper |
```

- [ ] **Step 2: Add a "Testing your shards" section**

In `README.md`, find the "ShardObserver (Global Logging)" section. After it (and before the "Requirements" section), insert:

````markdown
### LoggingObserver (Debug Out of the Box)

Drop-in debug logger; inert in release builds (uses `kDebugMode`):

```dart
void main() {
  Shard.observer = LoggingObserver();
  runApp(MyApp());
}
```

Customize sink and filtering:

```dart
Shard.observer = LoggingObserver(
  logChanges: false,
  shouldLog: (shard) => shard is! NoisyShard,
  printer: (msg) => Sentry.captureMessage(msg),
);
```

---

## Testing your shards

Shard ships a dedicated test utility entry point — import it from your test files:

```dart
import 'package:shard/shard_test.dart';
```

Assert state sequences with `ShardTester`:

```dart
test('counter increments by 1', () async {
  final shard = CounterShard();
  final tester = ShardTester(shard);
  addTearDown(tester.dispose);
  addTearDown(shard.dispose);

  shard.increment();
  shard.increment();

  await tester.expectStates([1, 2]);
});
```

Or use the declarative `shardTest()` helper:

```dart
test('increments by 1', () async {
  await shardTest<CounterShard, int>(
    build: () => CounterShard(),
    act: (s) async => s.increment(),
    expect: [1],
  );
});
```

Test persistence and caching with in-memory fakes:

```dart
final storage = FakeStateStorage();
final shard = TodoShard(storage: storage);
// ... assert storage.rawValue('todos') etc.

final cache = FakeCacheService()..seed('user_42', User(id: '42'));
// ... pass cache to your FutureShard for cached-path testing
```

Capture global observer events in tests with `MockShardObserver.scope`:

```dart
await MockShardObserver.scope((observer) async {
  final shard = AuthShard();
  addTearDown(shard.dispose);
  shard.login(...);
  expect(observer.errorsFor(shard), isEmpty);
});
```

````

- [ ] **Step 3: Verify the README still renders**

Run: `flutter pub publish --dry-run`
Expected: No errors or warnings about README format.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: add testing section and LoggingObserver to README"
```

---

### Task 32: Final acceptance verification

This task runs the spec's acceptance criteria end-to-end. No code changes. If any step fails, fix the underlying issue (which is itself a bug — find the failing test and trace the cause).

- [ ] **Step 1: All tests pass**

Run: `flutter test`
Expected: PASS — every test in `test/` is green. Count should be over 130 individual tests.

- [ ] **Step 2: Lint is clean**

Run: `dart analyze`
Expected: `No issues found!`

- [ ] **Step 3: Pub publish dry-run is clean**

Run: `flutter pub publish --dry-run`
Expected: No warnings, no errors.

- [ ] **Step 4: Coverage targets met**

Run: `flutter test --coverage`
Expected: `coverage/lcov.info` is generated. Inspect with any LCOV viewer:
- state_management: ≥ 95% line coverage
- persistence: ≥ 95%
- caching: ≥ 90%
- locator: ≥ 90%
- widgets: ≥ 85%

If a directory falls short, identify uncovered code and either add a test or document why it is intentionally uncovered (e.g., debug-only branches, deprecated dead code).

- [ ] **Step 5: `fake_async` is dev-only**

Run: `flutter pub deps --no-dev --style=compact`
Expected: `fake_async` is NOT listed. Only Flutter SDK packages appear.

- [ ] **Step 6: Production import graph does not touch testing utilities**

Run: `grep -rn "shard_test\|src/testing" lib/`
Expected: ONLY `lib/shard_test.dart` is matched (the entry point itself). No other file under `lib/` references the testing utilities.

- [ ] **Step 7: Public API surface check**

Run: `grep "^export " lib/shard.dart`
Expected: Two lines:

```
export 'src/src.dart';
export 'src/observability/logging_observer.dart';
```

No other exports were added or removed from the main entry point.

- [ ] **Step 8: Final commit (if needed)**

If the verification surfaced bugs and you committed fixes during this task, ensure the working tree is clean now:

Run: `git status`
Expected: `nothing to commit, working tree clean`.

---

## Self-review checklist (for the plan author, not the implementer)

- All spec sections (§3 file layout, §4 testing utilities, §5 LoggingObserver, §6 internal tests, §7 pubspec changes, §8 README, §9 acceptance criteria) have at least one corresponding task. ✓
- Every step that introduces code shows the actual code (no "TODO", "TBD", "similar to above"). ✓
- File paths are exact and absolute relative to the repo root. ✓
- Type names and method signatures used in later tasks match those defined in earlier tasks (`expectStates`, `recordedStates`, `FakeCacheService.seed`, etc. all match the spec). ✓
- The plan can be executed top-to-bottom by an engineer with zero context: each task includes file paths, test code, implementation code, run commands, expected results, and a commit step. ✓
