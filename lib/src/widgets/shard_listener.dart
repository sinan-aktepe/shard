import 'package:flutter/material.dart';

import '../state_management/shard.dart';
import 'shard_provider.dart';

/// Interface implemented by listeners usable inside a [MultiShardListener].
///
/// Mirrors `SingleChildShardProvider`: a [ShardListener] can omit its `child`
/// and have it injected via [buildWithChild] when nested.
abstract class SingleChildShardListener {
  /// Builds this listener wrapping [child].
  Widget buildWithChild(Widget child);
}

/// A widget that invokes [listener] on a [Shard]'s state changes **without
/// rebuilding** — for side effects like navigation or showing a snackbar.
///
/// It is the listener-only counterpart to `ShardBuilder` (which always
/// rebuilds via its `builder`). The [child] is rendered as-is and never
/// rebuilt by this widget.
///
/// ## Basic Usage
///
/// ```dart
/// ShardListener<AuthShard, AuthState>(
///   listener: (context, prev, curr) {
///     if (curr.isLoggedIn && !prev.isLoggedIn) {
///       Navigator.of(context).pushReplacementNamed('/home');
///     }
///   },
///   child: const LoginForm(),
/// )
/// ```
///
/// ## Conditional Listening
///
/// ```dart
/// ShardListener<FormShard, FormState>(
///   listenWhen: (prev, curr) => curr.hasError && !prev.hasError,
///   listener: (context, prev, curr) {
///     ScaffoldMessenger.of(context).showSnackBar(
///       SnackBar(content: Text(curr.errorMessage)),
///     );
///   },
///   child: const MyForm(),
/// )
/// ```
///
/// See also:
/// - [MultiShardListener] for nesting several listeners
/// - `ShardBuilder` for the rebuilding counterpart
class ShardListener<T extends Shard<S>, S> extends StatefulWidget
    implements SingleChildShardListener {
  /// Optional direct reference to a shard instance.
  ///
  /// If not provided, the shard is obtained from `ShardProvider` in the tree.
  final T? shard;

  /// Side-effect callback invoked on state changes (not on first build).
  final void Function(BuildContext context, S previous, S current) listener;

  /// Optional condition for when to call [listener].
  ///
  /// If provided and it returns `false`, [listener] is not called.
  final bool Function(S previous, S current)? listenWhen;

  /// The widget below this listener. May be omitted when used inside a
  /// [MultiShardListener] (which injects it via [buildWithChild]).
  final Widget? child;

  /// Creates a [ShardListener].
  const ShardListener({
    super.key,
    this.shard,
    required this.listener,
    this.listenWhen,
    this.child,
  });

  @override
  Widget buildWithChild(Widget child) => ShardListener<T, S>(
    key: key,
    shard: shard,
    listener: listener,
    listenWhen: listenWhen,
    child: child,
  );

  @override
  State<ShardListener<T, S>> createState() => _ShardListenerState<T, S>();
}

class _ShardListenerState<T extends Shard<S>, S>
    extends State<ShardListener<T, S>> {
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
    if (widget.shard != null) {
      _initializeShard(widget.shard!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // When the shard comes from context, bind on first build and rebind if
    // the provider above starts supplying a different instance.
    if (widget.shard != null) return;
    final provided = ShardProvider.of<T>(context);
    if (!identical(provided, _shard)) {
      _shard?.removeListener(_onStateChanged);
      _initializeShard(provided);
    }
  }

  @override
  void didUpdateWidget(covariant ShardListener<T, S> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebind when a different shard instance is supplied via [shard].
    if (!identical(widget.shard, oldWidget.shard)) {
      _shard?.removeListener(_onStateChanged);
      _shard = null;
      _initializeShard(widget.shard ?? ShardProvider.of<T>(context));
    }
  }

  @override
  void dispose() {
    _shard?.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (_shard == null || !mounted) return;

    // _previousState is always assigned in _initializeShard before the
    // listener is attached, so the cast is safe even when S is nullable
    // (a null previous state is a legitimate value, not "uninitialized").
    final S previousState = _previousState as S;
    final S newState = _shard!.state;

    final shouldListen =
        widget.listenWhen == null ||
        widget.listenWhen!(previousState, newState);

    if (shouldListen) {
      widget.listener(context, previousState, newState);
    }

    _previousState = newState;
  }

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox.shrink();
}

/// Nests multiple [ShardListener]s around a single [child], analogous to
/// `MultiShardProvider`.
///
/// ```dart
/// MultiShardListener(
///   listeners: [
///     ShardListener<AuthShard, AuthState>(listener: _onAuth),
///     ShardListener<CartShard, CartState>(listener: _onCart),
///   ],
///   child: const HomePage(),
/// )
/// ```
///
/// Each entry may omit its own `child`; [MultiShardListener] injects it via
/// [SingleChildShardListener.buildWithChild]. The first entry is the outermost.
class MultiShardListener extends StatelessWidget {
  /// The listeners to nest, outermost first.
  final List<SingleChildShardListener> listeners;

  /// The widget below all the listeners.
  final Widget child;

  /// Creates a [MultiShardListener].
  const MultiShardListener({
    super.key,
    required this.listeners,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (listeners.isEmpty) return child;
    // Fold right: the last entry becomes innermost (closest to child).
    return listeners.reversed.fold<Widget>(
      child,
      (acc, entry) => entry.buildWithChild(acc),
    );
  }
}
