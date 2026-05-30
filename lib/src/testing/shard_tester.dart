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
  // ignore: prefer_final_fields
  List<_PendingWait<T>> _waiters = [];
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
    // Future tasks (7 and 8) will use _waiters to wake up pending waitFor calls.
  }
}

/// Internal wait record; populated by `waitForNext` / `waitFor` in later tasks.
class _PendingWait<T> {
  _PendingWait(this.completer, {this.predicate});
  final Completer<T> completer;
  final bool Function(T)? predicate;
}
