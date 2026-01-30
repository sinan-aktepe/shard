import 'package:flutter/material.dart';
import 'debounce_throttle.dart';
import 'shard_observer.dart';

/// A generic state management class that holds typed state.
///
/// [Shard] extends [ChangeNotifier] and provides a clean API for managing
/// application state with built-in lifecycle management, debounce, and
/// throttle support via mixins.
///
/// ## Creating a Shard
///
/// ```dart
/// class CounterShard extends Shard<int> {
///   CounterShard() : super(0);
///
///   void increment() => emit(state + 1);
///   void decrement() => emit(state - 1);
///   void reset() => emit(0);
/// }
/// ```
///
/// ## State Updates
///
/// Use [emit] to update state and notify listeners:
///
/// ```dart
/// void updateValue(int newValue) {
///   emit(newValue);
/// }
/// ```
///
/// ## Lifecycle
///
/// - [onInit] - Called when the shard is created
/// - [dispose] - Called when the shard is disposed
///
/// ## Observer Methods
///
/// Override these methods to handle events locally:
///
/// - [onChange] - Called when state changes
/// - [onError] - Called when an error is reported via [addError]
///
/// ## Example with Complex State
///
/// ```dart
/// class UserShard extends Shard<UserState> {
///   UserShard() : super(UserState.initial());
///
///   Future<void> fetchUser(String id) async {
///     emit(state.copyWith(isLoading: true));
///     try {
///       final user = await api.getUser(id);
///       emit(state.copyWith(isLoading: false, user: user));
///     } catch (e, st) {
///       addError(e, st);
///       emit(state.copyWith(isLoading: false, error: e.toString()));
///     }
///   }
/// }
/// ```
///
/// See also:
/// - [ShardObserver] for global event observation
/// - [PersistentShard] for state persistence
/// - [DebounceMixin] and [ThrottleMixin] for rate limiting
abstract class Shard<T> extends ChangeNotifier
    with DebounceMixin, ThrottleMixin {
  bool _isDisposed = false;
  T _state;

  /// Global observer for all [Shard] instances.
  ///
  /// Set this to receive notifications about state changes, disposal,
  /// and errors across all Shard instances in your application.
  ///
  /// ```dart
  /// void main() {
  ///   Shard.observer = MyShardObserver();
  ///   runApp(MyApp());
  /// }
  /// ```
  ///
  /// See also: [ShardObserver]
  static ShardObserver? observer;

  /// Creates a new [Shard] with the given initial state.
  ///
  /// The [initialState] is the starting value for [state].
  Shard(T initialState) : _state = initialState;

  /// Returns whether this shard has been disposed.
  ///
  /// Once disposed, the shard should not be used and [emit] calls
  /// will be ignored.
  bool get isDisposed => _isDisposed;

  /// The current state of the shard.
  ///
  /// This is a read-only property. Use [emit] to update the state.
  T get state => _state;

  /// Internal method for setting state directly.
  ///
  /// This method is used internally by persistence mixins and should
  /// not be called directly in most cases. Use [emit] instead.
  ///
  /// Unlike [emit], this method is public to allow persistence mechanisms
  /// to restore state without going through the protected [emit] method.
  void setStateInternal(T newState) {
    if (_isDisposed) return;
    final previousState = _state;
    _state = newState;
    onChange(previousState, newState);
    notifyListeners();
  }

  /// Called when the shard is initialized.
  ///
  /// Override this method to perform initialization logic such as
  /// loading data or setting up subscriptions.
  ///
  /// This method is called automatically by [ShardProvider] after
  /// the shard is created.
  ///
  /// ```dart
  /// @override
  /// void onInit() {
  ///   super.onInit();
  ///   loadInitialData();
  /// }
  /// ```
  @mustCallSuper
  void onInit() {}

  /// Called whenever the state changes.
  ///
  /// Override this method to handle state changes in your Shard subclass.
  /// Always call `super.onChange(previousState, currentState)` to ensure
  /// the global [observer] is notified.
  ///
  /// ```dart
  /// @override
  /// void onChange(int previousState, int currentState) {
  ///   print('State changed: $previousState -> $currentState');
  ///   super.onChange(previousState, currentState);
  /// }
  /// ```
  @protected
  @mustCallSuper
  void onChange(T previousState, T currentState) {
    observer?.onChange<T>(this, previousState, currentState);
  }

  /// Called when an error is reported via [addError].
  ///
  /// Override this method to handle errors in your Shard subclass.
  /// Always call `super.onError(error, stackTrace)` to ensure
  /// the global [observer] is notified.
  ///
  /// ```dart
  /// @override
  /// void onError(Object error, StackTrace? stackTrace) {
  ///   print('Error occurred: $error');
  ///   super.onError(error, stackTrace);
  /// }
  /// ```
  @protected
  @mustCallSuper
  void onError(Object error, StackTrace? stackTrace) {
    observer?.onError<T>(this, error, stackTrace);
  }

  /// Reports an error without blocking the execution flow.
  ///
  /// Use this method to report errors that should be observed but
  /// shouldn't stop the current operation. This is useful for
  /// non-fatal errors that should be logged or reported to analytics.
  ///
  /// The error is passed to [onError] and then to the global [observer].
  ///
  /// ```dart
  /// void doSomething() {
  ///   try {
  ///     // risky operation
  ///   } catch (e, st) {
  ///     addError(e, st); // Reports error, doesn't block
  ///   }
  ///   emit(newState); // Continues normally
  /// }
  /// ```
  @protected
  void addError(Object error, [StackTrace? stackTrace]) {
    if (_isDisposed) return;
    onError(error, stackTrace);
  }

  /// Determines whether two state instances are equal.
  ///
  /// Override this method to provide custom equality logic for your state.
  /// By default, uses `==` operator.
  ///
  /// This is used by [emit] to skip unnecessary state updates when the
  /// new state is equal to the current state.
  ///
  /// ```dart
  /// @override
  /// bool stateEquals(MyState a, MyState b) {
  ///   return a.id == b.id && a.name == b.name;
  /// }
  /// ```
  @protected
  bool stateEquals(T a, T b) => a == b;

  /// Updates the state and notifies all listeners.
  ///
  /// This is the primary method for updating state. When called:
  /// 1. Checks if [newState] equals the current state using [stateEquals]
  /// 2. If equal, does nothing (skips unnecessary rebuilds)
  /// 3. If different, updates state, calls [onChange], and notifies listeners
  ///
  /// If the shard [isDisposed], this method does nothing.
  ///
  /// To force emit even when state is equal, use [emitForce].
  ///
  /// ```dart
  /// void increment() {
  ///   emit(state + 1);
  /// }
  /// ```
  @protected
  void emit(T newState) {
    if (_isDisposed) return;
    if (stateEquals(_state, newState)) return;
    final previousState = _state;
    _state = newState;
    onChange(previousState, newState);
    notifyListeners();
  }

  /// Updates the state and notifies all listeners, bypassing equality check.
  ///
  /// Unlike [emit], this method always updates the state and notifies
  /// listeners, even if [newState] equals the current state.
  ///
  /// Use this when you need to force a rebuild, such as when the state
  /// object is mutable and has been modified in place.
  ///
  /// ```dart
  /// void forceRefresh() {
  ///   emitForce(state); // Forces rebuild with same state
  /// }
  /// ```
  @protected
  void emitForce(T newState) {
    if (_isDisposed) return;
    final previousState = _state;
    _state = newState;
    onChange(previousState, newState);
    notifyListeners();
  }

  /// Disposes the shard and cleans up resources.
  ///
  /// Override this method to perform cleanup in your Shard subclass.
  /// Always call `super.dispose()` to ensure proper cleanup.
  ///
  /// This method:
  /// 1. Sets [isDisposed] to true
  /// 2. Cancels all debounce and throttle timers
  /// 3. Cleans up persistence if enabled
  /// 4. Calls `super.dispose()` to clean up [ChangeNotifier]
  ///
  /// After calling dispose, the shard should not be used.
  ///
  /// ```dart
  /// @override
  /// void dispose() {
  ///   _timer?.cancel();
  ///   super.dispose();
  /// }
  /// ```
  @override
  @mustCallSuper
  void dispose() {
    // Set flag to prevent race conditions
    _isDisposed = true;

    cancelAllDebounce();
    cancelAllThrottle();

    // Clean up persistence if StatePersistenceMixin is used
    disposePersistenceIfEnabled();

    super.dispose();
  }

  /// Internal hook for persistence cleanup.
  ///
  /// This method is overridden by [StatePersistenceMixin] when persistence
  /// is enabled to save state before disposal.
  @protected
  void disposePersistenceIfEnabled() {
    // Overridden by StatePersistenceMixin when persistence is enabled
  }
}
