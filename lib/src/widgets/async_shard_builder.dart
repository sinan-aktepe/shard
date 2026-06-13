import 'package:flutter/material.dart';

import '../state_management/async_value.dart';
import '../state_management/shard.dart';
import 'shard_builder.dart';

/// A widget that builds UI based on the [AsyncValue] state of a [Shard].
///
/// [AsyncShardBuilder] simplifies building UI for async operations by
/// providing separate callbacks for loading, data, and error states.
///
/// ## Basic Usage
///
/// ```dart
/// AsyncShardBuilder<UserShard, User>(
///   onLoading: (context) => CircularProgressIndicator(),
///   onData: (context, user) => Text('Hello, ${user.name}'),
///   onError: (context, error, stackTrace) => Text('Error: $error'),
/// )
/// ```
///
/// ## With Default Loading/Error Widgets
///
/// If [onLoading] is not provided, a centered [CircularProgressIndicator] is shown.
/// If [onError] is not provided, a centered error text is shown.
///
/// ```dart
/// AsyncShardBuilder<UserShard, User>(
///   onData: (context, user) => Text('Hello, ${user.name}'),
/// )
/// ```
///
/// ## With Direct Shard Reference
///
/// ```dart
/// final userShard = UserShard();
///
/// AsyncShardBuilder<UserShard, User>(
///   shard: userShard,
///   onData: (context, user) => UserProfile(user: user),
/// )
/// ```
///
/// ## Showing Stale Data While Loading
///
/// The [onData] callback receives data even during refresh if previous
/// data exists. Use [showDataOnLoading] to control this behavior:
///
/// ```dart
/// AsyncShardBuilder<UserShard, User>(
///   showDataOnLoading: true, // Default
///   onLoading: (context) => LinearProgressIndicator(),
///   onData: (context, user) => UserCard(user: user),
/// )
/// ```
///
/// See also:
/// - [FutureShard] for Future-based async state management
/// - [StreamShard] for Stream-based async state management
/// - [AsyncValue] for the state representation
/// - [ShardBuilder] for non-async shard building
class AsyncShardBuilder<T extends Shard<AsyncValue<D>>, D>
    extends StatelessWidget {
  /// Optional direct reference to a shard instance.
  ///
  /// If not provided, the shard will be obtained from [ShardProvider]
  /// in the widget tree.
  final T? shard;

  /// Builder for the loading state.
  ///
  /// If not provided, defaults to a centered [CircularProgressIndicator].
  ///
  /// ```dart
  /// onLoading: (context) => Shimmer(),
  /// ```
  final Widget Function(BuildContext context)? onLoading;

  /// Builder for the data state.
  ///
  /// This is called when the async operation completes successfully.
  ///
  /// ```dart
  /// onData: (context, user) => Text('Hello, ${user.name}'),
  /// ```
  final Widget Function(BuildContext context, D data) onData;

  /// Builder for the error state.
  ///
  /// If not provided, defaults to a centered error text.
  ///
  /// ```dart
  /// onError: (context, error, stackTrace) => ErrorWidget(error: error),
  /// ```
  final Widget Function(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  )?
  onError;

  /// Whether to show [onData] when in loading state with previous data.
  ///
  /// When `true` (default), if a refresh is in progress and previous data
  /// exists, [onData] will be called with the previous data.
  ///
  /// Set to `false` to always show [onLoading] during any loading state.
  final bool showDataOnLoading;

  /// Creates an [AsyncShardBuilder].
  ///
  /// The [onData] parameter is required and defines how to build
  /// the widget when data is available.
  const AsyncShardBuilder({
    super.key,
    this.shard,
    this.onLoading,
    required this.onData,
    this.onError,
    this.showDataOnLoading = true,
  });

  @override
  Widget build(BuildContext context) {
    return ShardBuilder<T, AsyncValue<D>>(
      shard: shard,
      builder: (context, asyncValue) {
        return switch (asyncValue) {
          AsyncIdle<D>() => _buildLoading(context, null),
          AsyncLoading<D>(:final previousData) => _buildLoading(
            context,
            previousData,
          ),
          AsyncData<D>(:final data) => onData(context, data),
          AsyncError<D>(:final error, :final stackTrace, :final previousData) =>
            _buildError(context, error, stackTrace, previousData),
        };
      },
    );
  }

  Widget _buildLoading(BuildContext context, D? previousData) {
    // If we have previous data and showDataOnLoading is true, show the data
    if (showDataOnLoading && previousData != null) {
      return onData(context, previousData);
    }

    // Otherwise show the loading widget
    return onLoading?.call(context) ??
        const Center(child: CircularProgressIndicator());
  }

  Widget _buildError(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
    D? previousData,
  ) {
    // Show custom error widget if provided
    if (onError != null) {
      return onError!(context, error, stackTrace);
    }

    // Default error widget
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Error: $error',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
