import 'package:flutter/material.dart';
import '../state_management/shard.dart';
import 'shard_provider.dart';

/// Extension methods on [BuildContext] for accessing shards.
///
/// These extensions provide convenient access to shard instances
/// from the widget tree without having to call [ShardProvider.of]
/// directly.
///
/// ## Using read
///
/// [read] gets the shard without subscribing to changes.
/// Use in callbacks, event handlers, and `initState`.
///
/// For displaying state in the UI, use [ShardBuilder] or [ShardSelector]
/// instead, which provide better performance and more explicit control
/// over when widgets rebuild.
///
/// ## Example
///
/// ```dart
/// class MyWidget extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return Column(
///       children: [
///         // Use ShardBuilder to display state
///         ShardBuilder<CounterShard, int>(
///           builder: (context, count) {
///             return Text('Count: $count');
///           },
///         ),
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
/// ## When to Use read
///
/// | Scenario | Method |
/// |----------|--------|
/// | Calling shard methods | `read` |
/// | In `initState` | `read` |
/// | In button callbacks | `read` |
/// | Displaying state in UI | [ShardBuilder] or [ShardSelector] |
///
/// See also:
/// - [ShardProvider] for providing shards to the widget tree
/// - [ShardBuilder] for building widgets that react to state changes
/// - [ShardSelector] for selecting specific parts of state
extension ContextExtensions on BuildContext {
  /// Obtains a [Shard] without subscribing to changes.
  ///
  /// Use this method when you need to access the shard but don't
  /// want the widget to rebuild when the shard's state changes.
  /// This is typically used in callbacks and event handlers.
  ///
  /// For displaying state in the UI, use [ShardBuilder] or [ShardSelector]
  /// instead, which provide better performance and more explicit control
  /// over when widgets rebuild.
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
}
