import 'package:flutter/material.dart';
import 'shard_provider.dart';

/// A widget that provides multiple [Shard] instances to its descendants.
///
/// [MultiShardProvider] simplifies providing multiple shards by accepting
/// a list of [SingleChildShardProvider] instances (typically `ShardProvider<T>`)
/// and automatically nesting them.
///
/// This is type-safe and keeps each shard's generic type intact so that
/// `context.read<MyShard>()` and `ShardProvider.of<MyShard>(context)` work
/// reliably.
///
/// ## Basic Usage
///
/// ```dart
/// MultiShardProvider(
///   providers: [
///     ShardProvider<CounterShard>(create: () => CounterShard()),
///     ShardProvider<AuthShard>(create: () => AuthShard()),
///     ShardProvider<SettingsShard>(create: () => SettingsShard()),
///   ],
///   child: MyApp(),
/// )
/// ```
///
/// This is equivalent to:
///
/// ```dart
/// ShardProvider<CounterShard>(
///   create: () => CounterShard(),
///   child: ShardProvider<AuthShard>(
///     create: () => AuthShard(),
///     child: ShardProvider<SettingsShard>(
///       create: () => SettingsShard(),
///       child: MyApp(),
///     ),
///   ),
/// )
/// ```
///
/// ## Mixing Create and Value Constructors
///
/// You can mix both entry types:
///
/// ```dart
/// final existingShard = CounterShard();
///
/// MultiShardProvider(
///   providers: [
///     ShardProvider<CounterShard>.value(value: existingShard),
///     ShardProvider<AuthShard>(create: () => AuthShard()),
///   ],
///   child: MyApp(),
/// )
/// ```
///
/// ## Accessing Shards
///
/// All shards provided by [MultiShardProvider] can be accessed using
/// the same methods as individual [ShardProvider] instances:
///
/// ```dart
/// // Read without subscribing to changes
/// final counterShard = context.read<CounterShard>();
/// final authShard = context.read<AuthShard>();
///
/// // Or using ShardProvider.of
/// final counterShard = ShardProvider.of<CounterShard>(context);
/// final authShard = ShardProvider.of<AuthShard>(context);
/// ```
///
/// For displaying state in the UI, use [ShardBuilder] or [ShardSelector]
/// instead, which provide better performance and more explicit control
/// over when widgets rebuild.
///
/// ## Lifecycle Management
///
/// Each [ShardProvider] in the list maintains its own lifecycle:
/// - Shards created with `create` are automatically disposed when
///   [MultiShardProvider] is removed from the widget tree
/// - Shards provided with `value` are NOT disposed automatically
///
/// ## Empty List
///
/// If an empty list is provided, [MultiShardProvider] simply returns
/// the child widget without any providers.
///
/// See also:
/// - [ShardProvider] for providing a single shard
/// - [ShardBuilder] for building widgets that react to state changes
/// - [ShardSelector] for selecting specific parts of state
/// - [ContextExtensions] for `context.read`
class MultiShardProvider extends StatelessWidget {
  /// List of provider entries to nest.
  ///
  /// The providers are nested in order, with the first provider being
  /// the outermost and the last provider being the innermost (closest
  /// to the child).
  final List<SingleChildShardProvider> providers;

  /// The widget below this widget in the tree.
  final Widget child;

  /// Creates a [MultiShardProvider] that nests multiple [ShardProvider]
  /// instances.
  ///
  /// The [providers] list should contain [SingleChildShardProvider] instances.
  /// They will be automatically nested, with the first provider being
  /// the outermost.
  ///
  /// ```dart
  /// MultiShardProvider(
  ///   providers: [
  ///     ShardProvider<CounterShard>(create: () => CounterShard()),
  ///     ShardProvider<AuthShard>(create: () => AuthShard()),
  ///   ],
  ///   child: MyApp(),
  /// )
  /// ```
  const MultiShardProvider({
    super.key,
    required this.providers,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) {
      return child;
    }

    // Fold right: last provider becomes innermost (closest to child).
    return providers.reversed.fold<Widget>(
      child,
      (acc, entry) => entry.buildWithChild(acc),
    );
  }
}
