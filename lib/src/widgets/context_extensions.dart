import 'package:flutter/material.dart';
import '../state_management/shard.dart';
import 'shard_provider.dart';

/// Extension methods on [BuildContext] for accessing shards.
///
/// These extensions provide convenient access to shard instances
/// from the widget tree without having to call [ShardProvider.of]
/// directly.
///
/// ## read vs watch
///
/// - [read] - Gets the shard without subscribing to changes.
///   Use in callbacks, event handlers, and `initState`.
///
/// - [watch] - Gets the shard and subscribes to changes.
///   Use in `build` methods when you need to react to state changes.
///
/// ## Example
///
/// ```dart
/// class MyWidget extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     // Use watch in build methods to react to changes
///     final shard = context.watch<CounterShard>();
///
///     return Column(
///       children: [
///         Text('Count: ${shard.state}'),
///         ElevatedButton(
///           // Use read in callbacks to avoid unnecessary rebuilds
///           onPressed: () => context.read<CounterShard>().increment(),
///           child: Text('Increment'),
///         ),
///       ],
///     );
///   }
/// }
/// ```
///
/// ## When to Use Each
///
/// | Scenario | Method |
/// |----------|--------|
/// | Displaying state in UI | `watch` |
/// | Calling shard methods | `read` |
/// | In `initState` | `read` |
/// | In button callbacks | `read` |
/// | In `build` for derived data | `watch` |
///
/// See also:
/// - [ShardProvider] for providing shards to the widget tree
/// - [ShardBuilder] for more control over rebuilds
extension ContextExtensions on BuildContext {
  /// Obtains a [Shard] without subscribing to changes.
  ///
  /// Use this method when you need to access the shard but don't
  /// want the widget to rebuild when the shard's state changes.
  /// This is typically used in callbacks and event handlers.
  ///
  /// ```dart
  /// ElevatedButton(
  ///   onPressed: () {
  ///     context.read<CounterShard>().increment();
  ///   },
  ///   child: Text('Increment'),
  /// )
  /// ```
  ///
  /// Throws an assertion error if no [ShardProvider] of type [T] is found.
  T read<T extends Shard<dynamic>>() {
    return ShardProvider.of<T>(this, listen: false);
  }

  /// Obtains a [Shard] and subscribes to changes.
  ///
  /// Use this method when you need to access the shard and want
  /// the widget to rebuild when the shard's state changes.
  /// This is typically used in `build` methods.
  ///
  /// ```dart
  /// @override
  /// Widget build(BuildContext context) {
  ///   final shard = context.watch<CounterShard>();
  ///   return Text('Count: ${shard.state}');
  /// }
  /// ```
  ///
  /// **Note:** Using `watch` outside of `build` methods may cause
  /// unnecessary rebuilds or errors. Use [read] in callbacks instead.
  ///
  /// Throws an assertion error if no [ShardProvider] of type [T] is found.
  T watch<T extends Shard<dynamic>>() {
    return ShardProvider.of<T>(this, listen: true);
  }
}
