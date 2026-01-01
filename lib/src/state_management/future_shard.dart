import 'package:flutter/material.dart';

import 'async_value.dart';
import 'shard.dart';

/// A [Shard] that manages asynchronous state from a [Future].
///
/// [FutureShard] automatically executes [build] when initialized and
/// manages the loading, data, and error states through [AsyncValue].
///
/// ## Creating a FutureShard
///
/// ```dart
/// class UserShard extends FutureShard<User> {
///   final String userId;
///   final UserRepository repository;
///
///   UserShard({required this.userId, required this.repository});
///
///   @override
///   Future<User> build() async {
///     return await repository.getUser(userId);
///   }
/// }
/// ```
///
/// ## Usage in UI
///
/// ```dart
/// AsyncShardBuilder<UserShard, User>(
///   onLoading: (context) => CircularProgressIndicator(),
///   onData: (context, user) => Text('Hello, ${user.name}'),
///   onError: (context, error, stackTrace) => Text('Error: $error'),
/// )
/// ```
///
/// ## Refreshing Data
///
/// Call [refresh] to re-execute the [build] method:
///
/// ```dart
/// final userShard = context.shard<UserShard>();
/// userShard.refresh();
/// ```
///
/// See also:
/// - [StreamShard] for Stream-based async state management
/// - [AsyncValue] for the state representation
/// - [AsyncShardBuilder] for building UI based on async state
abstract class FutureShard<T> extends Shard<AsyncValue<T>> {
  bool _isRefreshing = false;

  /// Creates a [FutureShard] with an initial loading state.
  FutureShard() : super(AsyncLoading<T>());

  /// Builds and returns the [Future] that produces the data.
  ///
  /// This method is called automatically when the shard is initialized
  /// and when [refresh] is called.
  ///
  /// Override this method to define how data should be fetched:
  ///
  /// ```dart
  /// @override
  /// Future<User> build() async {
  ///   return await api.fetchUser(userId);
  /// }
  /// ```
  @protected
  Future<T> build();

  /// Re-executes [build] to refresh the data.
  ///
  /// The state transitions to [AsyncLoading] (retaining previous data)
  /// before executing [build] again.
  ///
  /// If a refresh is already in progress, this method does nothing.
  ///
  /// ```dart
  /// void onRefreshPressed() {
  ///   myShard.refresh();
  /// }
  /// ```
  void refresh() {
    if (_isRefreshing || isDisposed) return;
    _isRefreshing = true;
    emit(AsyncLoading<T>(previousData: state.dataOrNull));
    _fetch();
  }

  /// Called when the shard is initialized.
  ///
  /// Automatically starts fetching data by calling [build].
  @override
  @mustCallSuper
  void onInit() {
    super.onInit();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final result = await build();
      if (isDisposed) return;
      emit(AsyncData<T>(result));
    } catch (e, st) {
      if (isDisposed) return;
      addError(e, st);
      emit(AsyncError<T>(e, st, state.dataOrNull));
    } finally {
      _isRefreshing = false;
    }
  }
}

