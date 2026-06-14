import 'shard.dart';

/// Base class for observing [Shard] instances.
///
/// Override the methods to receive notifications about state changes
/// and errors across all Shard instances in your application.
///
/// To use a global observer, set it via [Shard.observer]:
/// ```dart
/// Shard.observer = MyShardObserver();
/// ```
abstract class ShardObserver {
  /// Creates a [ShardObserver].
  ///
  /// `const` so subclasses can provide const constructors.
  const ShardObserver();

  /// Called whenever a [Shard]'s state changes.
  ///
  /// [shard] is the shard instance that changed.
  /// [previousState] is the state before the change.
  /// [currentState] is the state after the change.
  void onChange<T>(Shard<T> shard, T previousState, T currentState) {}

  /// Called when an error is reported via [Shard.addError].
  ///
  /// [shard] is the shard instance that reported the error.
  /// [error] is the error object.
  /// [stackTrace] is the optional stack trace associated with the error.
  void onError<T>(Shard<T> shard, Object error, StackTrace? stackTrace) {}
}
