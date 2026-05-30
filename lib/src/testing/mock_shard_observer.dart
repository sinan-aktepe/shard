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
  const ObservedError(this.shard, this.error, [this.stackTrace]);

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
