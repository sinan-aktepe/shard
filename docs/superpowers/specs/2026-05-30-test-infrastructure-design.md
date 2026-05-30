# Test Infrastructure Design

**Date:** 2026-05-30
**Scope:** Add a complete testing story to the `shard` package: a public test utility entry point (`lib/shard_test.dart`), a debug-friendly `LoggingObserver` in the main library, and the package's own internal test suite.
**Status:** Spec — pending implementation plan.

---

## 1. Why

`shard` is at 1.0.1 with a frozen public API, but the package has no test suite at the root (only the default Flutter counter test inside `example/`). For a state-management package this is both a credibility gap (pub.dev score, regression risk) and a missing feature: users who adopt `shard` have no idiomatic way to test their own `Shard` subclasses, persistence flows, or async shards.

This spec adds:

1. A public test utility surface under `package:shard/shard_test.dart` — no extra runtime dependencies.
2. `LoggingObserver` in the main library — a debug-build default for observability that everyone otherwise rewrites.
3. The package's own unit and widget tests (`test/`), built on top of the same utilities (dogfooding).

All additions are pure additions to the 1.x API. No breaking changes. No new runtime dependencies. One new dev dependency (`fake_async`).

---

## 2. Goals and non-goals

### Goals

- Provide a deterministic, ergonomic way to assert state sequences on any `Shard<T>`.
- Provide drop-in in-memory fakes for the two adapter interfaces (`StateStorage`, `CacheService`) so users can test persistence and caching flows without real backends.
- Provide a `MockShardObserver` with safe scoped install/uninstall, because `Shard.observer` is global static.
- Ship a debug-build `LoggingObserver` integrated with Flutter DevTools' Logging tab.
- Cover the package's existing implementation with unit and widget tests at high coverage (≥ 95% for state/persistence, ≥ 90% for caching/locator, ≥ 85% for widgets).

### Non-goals

- No `flutter_test` matcher (`emitsStates(...)` etc.). `ShardTester` exposes assertion methods directly to avoid the `flutter_test`/`matcher` runtime dependency that a custom matcher would imply.
- No composite observer helper (`CompositeShardObserver`). Users who need multiple observers can compose them in a single subclass.
- No CI workflow (GitHub Actions, etc.) in this iteration — flagged as follow-up work in §10.
- No tests for the `example/` app — out of scope.
- No DevTools extension — orthogonal to test infrastructure.

---

## 3. Architecture

### 3.1 File layout

```
lib/
  shard.dart                          (modified: re-exports LoggingObserver)
  shard_test.dart                     (new: public entry point for testing utilities)
  src/
    observability/                    (new directory)
      logging_observer.dart           (new)
    testing/                          (new directory; only re-exported by lib/shard_test.dart)
      testing.dart                    (new: bundle export)
      shard_tester.dart               (new)
      fake_state_storage.dart         (new)
      fake_cache_service.dart         (new)
      mock_shard_observer.dart        (new)
test/                                 (new root directory)
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
docs/
  superpowers/
    specs/
      2026-05-30-test-infrastructure-design.md   (this document)
```

Counts: 1 new public entry point, 5 new files under `lib/src/`, 19 new test files, 1 spec doc. Zero existing-file breaking changes; `lib/shard.dart` gets one additional re-export.

### 3.2 Two public entry points

| Entry point | Purpose | Importable from |
|---|---|---|
| `package:shard/shard.dart` | Main library (existing surface + `LoggingObserver`) | App code |
| `package:shard/shard_test.dart` | Test utilities only | Test code |

No file in `lib/shard.dart`'s import graph imports `lib/shard_test.dart`. Production builds never link the testing code.

### 3.3 Why `lib/src/testing/` and not `lib/testing/`

Dart convention: `lib/`'s top level is public; `lib/src/` is implementation. Putting the testing implementations under `lib/src/testing/` and re-exporting through `lib/shard_test.dart` causes pub_lint to warn if someone tries `import 'package:shard/src/testing/shard_tester.dart'` directly. The only supported path is through the entry point.

### 3.4 Dependency posture

| | Before | After |
|---|---|---|
| Runtime `dependencies` | flutter SDK only | flutter SDK only (unchanged) |
| `dev_dependencies` | flutter_test, flutter_lints | flutter_test, flutter_lints, **fake_async** |

`fake_async` is dev-only; it does not propagate to users of the package. The README claim "**Zero** external dependencies" remains accurate (it refers to runtime).

---

## 4. Public API — `lib/shard_test.dart`

### 4.1 `ShardTester<T>`

Captures state emissions from a `Shard<T>` from the moment of construction and provides assertion + waiting helpers. Self-contained: no `flutter_test`/`matcher` dependency. Throws `ShardAssertionError` / `ShardTimeoutError` on failure, which Flutter's `expect()` treats as test failures (any thrown `Error`/`Exception` fails a test).

```dart
class ShardTester<T> {
  ShardTester(Shard<T> shard);

  // Read-only inspection
  Shard<T> get shard;
  List<T> get recordedStates;     // states emitted AFTER construction (initial state excluded)
  T? get lastState;
  bool get hasStates;

  // Mutating
  void clear();                   // wipe recorded list; keep subscription active
  Future<void> dispose();         // remove listener; fail pending waiters

  // Async waiting
  Future<T> waitForNext({Duration timeout = const Duration(seconds: 1)});
  Future<T> waitFor(
    bool Function(T state) predicate, {
    Duration timeout = const Duration(seconds: 1),
  });

  // Assertions (throw on mismatch)
  Future<void> expectStates(
    List<T> expected, {
    Duration timeout = const Duration(seconds: 1),
    bool exactMatch = false,
  });
  Future<void> expectNoMoreStates({
    Duration window = const Duration(milliseconds: 100),
  });

  // Scoped helper (auto-dispose). Type param renamed to S to avoid shadowing the
  // outer class's T (static methods can't see the class's type parameter).
  static Future<R> scope<S, R>(
    Shard<S> shard,
    Future<R> Function(ShardTester<S> tester) body,
  );
}

class ShardAssertionError extends Error {
  ShardAssertionError(this.message);
  final String message;
  @override String toString();
}

class ShardTimeoutError extends Error {
  ShardTimeoutError(this.message);
  final String message;
  @override String toString();
}
```

#### Semantics

- **Initial state excluded.** `recordedStates` only contains emissions after `ShardTester(shard)` runs. Initial state is reachable via `shard.state`. This matches a "stream from now on" mental model.
- **`expectStates` is prefix-match by default.** It waits up to `timeout` for at least `expected.length` states, then compares element-by-element. `exactMatch: true` additionally requires `recordedStates.length == expected.length`. Empty `expected` list: with `exactMatch: false` always succeeds (vacuously true); with `exactMatch: true` succeeds only if `recordedStates` is also empty after the timeout window — useful with a small `timeout` to assert "no states emitted at all".
- **Mismatch messages include both sides in full.** When `expected` and `recordedStates` differ, the error message prints both lists end-to-end so the diff is obvious.
- **`waitFor` checks the current state once, then subscribes.** If `shard.state` already satisfies the predicate at call time, returns it synchronously. Otherwise subscribes to future emissions and returns the first satisfying one. Does NOT scan `recordedStates` history — semantics are "wait until the live condition holds", not "did this ever happen". For history scans, users iterate `recordedStates` themselves.
- **Errors are not captured by `ShardTester`.** `Shard.addError(...)` routes through the global `Shard.observer`; per-instance error capture requires `MockShardObserver` (§4.4). Trade-off noted; the cost is one extra utility in error-path tests.
- **`dispose()` is required.** Listener leaks otherwise. `ShardTester.scope(...)` and `addTearDown(tester.dispose)` are both idiomatic; the docs lead with `scope`.

#### Bonus: declarative `shardTest()` helper

For one-shot "build → act → expect" tests, a thin wrapper:

```dart
Future<void> shardTest<S extends Shard<T>, T>({
  required S Function() build,
  Future<void> Function(S shard)? act,
  required List<T> expect,
  Duration timeout = const Duration(seconds: 1),
});
```

This is a function (not a `test()` registrar like `bloc_test`'s `blocTest`). The user still wraps it in `test('description', () async => shardTest(...))`. It builds the shard, captures with a `ShardTester`, runs `act`, asserts, and disposes both. Pure ergonomic sugar over `ShardTester`.

### 4.2 `FakeStateStorage`

In-memory `StateStorage` for tests. Implements failure injection, latency simulation, and call inspection.

```dart
class FakeStateStorage implements StateStorage {
  FakeStateStorage({Map<String, String>? initialData});

  // Failure injection
  Object? loadError;
  Object? saveError;

  // Latency simulation
  Duration? loadDelay;
  Duration? saveDelay;

  // Inspection
  int get loadCount;
  int get saveCount;
  List<String> get savedKeys;       // in order, duplicates included
  Map<String, String> get data;     // unmodifiable view of underlying map
  bool hasKey(String key);
  String? rawValue(String key);

  // Mutating helpers
  void seed(String key, String value);
  void clear();    // wipes data, keeps counters and injected errors
  void reset();    // wipes data + counters + errors + delays (setUp-friendly)

  // StateStorage API
  @override Future<void> save(String key, String value);
  @override Future<String?> load(String key);
}
```

### 4.3 `FakeCacheService`

In-memory `CacheService`. Same shape as `FakeStateStorage` but for cache.

```dart
class FakeCacheService implements CacheService {
  FakeCacheService({Map<String, CacheEntry>? initialData});

  // Failure injection
  Object? readError;
  Object? writeError;
  Object? deleteError;
  Object? clearError;

  // Latency simulation
  Duration? readDelay;
  Duration? writeDelay;

  // Inspection
  int get readCount;
  int get writeCount;
  int get deleteCount;
  List<String> get readKeys;
  List<String> get writeKeys;
  Map<String, CacheEntry> get entries;
  bool hasKey(String key);

  // Mutating helpers
  void seed(String key, Object? data, {Duration ttl = const Duration(hours: 1)});
  void seedExpired(String key, Object? data);
  void clear();
  void reset();

  // CacheService API
  @override Future<void> write(String key, CacheEntry entry);
  @override Future<CacheEntry?> read(String key);
  @override Future<void> delete(String key);
  @override Future<void> clearAll();
}
```

### 4.4 `MockShardObserver`

Records every `onChange` and `onError` event from the global `Shard.observer` slot. Provides filtering helpers and — crucially — a `scope` static that installs and restores the global observer safely.

```dart
class ObservedChange<T> {
  const ObservedChange(this.shard, this.previousState, this.currentState);
  final Shard<T> shard;
  final T previousState;
  final T currentState;
}

class ObservedError {
  const ObservedError(this.shard, this.error, this.stackTrace);
  final Shard shard;
  final Object error;
  final StackTrace? stackTrace;
}

class MockShardObserver extends ShardObserver {
  MockShardObserver();

  List<ObservedChange> get recordedChanges;
  List<ObservedError> get recordedErrors;

  // Filtering helpers
  List<ObservedChange<T>> changesFor<T>(Shard<T> shard);
  List<ObservedError> errorsFor(Shard shard);
  List<ObservedChange<T>> changesOfType<T>();
  List<ObservedError> errorsOfType<S extends Shard>();

  void clear();

  // Scoped install (preferred usage)
  static Future<R> scope<R>(
    Future<R> Function(MockShardObserver observer) body,
  );

  @override void onChange<T>(Shard<T> shard, T previousState, T currentState);
  @override void onError<T>(Shard<T> shard, Object error, StackTrace? stackTrace);
}
```

`MockShardObserver.scope` saves the previous `Shard.observer`, installs a fresh `MockShardObserver`, runs the body, and restores the previous observer in a `finally` block. Tests that manipulate `Shard.observer` directly without `scope` risk cross-test pollution; docs lead with `scope`.

### 4.5 What is *not* in `lib/shard_test.dart`

- No `flutter_test`-style matchers. `ShardTester.expectStates(...)` is the substitute.
- No `CompositeShardObserver`. Out of scope for this iteration; users can subclass `ShardObserver` and call multiple delegates inline.
- No mockable clock. Test code uses `package:fake_async` directly when needed (the package's own tests do); user code can do the same.
- No fixtures or sample shards. Each test owns its setup.

---

## 5. `LoggingObserver` (main library)

Location: `lib/src/observability/logging_observer.dart`, re-exported from `lib/shard.dart`. Not a test utility — debug-time observability for production app code.

```dart
class LoggingObserver extends ShardObserver {
  LoggingObserver({
    bool? enabled,                       // null → kDebugMode
    this.logChanges = true,
    this.logErrors = true,
    this.includeStackTrace = false,
    this.printer,                        // null → dart:developer log(name: 'shard')
    this.shouldLog,                      // null → log every shard
  }) : enabled = enabled ?? kDebugMode;

  final bool enabled;
  final bool logChanges;
  final bool logErrors;
  final bool includeStackTrace;
  final void Function(String message)? printer;
  final bool Function(Shard shard)? shouldLog;

  @override void onChange<T>(Shard<T> shard, T previousState, T currentState);
  @override void onError<T>(Shard<T> shard, Object error, StackTrace? stackTrace);
}
```

### Design choices

- **Default sink: `dart:developer.log(name: 'shard')`.** Integrates with Flutter DevTools' Logging tab. `CacheMixin` already uses the same channel; consistent.
- **Defaults to `kDebugMode`.** In release builds the observer is inert — no formatting cost, no privacy concerns for state values that may contain PII. `kDebugMode` comes from `package:flutter/foundation.dart` (Flutter SDK); the new `logging_observer.dart` file imports it, but no new third-party package dependency is introduced.
- **`printer` is opt-in.** Routes formatted messages to a custom sink (Crashlytics, Sentry, file logger). The format itself is fixed; users wanting full format control subclass `ShardObserver`.
- **`shouldLog(shard)` predicate.** Lets users silence noisy shards or only log specific types: `shouldLog: (s) => s is AuthShard`.
- **`includeStackTrace` opt-in.** Stack traces flood the debug console; off by default.

### Fixed log format

```
[CounterShard] 0 → 1
[UserShard] AsyncLoading<User>(previousData: null) → AsyncData<User>(data: User(id: 42, name: Alice))
[AuthShard] ERROR: SocketException: Failed host lookup
```

With `includeStackTrace: true`, the stack trace is appended on the next line(s), no separator.

---

## 6. Package-internal test strategy

### 6.1 Test directory mirrors `lib/src/`

19 files, one per unit. Each file uses the testing utilities from `lib/shard_test.dart` where applicable, dogfooding the public surface.

### 6.2 Per-file coverage outline

#### `state_management/`

- **`shard_test.dart`** — `emit` triggers `notifyListeners` and `onChange`; equality check skips no-op; `emitForce` bypasses equality; `dispose` flips `isDisposed` and cancels timers; post-dispose `emit` is no-op; `addError` calls `onError` and global observer.
- **`future_shard_test.dart`** — `onInit` triggers `build`, emits Loading then Data; build error emits `AsyncError` with stack; `refresh()` re-runs build through Loading; cached value short-circuits build (`FakeCacheService.seed`); expired entry forces refetch; `allowCache = false` bypasses cache; dispose mid-fetch is safe.
- **`stream_shard_test.dart`** — initial Loading then Data; stream errors emit `AsyncError`; `refresh()` cancels and re-subscribes; dispose cancels subscription.
- **`async_value_test.dart`** — equality with/without `previousData`; `dataOrNull` semantics across all three subtypes; `isLoading`/`hasData`/`hasError` flags; `toString` stability.
- **`debounce_throttle_test.dart`** — `debounce` delays callback; consecutive calls cancel previous; different keys independent; `throttle` executes leading edge, ignores subsequent within window; `cancelAll*` clears all timers; dispose clears all. Uses `fake_async`.
- **`shard_observer_test.dart`** — `onChange` fires on emit; `onError` fires on `addError`; multiple shards notify same observer; swapping observers takes effect immediately. Uses `MockShardObserver`.

#### `persistence/`

- **`state_persistence_test.dart`** — `enablePersistence` triggers `autoLoad` when enabled; `emit` triggers debounced save; multiple emits within window collapse to one save; `saveState` serializes via the save queue; `onLoadComplete(null)` for empty storage; `onLoadComplete(data)` for non-empty; `onSaveError` / `onLoadError` callbacks fire; `disablePersistence` stops auto-save; `disposePersistenceIfEnabled` flushes pending save. Uses `FakeStateStorage` + `fake_async`.
- **`persistent_shard_test.dart`** — end-to-end T vs K type separation (only the persisted slice goes through the serializer); `retry()` re-runs initialization after a failure; `storageFactory` async path.
- **`primitive_serializers_test.dart`** — `IntSerializer` / `DoubleSerializer` / `BoolSerializer` / `StringSerializer` roundtrip; edge cases (negative, zero, fractional, empty string, unicode).
- **`state_serializer_test.dart`** — `stateSerializer<T>()` factory roundtrip for a simple `toJson`/`fromJson` object; list of objects; nested objects; malformed input throws (caller responsibility).

#### `caching/`

- **`memory_cache_service_test.dart`** — `write`/`read`/`delete`/`clearAll`; singleton: `MemoryCacheService()` always returns the same instance; expired entries readable but `isExpired` true.
- **`cache_mixin_test.dart`** — `resolve` cache hit returns cached without calling fetcher; miss calls fetcher and writes; expired calls fetcher; `forceRefresh: true` bypasses cache; `onErrorReturnOldCache: true` returns stale on fetcher error; rethrows when no cached entry exists.
- **`cache_entry_test.dart`** — `isExpired` true when `expiryDate < now`.

#### `locator/`

- **`shard_locator_test.dart`** — `registerSingleton` → `get` returns the same instance; `registerLazySingleton` triggers factory on first `get` and caches; `isRegistered` reflects both eager and lazy registrations; `reset()` clears everything; `get` without registration throws `StateError`; lazy after eager replaces eager (and vice versa).

#### `widgets/`

- **`shard_provider_test.dart`** — `create` constructor: `onInit` called once, `dispose` called on removal; `value` constructor: `dispose` NOT called on removal; `of()` with `listen: true` rebuilds on emit; `of()` with `listen: false` does not; assertion error if no provider in tree.
- **`shard_builder_test.dart`** — rebuilds on every emit; `buildWhen: false` suppresses rebuild; `listener` runs as side effect; `listenWhen: false` suppresses listener; direct `shard:` reference works without provider; previous state argument is correct.
- **`shard_selector_test.dart`** — rebuilds only when `selector(state)` returns a different value (by `==`); selector returning equal value across emits skips rebuild.
- **`async_shard_builder_test.dart`** — Loading → `onLoading`; Data → `onData`; Error → `onError`; `showDataOnLoading: true` shows data when Loading has `previousData`; defaults for missing `onLoading` / `onError`.
- **`multi_shard_provider_test.dart`** — providers nested in declaration order (first is outermost); empty list returns child unchanged; mix of `create` and `value` constructors works.
- **`context_extensions_test.dart`** — `context.read<T>()` returns the shard; emit to that shard does not rebuild the reading widget.

### 6.3 Timing strategy

`debounce`, `throttle`, debounced auto-save, and any cache-TTL test uses `package:fake_async` for deterministic virtual time. Real-time `Future.delayed` is forbidden in tests — too flaky on CI.

### 6.4 Coverage targets

- State management (`lib/src/state_management/`): ≥ 95%
- Persistence (`lib/src/persistence/`): ≥ 95%
- Caching (`lib/src/caching/`): ≥ 90%
- Locator (`lib/src/locator/`): ≥ 90%
- Widgets (`lib/src/widgets/`): ≥ 85%

Reported via `flutter test --coverage` → `coverage/lcov.info`. No automated CI threshold in this iteration; tracked manually.

---

## 7. Pubspec changes

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  fake_async: ^1.3.1   # NEW
```

Runtime `dependencies` block unchanged. No new export from `lib/shard.dart` that would require a runtime dep.

---

## 8. README updates

- A new section: "Testing your shards" with a `package:shard/shard_test.dart` import line and a small `ShardTester` snippet.
- A short note in "What's Included" listing `LoggingObserver` and the testing utilities.
- The "Zero external dependencies" claim is unchanged (it refers to runtime).

---

## 9. Acceptance criteria

A merge is acceptable when all of the following hold:

1. `flutter test` passes with the new test suite — every test green.
2. `dart analyze` reports zero issues across `lib/` and `test/`.
3. `flutter pub publish --dry-run` reports no warnings or errors.
4. Coverage targets in §6.4 are met (verified via `flutter test --coverage`).
5. `flutter pub deps --no-dev` shows zero non-Flutter-SDK runtime dependencies (i.e. `fake_async` is dev-only and does not leak to downstream consumers).
6. No existing public API in `lib/shard.dart` has changed signature; only the additive `LoggingObserver` export is new.
7. README updated per §8.

---

## 10. Out of scope / future work

- **CI workflow.** A GitHub Actions config running `flutter test --coverage` + a coverage badge belongs in a follow-up PR. Spec'd separately.
- **`CompositeShardObserver`.** Defer until at least one concrete need surfaces in user issues.
- **DevTools extension.** Orthogonal effort; large enough to warrant its own design.
- **Migration / versioning support for persistence** (item 6 from the original analysis). Tracked separately.
- **`MutationShard`, `ComputedShard`, `ShardFamily`** (items 2, 4, 5). Each is its own design.
- **Tests for `example/`.** Not in scope.
- **Property-based testing.** Tempting for `AsyncValue` equality and serializer roundtrips, but adds a dependency (`glados` or similar). Defer.

---

## 11. Risks and trade-offs

- **`ShardTester` carries its own assertion errors instead of `flutter_test` matchers.** Trade-off: zero matcher dep, slightly less idiomatic Dart test surface. Mitigation: error messages include both expected and actual lists in full, so debugging is fast.
- **Per-instance error capture requires `MockShardObserver`, not `ShardTester`.** Trade-off: two utilities for error-path tests. Mitigation: docs lead with `MockShardObserver.scope` for error tests; pattern is one extra `await scope(...)` wrapper.
- **`fake_async` dev_dep.** Small, well-maintained, dart-lang authored package. Risk minimal.
- **`LoggingObserver` defaults to `kDebugMode`.** Users who explicitly want production logging must pass `enabled: true`. Slight friction trade for safer default.
