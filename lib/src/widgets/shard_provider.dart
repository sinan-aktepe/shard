import 'package:flutter/material.dart';
import 'package:shard/src/src.dart';

/// Internal InheritedWidget used to provide shard instances to the widget tree.
class _ShardProvider<T extends Shard<dynamic>> extends InheritedWidget {
  final T shard;

  const _ShardProvider({super.key, required this.shard, required super.child});

  static T of<T extends Shard<dynamic>>(
    BuildContext context, {
    bool listen = true,
  }) {
    if (listen) {
      final provider = context
          .dependOnInheritedWidgetOfExactType<_ShardProvider<T>>();
      assert(provider != null, 'No ShardProvider<$T> found in context');
      return provider!.shard;
    } else {
      final element = context
          .getElementForInheritedWidgetOfExactType<_ShardProvider<T>>();
      assert(element != null, 'No ShardProvider<$T> found in context');
      final provider = element!.widget as _ShardProvider<T>;
      return provider.shard;
    }
  }

  @override
  bool updateShouldNotify(_ShardProvider<T> oldWidget) => false;
}

/// A widget that provides a [Shard] instance to its descendants.
///
/// [ShardProvider] makes a shard instance available to all widgets below
/// it in the widget tree. Descendants can access the shard using
/// [ShardProvider.of] or [context.read].
///
/// ## Creating a New Shard
///
/// Use the default constructor with [create] to create a new shard:
///
/// ```dart
/// ShardProvider<CounterShard>(
///   create: () => CounterShard(),
///   child: MyApp(),
/// )
/// ```
///
/// The shard will be disposed automatically when the provider is removed
/// from the widget tree.
///
/// ## Providing an Existing Shard
///
/// Use [ShardProvider.value] to provide an existing shard instance:
///
/// ```dart
/// final myShard = CounterShard();
///
/// ShardProvider.value(
///   value: myShard,
///   child: MyApp(),
/// )
/// ```
///
/// When using [ShardProvider.value], the shard is NOT disposed automatically.
/// You are responsible for disposing it when appropriate.
///
/// ## Accessing the Shard
///
/// From descendants, access the shard using:
///
/// ```dart
/// // Read without subscribing to changes (for callbacks)
/// final shard = context.read<CounterShard>();
///
/// // Or using ShardProvider.of
/// final shard = ShardProvider.of<CounterShard>(context);
/// ```
///
/// For displaying state in the UI, use [ShardBuilder] or [ShardSelector]
/// instead, which provide better performance and more explicit control
/// over when widgets rebuild.
///
/// ## Nested Providers
///
/// You can nest multiple providers:
///
/// ```dart
/// ShardProvider<AuthShard>(
///   create: () => AuthShard(),
///   child: ShardProvider<SettingsShard>(
///     create: () => SettingsShard(),
///     child: MyApp(),
///   ),
/// )
/// ```
///
/// See also:
/// - [ShardBuilder] for building widgets that react to state changes
/// - [ShardSelector] for selecting specific parts of state
/// - [ContextExtensions] for `context.read`
class ShardProvider<T extends Shard<dynamic>> extends StatefulWidget {
  /// Function to create a new shard instance.
  ///
  /// Only used when creating a new shard (default constructor).
  /// The function is called once when the widget is first built.
  final T Function()? create;

  /// Existing shard instance to provide.
  ///
  /// Only used when providing an existing shard ([ShardProvider.value]).
  /// The shard will NOT be disposed when the provider is removed.
  final T? value;

  /// The widget below this widget in the tree.
  final Widget child;

  /// Creates a [ShardProvider] that creates a new shard instance.
  ///
  /// The [create] function is called once to create the shard.
  /// The shard's [Shard.onInit] is called after creation.
  /// The shard will be disposed when this widget is disposed.
  ///
  /// ```dart
  /// ShardProvider<CounterShard>(
  ///   create: () => CounterShard(),
  ///   child: MyApp(),
  /// )
  /// ```
  const ShardProvider({super.key, required this.create, required this.child})
    : value = null;

  /// Creates a [ShardProvider] that provides an existing shard instance.
  ///
  /// The [value] shard will be provided to descendants, but will NOT be
  /// disposed when this widget is disposed. You are responsible for
  /// managing the shard's lifecycle.
  ///
  /// ```dart
  /// final myShard = CounterShard();
  ///
  /// ShardProvider.value(
  ///   value: myShard,
  ///   child: MyApp(),
  /// )
  /// ```
  const ShardProvider.value({
    super.key,
    required this.value,
    required this.child,
  }) : create = null;

  @override
  State<ShardProvider<T>> createState() => _ShardProviderState<T>();

  /// Obtains the nearest [ShardProvider] ancestor of the given context.
  ///
  /// If [listen] is true (default), the widget will rebuild when the shard
  /// notifies its listeners. If false, the widget will not rebuild.
  ///
  /// Throws an assertion error if no [ShardProvider] of type [T] is found.
  ///
  /// ```dart
  /// // Get shard and listen for changes
  /// final shard = ShardProvider.of<CounterShard>(context);
  ///
  /// // Get shard without listening (for callbacks)
  /// final shard = ShardProvider.of<CounterShard>(context, listen: false);
  /// ```
  static T of<T extends Shard<dynamic>>(
    BuildContext context, {
    bool listen = true,
  }) {
    return _ShardProvider.of<T>(context, listen: listen);
  }
}

class _ShardProviderState<T extends Shard<dynamic>>
    extends State<ShardProvider<T>> {
  late final T _shard;
  late final bool _shouldDispose;

  @override
  void initState() {
    super.initState();

    if (widget.value != null) {
      // Using existing shard - don't dispose it
      _shard = widget.value!;
      _shouldDispose = false;
    } else if (widget.create != null) {
      // Creating new shard - will dispose it
      _shard = widget.create!();
      _shouldDispose = true;
      _shard.onInit();
    } else {
      throw ArgumentError('Either create or value must be provided');
    }
  }

  @override
  void dispose() {
    // Only dispose if we created it (not if it was provided via value)
    if (_shouldDispose) {
      _shard.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShardProvider<T>(shard: _shard, child: widget.child);
  }
}
