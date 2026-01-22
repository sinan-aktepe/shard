import 'package:flutter/material.dart';
import 'package:shard/shard.dart';

/// A [Shard] with built-in state persistence.
///
/// [PersistentShard] automatically saves and restores data using the
/// configured storage and serializer. It extends [Shard] and mixes in
/// [StatePersistenceMixin] for persistence functionality.
///
/// Type parameters:
/// - [T] - The full state type of the shard
/// - [K] - The type of data to persist (can be a subset of T)
///
/// This separation allows you to:
/// - Only persist the data you need (e.g., todos list without loading status)
/// - Keep non-serializable fields in your state (e.g., loading flags, errors)
/// - Have full control over how loaded data is merged into state
///
/// ## Creating a Persistent Shard
///
/// ```dart
/// class TodoShard extends PersistentShard<TodoState, List<Todo>> {
///   TodoShard()
///       : super(
///           TodoState(status: TodoStatus.loading, todos: []),
///           storageFactory: () async =>
///               SharedPreferencesStorage.getInstance(),
///           serializer: TodoListSerializer(),
///         );
///
///   @override
///   String get persistenceKey => 'todos';
///
///   /// Extract only the todos list to persist
///   @override
///   List<Todo> toPersistence(TodoState state) => state.todos;
///
///   /// Handle load completion - data is null if storage was empty
///   @override
///   void onLoadComplete(List<Todo>? data) {
///     emit(state.copyWith(status: TodoStatus.loaded, todos: data ?? []));
///   }
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
/// - [serializer] - Converts persistence data to/from string (required)
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
///   super.onLoadError(error, stackTrace);
///   emit(state.copyWith(status: TodoStatus.error));
/// }
///
/// @override
/// void onSaveError(Object error, StackTrace? stackTrace) {
///   super.onSaveError(error, stackTrace);
///   showSnackBar('Failed to save. Please try again.');
/// }
/// ```
///
/// See also:
/// - [Shard] for base state management
/// - [StateStorage] for storage interface
/// - [StateSerializer] for serialization interface
abstract class PersistentShard<T, K> extends Shard<T>
    with StatePersistenceMixin<T, K> {
  /// The key used to identify this shard's data in storage.
  ///
  /// Must be unique across all persistent shards using the same storage.
  ///
  /// ```dart
  /// @override
  /// String get persistenceKey => 'user_settings';
  /// ```
  String get persistenceKey;

  final StateStorage? _storage;
  final Future<StateStorage> Function()? _storageFactory;
  final StateSerializer<K> _serializer;
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
  /// - [serializer] - Serializer for converting persistence data to/from string
  /// - [autoSave] - Whether to auto-save on state changes (default: true)
  /// - [autoLoad] - Whether to auto-load on init (default: true)
  /// - [debounceDuration] - Debounce duration for auto-save (default: 500ms)
  PersistentShard(
    super.initialState, {
    StateStorage? storage,
    Future<StateStorage> Function()? storageFactory,
    required StateSerializer<K> serializer,
    bool autoSave = true,
    bool autoLoad = true,
    Duration debounceDuration = const Duration(milliseconds: 500),
  }) : _storage = storage,
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

  /// Extracts the data to persist from the current state.
  ///
  /// Override this method to specify which part of the state should be
  /// persisted. This allows you to exclude non-serializable fields like
  /// loading status, error messages, or computed values.
  ///
  /// ```dart
  /// @override
  /// List<Todo> toPersistence(TodoState state) => state.todos;
  /// ```
  @protected
  K toPersistence(T state);

  /// Called when load operation completes.
  ///
  /// Override this method to merge the loaded data into your state.
  /// This gives you full control over how the loaded data is applied.
  ///
  /// The [data] parameter is:
  /// - The deserialized data if storage had data
  /// - `null` if storage was empty (first launch)
  ///
  /// ```dart
  /// @override
  /// void onLoadComplete(List<Todo>? data) {
  ///   emit(state.copyWith(
  ///     status: TodoStatus.loaded,
  ///     todos: data ?? [],
  ///   ));
  /// }
  /// ```
  @protected
  void onLoadComplete(K? data);

  /// Called when loading data from storage fails.
  ///
  /// The shard continues with the initial state, so your app doesn't crash.
  /// Override this method to handle load errors, such as showing
  /// a notification or updating error state.
  ///
  /// The error is automatically reported to observers via [addError].
  /// Override this method to add custom error handling.
  ///
  /// ```dart
  /// @override
  /// void onLoadError(Object error, StackTrace? stackTrace) {
  ///   super.onLoadError(error, stackTrace); // Reports to observer
  ///   emit(state.copyWith(status: TodoStatus.error));
  /// }
  /// ```
  @mustCallSuper
  void onLoadError(Object error, StackTrace? stackTrace) {
    // Report error to observers
    addError(error, stackTrace);
  }

  /// Called when saving data to storage fails.
  ///
  /// The in-memory state remains updated, so your app continues normally.
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
      toPersistence: toPersistence,
      autoSave: _autoSave,
      autoLoad: _autoLoad,
      debounceDuration: _debounceDuration,
      onLoadError: onLoadError,
      onSaveError: onSaveError,
      onLoadComplete: onLoadComplete,
    );
  }

  /// Retries loading data from storage.
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
}

/// A simplified [PersistentShard] for cases where the state type and
/// persistence type are the same.
///
/// Use this class when you want to persist the entire state without
/// any transformation. For more complex scenarios where you need to
/// persist only a subset of your state, use [PersistentShard] instead.
///
/// ## Example
///
/// ```dart
/// class CounterShard extends SimplePersistentShard<int> {
///   CounterShard()
///       : super(
///           0,
///           storageFactory: () => SharedPreferencesStorage.getInstance(),
///           serializer: IntSerializer(),
///         );
///
///   @override
///   String get persistenceKey => 'counter';
///
///   void increment() => emit(state + 1);
///   void decrement() => emit(state - 1);
/// }
/// ```
///
/// ## Default Behavior
///
/// - [toPersistence] returns the state as-is
/// - [onLoadComplete] replaces the state with loaded data (or keeps initial if null)
///
/// You can override these methods if you need custom behavior.
///
/// See also:
/// - [PersistentShard] for more complex persistence scenarios
abstract class SimplePersistentShard<T> extends PersistentShard<T, T> {
  /// Creates a new [SimplePersistentShard] with the given configuration.
  ///
  /// Either [storage] or [storageFactory] must be provided, but not both.
  ///
  /// - [initialState] - The initial state before loading from storage
  /// - [storage] - Pre-initialized storage instance
  /// - [storageFactory] - Factory function to create storage asynchronously
  /// - [serializer] - Serializer for converting state to/from string
  /// - [autoSave] - Whether to auto-save on state changes (default: true)
  /// - [autoLoad] - Whether to auto-load on init (default: true)
  /// - [debounceDuration] - Debounce duration for auto-save (default: 500ms)
  SimplePersistentShard(
    super.initialState, {
    super.storage,
    super.storageFactory,
    required super.serializer,
    super.autoSave,
    super.autoLoad,
    super.debounceDuration,
  });

  /// Returns the state as-is for persistence.
  ///
  /// Override this method if you need to transform the state before saving.
  @override
  T toPersistence(T state) => state;

  /// Replaces the current state with the loaded data.
  ///
  /// If [data] is null (storage was empty), the initial state is kept.
  /// Override this method if you need custom merge behavior.
  @override
  void onLoadComplete(T? data) {
    if (data != null) {
      emit(data);
    }
  }
}
