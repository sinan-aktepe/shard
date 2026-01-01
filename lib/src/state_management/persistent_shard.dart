import 'package:flutter/material.dart';
import 'package:shard/shard.dart';

/// A [Shard] with built-in state persistence.
///
/// [PersistentShard] automatically saves and restores state using the
/// configured storage and serializer. It extends [Shard] and mixes in
/// [StatePersistenceMixin] for persistence functionality.
///
/// ## Creating a Persistent Shard
///
/// ```dart
/// class TodoShard extends PersistentShard<TodoState> {
///   TodoShard()
///       : super(
///           TodoState.initial(),
///           storageFactory: () async =>
///               SharedPreferencesStorage.getInstance(),
///           serializer: stateSerializer(
///             fromJson: TodoState.fromJson,
///             toJson: (state) => state.toJson(),
///           ),
///         );
///
///   @override
///   String get persistenceKey => 'todos';
///
///   void addTodo(String title) {
///     emit(state.copyWith(
///       todos: [...state.todos, Todo(title: title)],
///     ));
///   }
/// }
/// ```
///
/// ## Configuration Options
///
/// - [storage] or [storageFactory] - Storage backend (one is required)
/// - [serializer] - Converts state to/from string (required)
/// - [autoSave] - Automatically save on state changes (default: true)
/// - [autoLoad] - Automatically load on init (default: true)
/// - [debounceDuration] - Debounce duration for auto-save (default: 500ms)
///
/// ## Error Handling
///
/// Override [onLoadError] and [onSaveError] to handle persistence errors:
///
/// ```dart
/// @override
/// void onLoadError(Object error, StackTrace? stackTrace) {
///   print('Failed to load state: $error');
/// }
///
/// @override
/// void onSaveError(Object error, StackTrace? stackTrace) {
///   print('Failed to save state: $error');
/// }
/// ```
///
/// See also:
/// - [Shard] for base state management
/// - [StateStorage] for storage interface
/// - [StateSerializer] for serialization interface
abstract class PersistentShard<T> extends Shard<T> with StatePersistenceMixin<T> {
  /// The key used to identify this shard's state in storage.
  ///
  /// Must be unique across all persistent shards using the same storage.
  ///
  /// ```dart
  /// @override
  /// String get persistenceKey => 'user_settings';
  /// ```
  String get persistenceKey;

  final T _initialState;
  final StateStorage? _storage;
  final Future<StateStorage> Function()? _storageFactory;
  final StateSerializer<T> _serializer;
  final bool _autoSave;
  final bool _autoLoad;
  final Duration _debounceDuration;

  /// Creates a new [PersistentShard] with the given configuration.
  ///
  /// Either [storage] or [storageFactory] must be provided, but not both.
  /// Use [storageFactory] when you need async storage initialization.
  ///
  /// - [initialState] - The initial state before loading from storage
  /// - [storage] - Pre-initialized storage instance
  /// - [storageFactory] - Factory function to create storage asynchronously
  /// - [serializer] - Serializer for converting state to/from string
  /// - [autoSave] - Whether to auto-save on state changes (default: true)
  /// - [autoLoad] - Whether to auto-load on init (default: true)
  /// - [debounceDuration] - Debounce duration for auto-save (default: 500ms)
  PersistentShard(
    super.initialState, {
    StateStorage? storage,
    Future<StateStorage> Function()? storageFactory,
    required StateSerializer<T> serializer,
    bool autoSave = true,
    bool autoLoad = true,
    Duration debounceDuration = const Duration(milliseconds: 500),
  })  : _initialState = initialState,
        _storage = storage,
        _storageFactory = storageFactory,
        _serializer = serializer,
        _autoSave = autoSave,
        _autoLoad = autoLoad,
        _debounceDuration = debounceDuration,
        super() {
    assert(
      storage != null || storageFactory != null,
      'Either storage or storageFactory must be provided',
    );
  }

  /// Called when loading state from storage fails.
  ///
  /// Override this method to handle load errors, such as showing
  /// a notification or falling back to default state.
  ///
  /// The error is automatically reported to observers via [addError].
  /// Override this method to add custom error handling.
  ///
  /// ```dart
  /// @override
  /// void onLoadError(Object error, StackTrace? stackTrace) {
  ///   super.onLoadError(error, stackTrace); // Reports to observer
  ///   analytics.logError('load_state_failed', error);
  /// }
  /// ```
  @mustCallSuper
  void onLoadError(Object error, StackTrace? stackTrace) {
    // Report error to observers
    addError(error, stackTrace);
  }

  /// Called when saving state to storage fails.
  ///
  /// Override this method to handle save errors, such as retrying
  /// or notifying the user.
  ///
  /// The error is automatically reported to observers via [addError].
  /// Override this method to add custom error handling.
  ///
  /// ```dart
  /// @override
  /// void onSaveError(Object error, StackTrace? stackTrace) {
  ///   super.onSaveError(error, stackTrace); // Reports to observer
  ///   showSnackBar('Failed to save. Please try again.');
  /// }
  /// ```
  @mustCallSuper
  void onSaveError(Object error, StackTrace? stackTrace) {
    // Report error to observers
    addError(error, stackTrace);
  }

  @override
  void onInit() {
    super.onInit();
    // Initialize persistence asynchronously but ensure it completes
    // Use unawaited to avoid blocking, but track the future
    _initializePersistence().catchError((error, stackTrace) {
      onLoadError(error, stackTrace);
    });
  }

  Future<void> _initializePersistence() async {
    // Check if disposed before initializing
    if (isDisposed) {
      return;
    }

    final storage = _storage ?? await _storageFactory!();

    // Check again after async operation - might have been disposed during storage creation
    if (isDisposed) {
      return;
    }

    enablePersistence(
      key: persistenceKey,
      storage: storage,
      serializer: _serializer,
      autoSave: _autoSave,
      autoLoad: _autoLoad,
      debounceDuration: _debounceDuration,
      onLoadError: onLoadError,
      onSaveError: onSaveError,
    );
  }

  /// Retries loading state from storage.
  ///
  /// Use this method to retry after a failed load, such as when
  /// the user has fixed a storage issue.
  ///
  /// ```dart
  /// ElevatedButton(
  ///   onPressed: () => shard.retry(),
  ///   child: Text('Retry'),
  /// )
  /// ```
  Future<void> retry() async {
    // Check if disposed before retrying
    if (isDisposed) {
      return;
    }

    try {
      await _initializePersistence();
    } catch (error, stackTrace) {
      // Only call onLoadError if not disposed
      if (!isDisposed) {
        // Call onLoadError but don't throw - retry is meant to be fire-and-forget
        onLoadError(error, stackTrace);
      }
    }
  }

  /// Clears storage and resets state to initial state.
  ///
  /// This method:
  /// 1. Clears all data from storage for this shard's key
  /// 2. Resets the state to [_initialState]
  ///
  /// ```dart
  /// ElevatedButton(
  ///   onPressed: () => shard.clear(),
  ///   child: Text('Reset to Default'),
  /// )
  /// ```
  Future<void> clear() async {
    // Check if disposed before clearing
    if (isDisposed) {
      return;
    }

    // Clear storage
    await clearStorage();

    // Check again after async operation - might have been disposed during clear
    if (isDisposed) {
      return;
    }

    // Reset local state to initial state
    // setStateInternal already has dispose check, but double-check here for safety
    if (!isDisposed) {
      setStateInternal(_initialState);
    }
  }
}
