import 'dart:async';
import 'package:flutter/material.dart';

class _DebounceTimer {
  Timer? _timer;
  final Duration duration;
  final VoidCallback callback;

  _DebounceTimer(this.duration, this.callback);

  void call() {
    _timer?.cancel();
    _timer = Timer(duration, callback);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}

/// A mixin that provides debounce functionality for [Shard].
///
/// Debouncing delays the execution of a callback until after a period of
/// inactivity. This is useful for scenarios like search input where you
/// want to wait until the user stops typing before making an API call.
///
/// This mixin is automatically included in [Shard].
///
/// ## Example
///
/// ```dart
/// class SearchShard extends Shard<SearchState> {
///   SearchShard() : super(SearchState.initial());
///
///   void updateQuery(String query) {
///     // Update UI immediately
///     emit(state.copyWith(query: query));
///
///     // Debounce the API call
///     debounce('search', () {
///       performSearch(query);
///     }, duration: Duration(milliseconds: 500));
///   }
///
///   Future<void> performSearch(String query) async {
///     emit(state.copyWith(isLoading: true));
///     final results = await api.search(query);
///     emit(state.copyWith(isLoading: false, results: results));
///   }
/// }
/// ```
mixin DebounceMixin {
  final Map<String, _DebounceTimer> _debounceTimers = {};

  /// Debounces a callback with the given [key].
  ///
  /// If called multiple times with the same [key], only the last call's
  /// [callback] will be executed after [duration] of inactivity.
  ///
  /// - [key] - Unique identifier for this debounce operation
  /// - [callback] - Function to execute after the delay
  /// - [duration] - Time to wait before executing (default: 300ms)
  ///
  /// ```dart
  /// debounce('search', () {
  ///   performSearch(query);
  /// }, duration: Duration(milliseconds: 500));
  /// ```
  @protected
  void debounce(
    String key,
    VoidCallback callback, {
    Duration duration = const Duration(milliseconds: 300),
  }) {
    // Cancel existing timer if it exists
    _debounceTimers[key]?.cancel();

    // Create new timer with the latest callback
    final newTimer = _DebounceTimer(duration, callback);
    _debounceTimers[key] = newTimer;
    newTimer.call();
  }

  /// Cancels a specific debounce operation by [key].
  ///
  /// If no debounce operation exists for the given [key], this method
  /// does nothing.
  ///
  /// ```dart
  /// cancelDebounce('search');
  /// ```
  @protected
  void cancelDebounce(String key) {
    _debounceTimers[key]?.cancel();
    _debounceTimers.remove(key);
  }

  /// Cancels all debounce operations.
  ///
  /// This is automatically called when the [Shard] is disposed.
  ///
  /// ```dart
  /// @override
  /// void dispose() {
  ///   cancelAllDebounce();
  ///   super.dispose();
  /// }
  /// ```
  @protected
  void cancelAllDebounce() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
  }
}

class _ThrottleTimer {
  Timer? _timer;
  final Duration duration;
  bool _isThrottled = false;

  _ThrottleTimer(this.duration);

  /// Whether an execution window is currently active.
  bool get isThrottled => _isThrottled;

  bool call(VoidCallback callback) {
    if (!_isThrottled) {
      // First call executes immediately (leading throttle)
      callback();
      _isThrottled = true;
      _timer = Timer(duration, () {
        _isThrottled = false;
        _timer = null;
      });
      return true;
    }
    // Subsequent calls are ignored while throttled
    return false;
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _isThrottled = false;
  }
}

/// A mixin that provides throttle functionality for [Shard].
///
/// Throttling limits the execution of a callback to once per time period.
/// This is useful for scenarios like scroll handlers or button clicks
/// where you want to limit how often an operation can be performed.
///
/// This mixin is automatically included in [Shard].
///
/// ## Example
///
/// ```dart
/// class InfiniteScrollShard extends Shard<ScrollState> {
///   InfiniteScrollShard() : super(ScrollState.initial());
///
///   void onScroll() {
///     // Throttle loadMore to once per second
///     final wasExecuted = throttle('loadMore', () {
///       loadMoreItems();
///     }, duration: Duration(seconds: 1));
///
///     if (!wasExecuted) {
///       print('Throttled - please wait');
///     }
///   }
///
///   Future<void> loadMoreItems() async {
///     emit(state.copyWith(isLoadingMore: true));
///     final items = await api.fetchMore();
///     emit(state.copyWith(
///       isLoadingMore: false,
///       items: [...state.items, ...items],
///     ));
///   }
/// }
/// ```
mixin ThrottleMixin {
  final Map<String, _ThrottleTimer> _throttleTimers = {};

  /// Throttles a callback with the given [key].
  ///
  /// The first call executes immediately (leading throttle). Subsequent
  /// calls within [duration] are ignored. Returns `true` if the callback
  /// was executed, `false` if it was throttled.
  ///
  /// - [key] - Unique identifier for this throttle operation
  /// - [callback] - Function to execute
  /// - [duration] - Minimum time between executions (default: 300ms).
  ///   Passing a different duration for an existing [key] takes effect the
  ///   next time the key is idle; an active window keeps its original
  ///   duration.
  ///
  /// ```dart
  /// final executed = throttle('loadMore', () {
  ///   loadMoreItems();
  /// }, duration: Duration(seconds: 1));
  ///
  /// if (!executed) {
  ///   showMessage('Please wait...');
  /// }
  /// ```
  @protected
  bool throttle(
    String key,
    VoidCallback callback, {
    Duration duration = const Duration(milliseconds: 300),
  }) {
    // Get or create the throttle timer for this key. When the key is idle
    // (not inside an active window) and a different duration is requested,
    // recreate the timer so the new duration takes effect instead of being
    // silently ignored. An active window keeps its original duration.
    var timer = _throttleTimers[key];
    if (timer == null || (!timer.isThrottled && timer.duration != duration)) {
      timer?.cancel();
      timer = _ThrottleTimer(duration);
      _throttleTimers[key] = timer;
    }

    // Call and return whether it was executed
    return timer.call(callback);
  }

  /// Cancels a specific throttle operation by [key].
  ///
  /// This resets the throttle, allowing the next call to execute immediately.
  ///
  /// ```dart
  /// cancelThrottle('loadMore');
  /// ```
  @protected
  void cancelThrottle(String key) {
    _throttleTimers[key]?.cancel();
    _throttleTimers.remove(key);
  }

  /// Cancels all throttle operations.
  ///
  /// This is automatically called when the [Shard] is disposed.
  ///
  /// ```dart
  /// @override
  /// void dispose() {
  ///   cancelAllThrottle();
  ///   super.dispose();
  /// }
  /// ```
  @protected
  void cancelAllThrottle() {
    for (final timer in _throttleTimers.values) {
      timer.cancel();
    }
    _throttleTimers.clear();
  }
}
