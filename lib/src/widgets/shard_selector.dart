import 'package:flutter/material.dart';
import '../state_management/shard.dart';
import 'shard_provider.dart';

/// A widget that rebuilds only when a selected value from state changes.
///
/// [ShardSelector] is an optimization over [ShardBuilder] when you only
/// need to react to a specific part of the state. It uses a [selector]
/// function to extract the relevant value and only rebuilds when that
/// value changes.
///
/// ## Basic Usage
///
/// ```dart
/// ShardSelector<UserShard, UserState, String>(
///   selector: (state) => state.name,
///   builder: (context, name) {
///     return Text('Hello, $name');
///   },
/// )
/// ```
///
/// ## Performance Optimization
///
/// Use [ShardSelector] when you have a widget that only depends on
/// a small part of a larger state object:
///
/// ```dart
/// // This only rebuilds when the cart count changes,
/// // not when other parts of the shop state change
/// ShardSelector<ShopShard, ShopState, int>(
///   selector: (state) => state.cartItems.length,
///   builder: (context, count) {
///     return Badge(
///       label: Text('$count'),
///       child: Icon(Icons.shopping_cart),
///     );
///   },
/// )
/// ```
///
/// ## Complex Selectors
///
/// You can compute derived values in the selector:
///
/// ```dart
/// ShardSelector<CartShard, CartState, double>(
///   selector: (state) => state.items.fold(
///     0.0,
///     (sum, item) => sum + item.price * item.quantity,
///   ),
///   builder: (context, total) {
///     return Text('Total: \$${total.toStringAsFixed(2)}');
///   },
/// )
/// ```
///
/// ## Direct Shard Reference
///
/// Optionally provide a [shard] directly instead of using context:
///
/// ```dart
/// final myShard = CounterShard();
///
/// ShardSelector<CounterShard, int, bool>(
///   shard: myShard,
///   selector: (count) => count > 10,
///   builder: (context, isAboveTen) {
///     return Text(isAboveTen ? 'High!' : 'Low');
///   },
/// )
/// ```
///
/// ## Note on Equality
///
/// The selector's return value is compared using `==` to determine
/// if a rebuild is needed. For complex objects, ensure they implement
/// `==` correctly or use immutable data structures.
///
/// See also:
/// - [ShardBuilder] for rebuilding on any state change
/// - [ShardProvider] for providing shards to the widget tree
class ShardSelector<T extends Shard<S>, S, R> extends StatefulWidget {
  /// Selects a value from the state.
  ///
  /// This function is called whenever the state changes. The widget
  /// only rebuilds if the selected value changes.
  final R Function(S state) selector;

  /// Builds the widget tree based on the selected value.
  ///
  /// This function is called whenever the selected value changes.
  final Widget Function(BuildContext context, R value) builder;

  /// Optional direct reference to a shard instance.
  ///
  /// If not provided, the shard will be obtained from [ShardProvider]
  /// in the widget tree.
  final T? shard;

  /// Creates a [ShardSelector].
  ///
  /// Both [selector] and [builder] are required.
  const ShardSelector({
    super.key,
    required this.selector,
    required this.builder,
    this.shard,
  });

  @override
  State<ShardSelector<T, S, R>> createState() =>
      _ShardSelectorState<T, S, R>();
}

class _ShardSelectorState<T extends Shard<S>, S, R>
    extends State<ShardSelector<T, S, R>> {
  T? _shard;
  R? _value;

  void _initializeShard(T shard) {
    _shard = shard;
    final S state = shard.state;
    _value = widget.selector(state);
    _shard!.addListener(_onStateChanged);
  }

  @override
  void initState() {
    super.initState();
    // If shard is provided directly, we can use it immediately
    if (widget.shard != null) {
      _initializeShard(widget.shard!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get shard from context if not provided directly
    if (_shard == null) {
      _initializeShard(ShardProvider.of<T>(context));
    }
  }

  @override
  void dispose() {
    _shard?.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (_shard == null) return;
    final S state = _shard!.state;
    final newValue = widget.selector(state);
    if (_value != newValue) {
      setState(() => _value = newValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    final shard = _shard;
    if (value == null || shard == null) {
      // Return empty container while initializing
      return const SizedBox.shrink();
    }
    return widget.builder(context, value);
  }
}
