import 'package:flutter/foundation.dart';

import 'shard.dart';

/// Creates a [Shard] whose value is derived from [sources] and recomputed
/// whenever any of them notifies.
///
/// This factory form is the recommended default: because [compute] is a
/// closure over already-constructed sources, it sidesteps the
/// constructor-ordering trap of the [ComputedShard] subclass form.
///
/// ```dart
/// final total = computedShard(
///   [cart],
///   () => cart.state.items.fold(0, (sum, i) => sum + i.price),
/// );
/// ```
Shard<T> computedShard<T>(List<Listenable> sources, T Function() compute) =>
    _InlineComputedShard<T>(sources, compute, compute());

/// A [Shard] that derives its state from one or more [Listenable] sources,
/// recomputing whenever any of them notifies.
///
/// Sources are any [Listenable] — other [Shard]s (which are [ChangeNotifier]s),
/// `ValueNotifier`s, `Animation`s, etc.
///
/// Prefer the [computedShard] function unless you need a named type to provide
/// via `ShardProvider`.
///
/// ```dart
/// class CartTotal extends ComputedShard<int> {
///   CartTotal(this.cart) : super([cart], 0);
///   final CartShard cart;
///
///   @override
///   int compute() => cart.state.items.fold(0, (sum, i) => sum + i.price);
/// }
/// ```
///
/// **Constructor-ordering caveat:** [compute] is invoked from this base
/// constructor's body, so any subclass field it reads must be set via an
/// initializing formal or the initializer list (not assigned later in the
/// subclass constructor body). The [computedShard] function form avoids this.
abstract class ComputedShard<T> extends Shard<T> {
  /// Creates a computed shard listening to [sources].
  ///
  /// [initial] is a throwaway value immediately overwritten by the first
  /// [compute]; pass any valid `T`. (Set [recomputeOnInit] to false only when
  /// [initial] is already the correct computed value — the [computedShard]
  /// factory does this to avoid computing twice.)
  ComputedShard(this._sources, T initial, {bool recomputeOnInit = true})
    : super(initial) {
    if (recomputeOnInit) _recompute();
    for (final source in _sources) {
      source.addListener(_recompute);
    }
  }

  final List<Listenable> _sources;

  /// Computes the derived value from the current source states.
  @protected
  T compute();

  void _recompute() => emit(compute());

  @override
  void dispose() {
    for (final source in _sources) {
      source.removeListener(_recompute);
    }
    super.dispose();
  }
}

class _InlineComputedShard<T> extends ComputedShard<T> {
  // [initial] is already `compute()` (eagerly evaluated by the factory), so
  // skip the constructor recompute to call `compute` exactly once at creation.
  _InlineComputedShard(List<Listenable> sources, this._computeFn, T initial)
    : super(sources, initial, recomputeOnInit: false);

  final T Function() _computeFn;

  @override
  T compute() => _computeFn();
}
