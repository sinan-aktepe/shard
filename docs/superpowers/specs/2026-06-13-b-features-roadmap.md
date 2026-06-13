# Shard — "B Features" Roadmap & Design Spec

**Date:** 2026-06-13
**Scope:** Design reference for the next wave of `shard` features (the "B items" from the 2026-06-13 package review). This is a *roadmap of independent features*, not a single execution plan. Each feature has a self-contained design here; when one is picked for work, turn its section into a per-feature execution plan under `docs/superpowers/plans/` and implement with TDD.
**Status:** Spec — features unstarted. Reference across sessions.

---

## 0. How to use this document

This file is the durable backlog for post-1.2.0 feature work. Across sessions:

1. **Pick one feature** from the catalog (§3). They are independent — no feature depends on another except where noted.
2. If the design here leaves open questions (each section has an **Open questions** subsection), resolve them first — brainstorm with the user if the answer changes the public API.
3. **Write an execution plan** for that one feature at `docs/superpowers/plans/YYYY-MM-DD-<feature>.md` using the `superpowers:writing-plans` skill (bite-sized TDD steps with full code).
4. **Implement with TDD** (`superpowers:test-driven-development`): failing test → minimal code → green. Match the existing test layout under `test/` (mirrors `lib/src/`).
5. **Ship additively:** bump the minor version in `pubspec.yaml`, add a `CHANGELOG.md` entry. Run `flutter test`, `dart analyze`, `flutter pub publish --dry-run` before claiming done.

Do not batch multiple features into one PR — each should be a working, independently reviewable change.

---

## 1. Context: where the package is now

- Current version: **1.2.0** (A-item fixes + additive features shipped 2026-06-13). Previously published on pub.dev: 1.0.1.
- Public API is **frozen for 1.x** (CHANGELOG 1.0.0). Everything exported from `lib/shard.dart`, `lib/shard_test.dart`, and the `lib/src/**` files re-exported by `lib/src/src.dart` is public.
- The package has **zero runtime dependencies** other than the Flutter SDK. This is a core selling point — *do not add runtime dependencies for any feature below*. Dev dependencies are fine (`fake_async` is already one).
- There is a full test suite under `test/` mirroring `lib/src/`. New features add tests in the matching subdirectory.

Several features here were already flagged as future work in the test-infrastructure spec (`2026-05-30-test-infrastructure-design.md`, §10): `MutationShard`, `ComputedShard`, `ShardFamily`, persistence migration/versioning, the DevTools extension, and `CompositeShardObserver`. This document supersedes those one-liners with real designs.

---

## 2. Cross-cutting constraints (apply to every feature)

1. **Additive only for 1.x.** Adding new classes, mixins, top-level functions, or new optional named parameters with defaults is non-breaking → minor bump. The following ARE breaking and must be deferred to a 2.0 spec:
   - Adding a member to a sealed class hierarchy via a *new subtype* (`AsyncValue` — adding `AsyncIdle` breaks every exhaustive `switch`). Adding *methods/statics* to the sealed base is fine.
   - Adding a member to `StateStorage` / `CacheService` / `StateSerializer` / `ShardObserver` — these are implemented with `implements` by users, so any new member breaks them.
   - Renaming/removing/changing the signature of anything public.
2. **Zero runtime deps.** Use only `dart:*` and `package:flutter/*` (the SDK). No `package:collection`, no `package:rxdart`, etc.
3. **Doc-comment everything public.** Multi-line `///` blocks with example snippets — pub.dev scores this and the codebase is consistent about it.
4. **Lifecycle discipline.** `onInit`/`dispose`/`onChange`/`onError` are `@mustCallSuper`. `emit` is `@protected`. Mixins that touch `emit` must mind ordering with `StatePersistenceMixin` (which overrides `emit`/`emitForce`).
5. **Tests use `fake_async` for timers**, real fakes (`FakeStateStorage`/`FakeCacheService`) for adapters, and `ShardTester` for emission sequences. No real `Future.delayed` in tests.

---

## 3. Feature catalog (priority order)

| ID | Feature | Value | Effort | Additive in 1.x? | Depends on |
|----|---------|-------|--------|------------------|-----------|
| **B2** | `AsyncValue.when/map/maybeWhen` + `AsyncValue.guard` | High | S | ✅ yes | — |
| **B1** | Async mutation/command helper | High | M | ✅ yes (see idle-state note) | B2 helps |
| **B6** | `clearPersistence()` (logout) | High | S | ✅ yes (empty-write trick) | — |
| **B5** | Persistence versioning + migration | High | M | ✅ yes (opt-in envelope) | — |
| **B3** | `ComputedShard` / derived shard | High | M | ✅ yes | — |
| **B4** | `ShardListener` / `MultiShardListener` | Med | S | ✅ yes | — |
| **B7** | `shard.stream` bridge | Med | S | ✅ yes | — |
| **B8** | `StreamShard.pause()/resume()` | Med | XS | ✅ yes | — |
| **B11** | Undo/redo (`HistoryMixin`) | Med | M | ✅ yes | — |
| **B9** | Persistence `flushOnPause` (lifecycle) | Med | M | ✅ yes (opt-in) | — |
| **B10** | DevTools extension (companion package) | High | XL | N/A (separate package) | — |

Effort: XS < S < M < L < XL. Recommended start: **B2 → B6 → B8** (quick wins), then **B1 / B5 / B3** (the meaty ones), then the rest.

---

## B2. `AsyncValue` pattern-matching + `guard`

**File:** modify `lib/src/state_management/async_value.dart`. Tests: `test/state_management/async_value_test.dart`.

### Problem
`AsyncValue<T>` is a sealed union (`AsyncLoading`/`AsyncData`/`AsyncError`) but only exposes flag getters (`isLoading`, `dataOrNull`, …). Outside the widget layer (`AsyncShardBuilder` covers widgets), users hand-write `switch` statements or chained getters. The idiomatic ergonomics other libraries ship — `when`, `maybeWhen`, `map`, and `guard` — are missing.

### Proposed API (methods/static added to the sealed base — non-breaking)
```dart
sealed class AsyncValue<T> {
  // Exhaustive handler. previousData is surfaced to loading/error so callers
  // can show stale data.
  R when<R>({
    required R Function(T? previousData) loading,
    required R Function(T data) data,
    required R Function(Object error, StackTrace? stackTrace, T? previousData) error,
  });

  // Partial handler with a fallback.
  R maybeWhen<R>({
    R Function(T? previousData)? loading,
    R Function(T data)? data,
    R Function(Object error, StackTrace? stackTrace, T? previousData)? error,
    required R Function() orElse,
  });

  // Transform the success value, preserving loading/error (and previousData).
  AsyncValue<R> mapData<R>(R Function(T data) transform);

  // Run f only when there is data; otherwise null.
  R? whenData<R>(R Function(T data) f);

  // Wrap a future into try/catch → AsyncData / AsyncError. Optionally carry
  // previousData onto the error.
  static Future<AsyncValue<T>> guard<T>(
    Future<T> Function() future, {
    T? previousData,
  });
}
```

### Sketch
```dart
R when<R>({required loading, required data, required error}) => switch (this) {
  AsyncLoading<T>(:final previousData) => loading(previousData),
  AsyncData<T>(:final data) => data(data),          // name carefully to avoid shadow
  AsyncError<T>(:final error, :final stackTrace, :final previousData) =>
      error(error, stackTrace, previousData),
};

static Future<AsyncValue<T>> guard<T>(future, {previousData}) async {
  try { return AsyncData<T>(await future()); }
  catch (e, st) { return AsyncError<T>(e, st, previousData); }
}
```

### Tests
- `when` routes each subtype to the right branch and passes `previousData`.
- `maybeWhen` falls through to `orElse` when the matching handler is null.
- `mapData` transforms `AsyncData`, leaves `AsyncLoading`/`AsyncError` as the same variant with `previousData` preserved.
- `whenData` returns null for loading/error.
- `guard` returns `AsyncData` on success, `AsyncError` (with stack + optional previousData) on throw.

### Additive/breaking
✅ Additive — adding methods and a static to a sealed base does not break exhaustive switches. Safe for 1.x.

### Open questions
- Should `when`'s `loading`/`error` expose `previousData` (richer, slightly more verbose) or omit it (simpler)? Recommendation: expose it; it is the main reason `AsyncValue` carries `previousData` at all.

---

## B1. Async mutation / command helper

**Files:** new `lib/src/state_management/command_shard.dart` (+ export from `state_management.dart`); optional new widget `lib/src/widgets/command_builder.dart`. Tests: `test/state_management/command_shard_test.dart`.

### Problem
`FutureShard`/`StreamShard` model **reads** (`build()` runs automatically). There is no first-class helper for **writes/actions** — form submit, create/update/delete, "send" buttons — which need: an idle→running→success/failure lifecycle, a double-submit guard, and error capture, without writing a bespoke `Shard<...>` each time.

### Key design tension (resolve before building)
The natural representation is `AsyncValue<T>`, but a mutation starts **idle** (not loading), and `AsyncValue` has no `AsyncIdle` variant. Adding `AsyncIdle` to the sealed `AsyncValue` is a **breaking change** (every exhaustive `switch`, including `AsyncShardBuilder`, would stop compiling). So for 1.x we must NOT reuse `AsyncValue` with a new idle case.

**Recommended approach (additive):** a dedicated lightweight state type + a `Shard` subclass.

```dart
/// Lifecycle of a one-shot action.
sealed class CommandState<R> {
  const CommandState();
  bool get isIdle => this is CommandIdle<R>;
  bool get isRunning => this is CommandRunning<R>;
  bool get isSuccess => this is CommandSuccess<R>;
  bool get isFailure => this is CommandFailure<R>;
  R? get valueOrNull => this is CommandSuccess<R> ? (this as CommandSuccess<R>).value : null;
}
final class CommandIdle<R> extends CommandState<R> { const CommandIdle(); }
final class CommandRunning<R> extends CommandState<R> { const CommandRunning(); }
final class CommandSuccess<R> extends CommandState<R> { const CommandSuccess(this.value); final R value; }
final class CommandFailure<R> extends CommandState<R> {
  const CommandFailure(this.error, [this.stackTrace]);
  final Object error; final StackTrace? stackTrace;
}

/// A Shard that runs a single async action and tracks its lifecycle.
/// Plugs into ShardProvider/context.read like any Shard.
class CommandShard<Arg, Res> extends Shard<CommandState<Res>> {
  CommandShard(this._action) : super(const CommandIdle());
  final Future<Res> Function(Arg arg) _action;

  bool get isRunning => state.isRunning;

  /// Runs the action. Ignored if already running (double-submit guard).
  /// Returns the result on success, null on failure.
  Future<Res?> execute(Arg arg) async {
    if (state.isRunning || isDisposed) return null;
    emit(const CommandRunning());
    try {
      final result = await _action(arg);
      if (isDisposed) return null;
      emit(CommandSuccess(result));
      return result;
    } catch (e, st) {
      if (isDisposed) return null;
      addError(e, st);
      emit(CommandFailure(e, st));
      return null;
    }
  }

  void reset() => emit(const CommandIdle());
}
```

Optional ergonomic widget `CommandBuilder<C extends CommandShard<dynamic, Res>, Res>` switching on `CommandState` (idle/running/success/failure), mirroring `AsyncShardBuilder`.

### Alternatives considered
- **Reuse `AsyncValue` + `AsyncIdle`** — rejected for 1.x (breaking sealed-class change). Revisit for 2.0; it would unify mutations with `AsyncShardBuilder`.
- **A `MutationMixin` keyed by name** (`mutate<R>(action, {key})` storing a `Map<String, CommandState>`) — more flexible (multiple mutations per shard) but a messier API and harder to render. Could ship later as a complement.

### Tests
- `execute` emits `CommandRunning` then `CommandSuccess(value)` and returns the value.
- failure path emits `CommandFailure(error)`, returns null, and routes through `addError` (assert via `MockShardObserver`).
- second `execute` while running is ignored (double-submit guard) — use a `Completer`-gated action, assert the action ran once.
- `reset` returns to `CommandIdle`.
- dispose mid-run is safe (no emit after dispose).

### Additive/breaking
✅ Additive (all-new types/widget). The `AsyncIdle` unification is the only breaking variant, explicitly deferred.

### Open questions
- Ship `CommandBuilder` now or just the shard? Recommendation: ship both; the builder is small and the feature is half as useful without it.
- Name: `CommandShard` vs `MutationShard`. "Command" avoids implying it must mutate. Pick during brainstorming.

---

## B6. `clearPersistence()` for logout

**File:** modify `lib/src/persistence/state_persistence.dart`. Tests: `test/persistence/state_persistence_test.dart`.

### Problem
On logout you want to wipe a shard's persisted slice. Today there is only `disablePersistence()` (stops auto-save, leaves stored data intact). `StateStorage.clear()` was deliberately removed in 0.2.0 because it wiped *all* keys. There is no per-key clear.

### Constraint
Adding `delete(String key)` to the `StateStorage` interface is **breaking** (users `implements StateStorage`). Defer the real `delete` to 2.0.

### 1.x-safe approach (additive)
`loadState()` already treats an empty stored string as "no data" (`data != null && data.isNotEmpty ? deserialize : null`). So clearing == writing an empty string for this key:

```dart
/// Clears this shard's persisted slice from storage.
///
/// Cancels any pending debounced save, then overwrites the stored value with
/// an empty string, which [loadState] treats as "no data" on the next launch
/// ([onLoadComplete] receives null). Does NOT change the in-memory state — pair
/// it with `emit(initialState)` if you also want to reset the live state.
///
/// Typical use: on logout.
Future<void> clearPersistence() async {
  final config = _persistenceConfig;
  if (config == null) return;
  cancelDebounce(_autoSaveDebounceKey);
  _saveQueue = _saveQueue.then((_) async {
    try {
      await config.storage.save(config.key, '');
    } catch (error, stackTrace) {
      config.onSaveError?.call(error, stackTrace);
    }
  });
  return _saveQueue;
}
```

Surface it on `PersistentShard` too (it already mixes in the mixin, so it's inherited automatically — just document it there).

### Tests
- after `clearPersistence()`, `FakeStateStorage.rawValue(key)` is `''`.
- a subsequent `loadState()` calls `onLoadComplete(null)`.
- a debounced save in flight is cancelled (no stale value written after clear) — `fake_async` + assert final stored value is `''`.

### Additive/breaking
✅ Additive. Note in the doc-comment that this leaves an empty entry (not a true delete); a real `StateStorage.delete` is a 2.0 item.

### Open questions
- Should `clearPersistence()` also reset in-memory state? Recommendation: no — keep it storage-only; resetting needs an initial value the mixin doesn't hold. `SimplePersistentShard` could add a `clearAndReset()` convenience later.

---

## B5. Persistence versioning + migration

**Files:** modify `lib/src/persistence/state_persistence.dart` (`PersistenceConfig`, `enablePersistence`, `loadState`, `saveState`) and `lib/src/state_management/persistent_shard.dart` (constructor params). Tests: `test/persistence/state_persistence_test.dart`, `test/persistence/persistent_shard_test.dart`.

### Problem
When a persisted model's JSON shape changes between app releases, `serializer.deserialize(oldData)` throws and the only recourse is `onLoadError` (data lost). There is no schema-versioning/migration path.

### Design: opt-in version envelope
Store `{"v": <version>, "p": "<serialized payload string>"}` instead of the bare payload. On load, detect the envelope; if the stored version is older, run `migrate` on the payload before `deserialize`.

```dart
enablePersistence({
  ...,
  int version = 1,
  String Function(int fromVersion, String payload)? migrate,
});
```

- **Write** (`saveState`): if `version == 1 && migrate == null` → write the bare payload exactly as today (byte-identical, so existing data and downgrades are unaffected). Otherwise write `jsonEncode({'v': version, 'p': serializer.serialize(data)})`.
- **Read** (`loadState`): read raw string. Try to parse as an envelope (`jsonDecode` → Map with `v` + `p`). If it parses as an envelope, `storedVersion = v`, `payload = p`. If it does NOT look like an envelope, it is legacy data → `storedVersion = 1`, `payload = rawString`. If `storedVersion < version && migrate != null`, `payload = migrate(storedVersion, payload)`. Then `serializer.deserialize(payload)`.

This keeps the default (version 1, no migrate) **byte-identical** to current behavior, so it is fully additive and backward compatible. Versioning only changes the on-disk format once a user opts in.

`PersistentShard` gets matching constructor params `version` / `migrate` forwarded into `enablePersistence`.

### Tests
- default (no version/migrate): stored value is the bare payload (unchanged format); roundtrip works.
- `version: 2` writes an envelope (`rawValue` is JSON with `v` and `p`).
- loading legacy bare data with `version: 2, migrate: ...` calls `migrate(1, payload)` then deserializes the migrated payload.
- loading a v1 envelope with current `version: 3` calls `migrate(1, ...)` (migrate is responsible for chaining 1→2→3, or is called once with fromVersion; decide below).
- migrate throwing routes to `onLoadError`.

### Additive/breaking
✅ Additive (opt-in; default unchanged). 

### Open questions
- `migrate(fromVersion, payload)` called **once** (user chains internally) vs the framework calling it stepwise (1→2, 2→3)? Recommendation: call once with `fromVersion`; simpler framework, user owns the chain. Document clearly.
- Envelope detection heuristic: a payload that is itself a JSON object with keys literally named `v`/`p` could be misdetected. Mitigation: use distinctive keys (`__shard_v`, `__shard_p`) to make collision essentially impossible. Decide key names during implementation.

---

## B3. `ComputedShard` / derived shard

**Files:** new `lib/src/state_management/computed_shard.dart` (+ export). Tests: `test/state_management/computed_shard_test.dart`.

### Problem
Deriving a value from one or more shards (cart total from cart items, "isFormValid" from several field shards) currently requires manual `addListener`/`removeListener` plumbing in every subclass. No reactive composition primitive exists.

### Design
A shard that listens to N `Listenable` sources (shards are `ChangeNotifier`s) and recomputes when any of them notifies.

**Primary (inline, safest):** a factory function — `compute` is a closure over already-constructed sources, sidestepping Dart's field-initialization-order trap.
```dart
Shard<T> computedShard<T>(
  List<Listenable> sources,
  T Function() compute,
) => _ComputedShard<T>(sources, compute);
```

**Secondary (subclass):** an abstract base for when you want a named type providable via `ShardProvider`.
```dart
abstract class ComputedShard<T> extends Shard<T> {
  ComputedShard(this._sources, T initial) : super(initial) {
    _recompute();                       // overwrite the throwaway initial
    for (final s in _sources) s.addListener(_recompute);
  }
  final List<Listenable> _sources;

  @protected
  T compute();

  void _recompute() { if (!isDisposed) emit(compute()); }

  @override
  void dispose() {
    for (final s in _sources) s.removeListener(_recompute);
    super.dispose();
  }
}
```

> **Constructor-ordering caveat:** `compute()` runs from the base constructor body, so any subclass field it reads must be set via the initializer list / constructor params (not assigned later in the subclass constructor body). Document this prominently. The `computedShard()` function form does not have this problem and is the recommended default.

### Tests
- recomputes when a source emits; the derived value updates.
- `deepEquals`/`stateEquals` dedup still applies (no notify when computed value unchanged) — combine with `DeepEqualityMixin` in a test.
- listens to multiple sources; any one changing triggers recompute.
- `dispose` detaches all source listeners (assert sources have no listeners afterward, or that post-dispose source emits don't recompute).

### Additive/breaking
✅ Additive (new class + function).

### Open questions
- Should sources be `List<Shard>` (tighter) or `List<Listenable>` (works with any `ChangeNotifier`/`ValueListenable`)? Recommendation: `Listenable` — maximally composable, zero downside.

---

## B4. `ShardListener` / `MultiShardListener`

**Files:** new `lib/src/widgets/shard_listener.dart` (+ export from `widgets.dart`). Tests: `test/widgets/shard_listener_test.dart`.

### Problem
Side-effect-only reactions (navigate on login, snackbar on error) currently require a `ShardBuilder` with a throwaway `builder`. A listener-only widget (like flutter_bloc's `BlocListener`) is missing.

### Design
```dart
class ShardListener<T extends Shard<S>, S> extends StatefulWidget {
  const ShardListener({
    super.key,
    this.shard,
    required this.listener,
    this.listenWhen,
    required this.child,
  });
  final T? shard;
  final void Function(BuildContext context, S previous, S current) listener;
  final bool Function(S previous, S current)? listenWhen;
  final Widget child;
}
```
State logic mirrors `_ShardBuilderState`'s listener path (resolve shard from `shard:` or `ShardProvider.of`, track `_previousState`, apply `listenWhen`) but **never calls `setState`** — `build` just returns `widget.child`. Include the `didUpdateWidget` rebind fix already applied to `ShardBuilder` (A3).

`MultiShardListener` nests multiple listeners around a child, analogous to `MultiShardProvider`:
```dart
class MultiShardListener extends StatelessWidget {
  const MultiShardListener({super.key, required this.listeners, required this.child});
  final List<SingleChildWidget> listeners;   // see note
  final Widget child;
}
```
Note: `MultiShardProvider` uses the `SingleChildShardProvider` interface. For listeners, either reuse a similar single-child interface (a `ShardListener` that can omit `child` and have it injected) or keep `MultiShardListener` minimal by requiring each entry to be a builder. Decide during implementation; simplest is to give `ShardListener` an optional `child` and a `buildWithChild` like providers do.

### Tests
- `listener` fires with correct (prev, curr) on emit; widget does not rebuild (assert child build count unchanged).
- `listenWhen: false` suppresses the listener.
- swapping `shard:` rebinds (didUpdateWidget) — reuse the A3 test pattern.
- `MultiShardListener` fires all listeners; nesting order correct.

### Additive/breaking
✅ Additive (new widgets).

### Open questions
- `MultiShardListener` entry type: reuse a single-child interface (consistent with `MultiShardProvider`) vs a flat list. Recommendation: mirror `MultiShardProvider` for consistency.

---

## B7. `shard.stream` bridge

**File:** modify `lib/src/state_management/shard.dart`. Tests: `test/state_management/shard_test.dart`.

### Problem
`Shard` is a `ChangeNotifier`; there is no `Stream<T>` view. A stream enables `StreamBuilder`, `await for`, stream-combinator composition, and `expectLater(..., emitsInOrder([...]))` in tests — all without a dependency.

### Design
Lazily create a broadcast controller fed by an internal listener; close it on dispose.
```dart
StreamController<T>? _streamController;

/// A broadcast stream of state changes (does NOT replay the current state).
/// The first listener attaches an internal ChangeNotifier listener; the
/// controller is closed on dispose.
Stream<T> get stream {
  final controller = _streamController ??= StreamController<T>.broadcast();
  // attach the forwarding listener exactly once
  return controller.stream;
}
```
Implementation detail: add the forwarding listener (`() => _streamController?.add(state)`) when the controller is first created, and `_streamController?.close()` in `dispose()` (before `super.dispose()`). Decide whether to emit the current state on listen (recommend NO — matches `ShardTester`'s "from now on" model; document it).

### Tests
- emits each post-subscription state in order (`emitsInOrder`).
- does not replay the current state to a new listener.
- closes on dispose (stream `emitsDone`).
- broadcast: two listeners both receive events.

### Additive/breaking
✅ Additive (new getter on `Shard`).

### Open questions
- Replay current value on listen? Recommendation: no (consistent with the rest of the package). If users want the current value they read `shard.state` first.

---

## B8. `StreamShard.pause()` / `resume()`

**File:** modify `lib/src/state_management/stream_shard.dart`. Tests: `test/state_management/stream_shard_test.dart`.

### Problem
A `StreamShard` keeps consuming its source even when the relevant screen is backgrounded. The underlying `StreamSubscription` already supports pause/resume; it's just not exposed.

### Design
```dart
/// Pauses the underlying subscription. Events are buffered by the source per
/// Dart's StreamSubscription.pause semantics.
void pause() => _subscription?.pause();

/// Resumes a paused subscription.
void resume() => _subscription?.resume();

/// Whether the subscription is currently paused.
bool get isPaused => _subscription?.isPaused ?? false;
```

### Tests
- after `pause()`, source events do not emit new states; `isPaused` is true.
- after `resume()`, buffered/new events emit again.
- pause/resume before subscription exists (e.g. before `onInit`) is a safe no-op.

### Additive/breaking
✅ Additive (new methods/getter on `StreamShard`).

### Open questions
- None significant. XS effort; good warm-up task.

---

## B11. Undo/redo — `HistoryMixin`

**File:** new `lib/src/state_management/history.dart` (+ export). Tests: `test/state_management/history_test.dart`.

### Problem
Editor/form-style apps want undo/redo. No primitive exists.

### Design
A mixin that records state transitions and can restore them. Restores must NOT be re-recorded — use the existing public `setStateInternal` (which notifies without going through `emit`'s record hook).
```dart
mixin HistoryMixin<T> on Shard<T> {
  final List<T> _undo = [];
  final List<T> _redo = [];
  bool _restoring = false;

  /// Max retained undo entries (oldest dropped beyond this). Default 50.
  int maxHistory = 50;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  @override
  void onChange(T previousState, T currentState) {
    if (!_restoring) {
      _undo.add(previousState);
      if (_undo.length > maxHistory) _undo.removeAt(0);
      _redo.clear();
    }
    super.onChange(previousState, currentState);
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(state);
    _restoring = true;
    setStateInternal(_undo.removeLast());
    _restoring = false;
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(state);
    _restoring = true;
    setStateInternal(_redo.removeLast());
    _restoring = false;
  }

  void clearHistory() { _undo.clear(); _redo.clear(); }
}
```

> **Ordering note:** if combined with `StatePersistenceMixin`, mind that both interact with state changes. `HistoryMixin` overrides `onChange` (record), persistence overrides `emit` (save). They are orthogonal but test the combination.

### Tests
- emit pushes onto undo; `undo()` restores previous state and enables `redo()`.
- a new emit after undo clears the redo stack.
- `maxHistory` bound drops the oldest entry.
- `undo()` does not itself get recorded as a new history entry (no infinite stacks).
- observer still notified on undo/redo (since `setStateInternal` calls `onChange` → `super`).

### Additive/breaking
✅ Additive (new mixin). Note: `setStateInternal` is already public and intended for exactly this kind of out-of-band restore.

### Open questions
- Should `undo()`/`redo()` record through the observer as normal changes? With `setStateInternal` they do call `onChange`→observer. If that's undesirable for undo, add a guard. Decide during brainstorming.

---

## B9. Persistence `flushOnPause` (app lifecycle)

**File:** modify `lib/src/persistence/state_persistence.dart` (+ `PersistentShard` param). Tests: `test/persistence/state_persistence_test.dart` (with `TestWidgetsFlutterBinding` to drive lifecycle).

### Problem
Auto-save is debounced; if the OS kills the app during the debounce window, the last change is lost. `disposePersistenceIfEnabled` flushes on dispose, but a backgrounded app may never dispose the shard before being killed.

### Design
Opt-in flag that registers a `WidgetsBindingObserver` flushing `saveState()` on `AppLifecycleState.paused`/`detached`.
```dart
enablePersistence({ ..., bool flushOnPause = false });
```
When `flushOnPause` is true, on enable register an observer (`WidgetsBinding.instance.addObserver(...)`); on `disablePersistence`/dispose, remove it. The observer's `didChangeAppLifecycleState` calls `saveState()` when paused/detached.

> **Caveat:** requires `WidgetsFlutterBinding` to be initialized (it is in any running app). Tests must use `TestWidgetsFlutterBinding` and pump a lifecycle change. Keep it strictly opt-in (default false) so non-widget tests of the mixin are unaffected.

### Tests
- with `flushOnPause: true`, driving the binding to `paused` triggers a save even within the debounce window.
- with `flushOnPause: false` (default), lifecycle changes do nothing.
- observer removed on `disablePersistence`/dispose (no leak; assert no save after dispose on a later lifecycle event).

### Additive/breaking
✅ Additive (opt-in flag, default false).

### Open questions
- Flush on `inactive` too, or only `paused`/`detached`? Recommendation: `paused` + `detached` (iOS/Android background); `inactive` is too chatty.

---

## B10. DevTools extension (companion package)

**Location:** a **separate** package (e.g. `shard_devtools`), NOT in this repo's `lib/` — it would pull DevTools/extension dependencies that violate the zero-dep core.

### Problem
No visual tooling. `LoggingObserver` already streams to the DevTools Logging tab, but there's no shard-aware inspector (live state tree, emit timeline, time-travel).

### Direction (not a 1.x core feature)
- Build a `devtools_extension`-based package that consumes a structured event stream from a special observer in the core (the core could expose a tiny, dependency-free hook that the extension subscribes to — design that hook carefully so the core stays zero-dep).
- Out of scope for the core package's 1.x line. Treat as its own project with its own spec when prioritized. Listed here for completeness because it's the highest-"wow" item.

### Additive/breaking
N/A to core (separate package). If the core needs a hook to feed the extension, design it as an additive, dependency-free observer extension point.

---

## 4. Recommended sequencing

1. **B8** (XS) — warm-up, immediately useful.
2. **B2** (S) — unlocks ergonomics that B1 and user code both lean on.
3. **B6** (S) — frequently requested (logout), low risk.
4. **B7** (S) — small, enables stream-based tests/composition.
5. **B1** (M) — high value; do after B2. Resolve the Command naming/idle decision first.
6. **B5** (M) — high value; careful with the envelope format decision.
7. **B3** (M) — reactive composition.
8. **B4** (S) — nice ergonomics once the above land.
9. **B11** (M) — niche but loved where it fits.
10. **B9** (M) — correctness nicety; needs binding-aware tests.
11. **B10** (XL) — separate project; schedule independently.

---

## 5. Self-review checklist (per feature, before "done")

- [ ] New public symbols have multi-line `///` docs with an example.
- [ ] No new runtime dependency (`flutter pub deps --no-dev` unchanged).
- [ ] `flutter test` green; new tests live in the matching `test/` subdir and use `fake_async`/fakes/`ShardTester` as appropriate.
- [ ] `dart analyze` clean.
- [ ] `flutter pub publish --dry-run` shows no new warnings (git-dirty warning during dev is fine).
- [ ] `pubspec.yaml` minor-bumped; `CHANGELOG.md` entry added (New/Fix format).
- [ ] Confirmed additive: no signature change to existing public API; no new member on `StateStorage`/`CacheService`/`StateSerializer`/`ShardObserver`; no new `AsyncValue` subtype.
