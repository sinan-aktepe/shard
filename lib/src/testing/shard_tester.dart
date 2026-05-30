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

/// Internal wait record; populated by `waitForNext` / `waitFor` in later tasks.
class _PendingWait<T> {
  _PendingWait(this.completer, {this.predicate});
  final Completer<T> completer;
  final bool Function(T)? predicate;
}
