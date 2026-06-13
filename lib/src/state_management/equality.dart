import 'shard.dart';

/// Deep structural equality for values commonly held in [Shard] state.
///
/// Dart's `==` on [List], [Set], and [Map] is identity-based, so rebuilding a
/// collection with the same contents produces an "unequal" value and triggers a
/// rebuild that changed nothing. [deepEquals] compares collections by their
/// elements (recursively) and falls back to `==` for everything else.
///
/// It handles:
/// - [List] / [Iterable] — same length and pairwise-equal elements, in order.
/// - [Set] — same length and every element has a deep-equal match (order
///   independent).
/// - [Map] — same length, same keys, and deep-equal values.
/// - Anything else — compared with `==`.
///
/// Nested collections are compared recursively, so `{'ids': [1, 2]}` equals a
/// freshly built `{'ids': [1, 2]}`.
///
/// Use it directly in a `buildWhen`/`listenWhen` predicate, inside a
/// `ShardSelector`, or via [DeepEqualityMixin] to make [Shard.emit] skip
/// no-op rebuilds for collection state.
///
/// ```dart
/// deepEquals([1, 2, 3], [1, 2, 3]); // true
/// deepEquals({'a': 1}, {'a': 2});   // false
/// ```
bool deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;

  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!deepEquals(a[i], b[i])) return false;
    }
    return true;
  }

  if (a is Set && b is Set) {
    if (a.length != b.length) return false;
    for (final element in a) {
      if (!b.any((other) => deepEquals(element, other))) return false;
    }
    return true;
  }

  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!deepEquals(a[key], b[key])) return false;
    }
    return true;
  }

  if (a is Iterable && b is Iterable) {
    final ai = a.iterator;
    final bi = b.iterator;
    while (true) {
      final aHasNext = ai.moveNext();
      final bHasNext = bi.moveNext();
      if (aHasNext != bHasNext) return false;
      if (!aHasNext) return true;
      if (!deepEquals(ai.current, bi.current)) return false;
    }
  }

  return a == b;
}

/// A [Shard] mixin that compares state with [deepEquals] instead of `==`.
///
/// Mix this in when your state is (or contains) a [List], [Set], or [Map] that
/// you rebuild immutably. Without it, `emit([...state, item])` followed by an
/// emit of an identical-content list would still notify listeners, because the
/// two list instances are not `==`. With it, [emit] skips the notification when
/// the contents match.
///
/// ```dart
/// class TagsShard extends Shard<List<String>>
///     with DeepEqualityMixin<List<String>> {
///   TagsShard() : super(const []);
///   void setTags(List<String> tags) => emit(tags);
/// }
/// ```
///
/// You can still override [stateEquals] for fully custom logic; this mixin just
/// provides a sensible collection-aware default.
mixin DeepEqualityMixin<T> on Shard<T> {
  @override
  bool stateEquals(T a, T b) => deepEquals(a, b);
}
