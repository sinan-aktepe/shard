import 'package:flutter/material.dart';
import '../state_management/shard.dart';
import 'shard_provider.dart';

/// A widget that rebuilds when the state of a [Shard] changes.
///
/// [ShardBuilder] listens to a shard and calls [builder] whenever the
/// state changes. It provides fine-grained control over when to rebuild
/// and when to trigger side effects.
///
/// ## Basic Usage
///
/// ```dart
/// ShardBuilder<CounterShard, int>(
///   builder: (context, count) {
///     return Text('Count: $count');
///   },
/// )
/// ```
///
/// ## With Listener
///
/// Use [listener] to perform side effects (like navigation or showing
/// snackbars) when state changes:
///
/// ```dart
/// ShardBuilder<AuthShard, AuthState>(
///   listener: (prev, curr) {
///     if (curr.isLoggedIn && !prev.isLoggedIn) {
///       Navigator.pushReplacementNamed(context, '/home');
///     }
///   },
///   builder: (context, state) {
///     return LoginForm(isLoading: state.isLoading);
///   },
/// )
/// ```
///
/// ## Conditional Rebuilding
///
/// Use [buildWhen] to control when the widget should rebuild:
///
/// ```dart
/// ShardBuilder<UserShard, UserState>(
///   buildWhen: (prev, curr) => prev.name != curr.name,
///   builder: (context, state) {
///     return Text('Hello, ${state.name}');
///   },
/// )
/// ```
///
/// ## Conditional Listening
///
/// Use [listenWhen] to control when the listener should be called:
///
/// ```dart
/// ShardBuilder<FormShard, FormState>(
///   listenWhen: (prev, curr) => curr.hasError && !prev.hasError,
///   listener: (prev, curr) {
///     ScaffoldMessenger.of(context).showSnackBar(
///       SnackBar(content: Text(curr.errorMessage)),
///     );
///   },
///   builder: (context, state) => MyForm(state: state),
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
/// ShardBuilder<CounterShard, int>(
///   shard: myShard,
///   builder: (context, count) => Text('Count: $count'),
/// )
/// ```
///
/// See also:
/// - [ShardSelector] for selecting specific parts of state
/// - [ShardProvider] for providing shards to the widget tree
class ShardBuilder<T extends Shard<S>, S> extends StatefulWidget {
  /// Builds the widget tree based on the current state.
  ///
  /// This function is called whenever the state changes (subject to
  /// [buildWhen]) and should return a widget.
  final Widget Function(BuildContext context, S state) builder;

  /// Optional direct reference to a shard instance.
  ///
  /// If not provided, the shard will be obtained from [ShardProvider]
  /// in the widget tree.
  final T? shard;

  /// Optional callback for side effects when state changes.
  ///
  /// Unlike [builder], this is not called on the initial build.
  /// Use this for navigation, showing dialogs, etc.
  final void Function(S prev, S curr)? listener;

  /// Optional condition for when to call [listener].
  ///
  /// If provided and returns `false`, [listener] will not be called.
  /// If not provided, [listener] is called on every state change.
  final bool Function(S previous, S current)? listenWhen;

  /// Optional condition for when to rebuild the widget.
  ///
  /// If provided and returns `false`, the widget will not rebuild.
  /// If not provided, the widget rebuilds on every state change.
  final bool Function(S previous, S current)? buildWhen;

  /// Creates a [ShardBuilder].
  ///
  /// The [builder] parameter is required and defines how to build
  /// the widget tree based on the current state.
  const ShardBuilder({
    super.key,
    required this.builder,
    this.shard,
    this.listener,
    this.listenWhen,
    this.buildWhen,
  });

  @override
  State<ShardBuilder<T, S>> createState() => _ShardBuilderState<T, S>();
}

class _ShardBuilderState<T extends Shard<S>, S>
    extends State<ShardBuilder<T, S>> {
  T? _shard;
  S? _previousState;

  void _initializeShard(T shard) {
    _shard = shard;
    _previousState = shard.state;
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
    if (_shard == null || !mounted) return;

    // Extract new state from Shard
    final S newState = _shard!.state;

    // Check if we should listen (call onStateChanged)
    final shouldListen =
        widget.listenWhen == null ||
        (_previousState != null &&
            widget.listenWhen!(_previousState as S, newState));

    // Call onStateChanged callback if provided, we have a previous state, and shouldListen is true
    if (widget.listener != null && _previousState != null && shouldListen) {
      widget.listener!(_previousState as S, newState);
    }

    // Check if we should rebuild
    final shouldBuild =
        widget.buildWhen == null ||
        (_previousState != null &&
            widget.buildWhen!(_previousState as S, newState));

    // Update previous state for next change
    _previousState = newState;

    // Rebuild only if shouldBuild is true
    if (shouldBuild && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_shard == null) {
      // Return empty container while initializing
      return const SizedBox.shrink();
    }

    // Extract state from Shard
    final S state = _shard!.state;

    return widget.builder(context, state);
  }
}
