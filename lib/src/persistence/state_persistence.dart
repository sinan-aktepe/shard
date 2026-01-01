import 'dart:async';
import '../state_management/shard.dart';
import 'storage.dart';
import 'serializer.dart';

/// Configuration for state persistence.
///
/// This class holds all the configuration options for persisting
/// shard state. It is used internally by [StatePersistenceMixin].
///
/// See also:
/// - [StatePersistenceMixin] for using this configuration
/// - [PersistentShard] for a ready-to-use persistent shard
class PersistenceConfig<T> {
  /// The key used to identify this state in storage.
  final String key;

  /// The storage backend for persisting state.
  final StateStorage storage;

  /// The serializer for converting state to/from strings.
  final StateSerializer<T> serializer;

  /// Whether to automatically save state on changes.
  final bool autoSave;

  /// Whether to automatically load state on initialization.
  final bool autoLoad;

  /// The debounce duration for auto-save operations.
  final Duration debounceDuration;

  /// Callback for handling save errors.
  final void Function(Object error, StackTrace? stackTrace)? onSaveError;

  /// Callback for handling load errors.
  final void Function(Object error, StackTrace? stackTrace)? onLoadError;

  /// Creates a new persistence configuration.
  PersistenceConfig({
    required this.key,
    required this.storage,
    required this.serializer,
    this.autoSave = true,
    this.autoLoad = true,
    this.debounceDuration = const Duration(milliseconds: 500),
    this.onSaveError,
    this.onLoadError,
  });
}

/// A mixin that adds state persistence to a [Shard].
///
/// This mixin provides automatic saving and loading of state using
/// a configurable storage backend and serializer.
///
/// ## Features
///
/// - **Auto-save**: Automatically saves state when it changes (debounced)
/// - **Auto-load**: Automatically loads state on initialization
/// - **Manual control**: [saveState] and [loadState] for manual persistence
/// - **Error handling**: Callbacks for handling save/load errors
///
/// ## Usage
///
/// Use this mixin when you want to add persistence to an existing [Shard]
/// subclass. For a simpler approach, consider using [PersistentShard] instead.
///
/// ```dart
/// class MyShard extends Shard<MyState> with StatePersistenceMixin<MyState> {
///   MyShard() : super(MyState.initial());
///
///   @override
///   void onInit() {
///     super.onInit();
///     enablePersistence(
///       key: 'my_state',
///       storage: myStorage,
///       serializer: mySerializer,
///     );
///   }
/// }
/// ```
///
/// ## Lifecycle
///
/// 1. Call [enablePersistence] to configure and start persistence
/// 2. State is automatically loaded if [autoLoad] is true
/// 3. State is automatically saved on changes if [autoSave] is true
/// 4. Call [disablePersistence] to stop persistence
///
/// See also:
/// - [PersistentShard] for a ready-to-use persistent shard
/// - [StateStorage] for storage interface
/// - [StateSerializer] for serialization interface
mixin StatePersistenceMixin<T> on Shard<T> {
  PersistenceConfig<T>? _persistenceConfig;
  bool _isPersistenceEnabled = false;
  Timer? _saveTimer;
  bool _isLoading = false;
  bool _pendingSave = false;
  bool _isSaving = false;

  @override
  void emit(T newState) {
    // Check if state will actually change (same logic as base emit)
    if (stateEquals(state, newState)) return;

    // Call the base implementation
    super.emit(newState);

    // Trigger auto-save if enabled (only if state changed)
    _triggerAutoSaveIfEnabled();
  }

  @override
  void emitForce(T newState) {
    // Call the base implementation (no equality check)
    super.emitForce(newState);

    // Trigger auto-save if enabled
    _triggerAutoSaveIfEnabled();
  }

  /// Enables persistence with the given configuration.
  ///
  /// This method must be called to start persisting state. It configures
  /// the storage backend, serializer, and auto-save/load behavior.
  ///
  /// - [key] - Unique key for this state in storage
  /// - [storage] - Storage backend to use
  /// - [serializer] - Serializer for state conversion
  /// - [autoSave] - Whether to auto-save on state changes (default: true)
  /// - [autoLoad] - Whether to auto-load on enable (default: true)
  /// - [debounceDuration] - Debounce duration for auto-save (default: 500ms)
  /// - [onSaveError] - Callback for save errors
  /// - [onLoadError] - Callback for load errors
  ///
  /// ```dart
  /// @override
  /// void onInit() {
  ///   super.onInit();
  ///   enablePersistence(
  ///     key: 'my_state',
  ///     storage: await SharedPreferencesStorage.getInstance(),
  ///     serializer: mySerializer,
  ///     debounceDuration: Duration(seconds: 1),
  ///   );
  /// }
  /// ```
  void enablePersistence({
    required String key,
    required StateStorage storage,
    required StateSerializer<T> serializer,
    bool autoSave = true,
    bool autoLoad = true,
    Duration debounceDuration = const Duration(milliseconds: 500),
    void Function(Object error, StackTrace? stackTrace)? onSaveError,
    void Function(Object error, StackTrace? stackTrace)? onLoadError,
  }) {
    // Check if disposed before enabling persistence
    if (isDisposed) {
      return;
    }

    _persistenceConfig = PersistenceConfig<T>(
      key: key,
      storage: storage,
      serializer: serializer,
      autoSave: autoSave,
      autoLoad: autoLoad,
      debounceDuration: debounceDuration,
      onSaveError: onSaveError,
      onLoadError: onLoadError,
    );
    _isPersistenceEnabled = true;

    // Auto-load if enabled
    if (autoLoad) {
      // loadState() handles errors internally and calls onLoadError callback
      loadState();
    }
  }

  /// Disables persistence and cleans up resources.
  ///
  /// After calling this method, state changes will no longer be
  /// automatically saved, and [saveState]/[loadState] will do nothing.
  void disablePersistence() {
    _saveTimer?.cancel();
    _saveTimer = null;
    _persistenceConfig = null;
    _isPersistenceEnabled = false;
  }

  /// Clears all data from storage.
  ///
  /// This removes all stored state. The in-memory state is not affected.
  /// Use [PersistentShard.clear] to also reset the in-memory state.
  Future<void> clearStorage() async {
    if (!_isPersistenceEnabled || _persistenceConfig == null) {
      return;
    }
    await _persistenceConfig!.storage.clear();
  }

  /// Manually saves the current state to storage.
  ///
  /// This method is automatically called by auto-save, but can also
  /// be called manually for immediate persistence.
  ///
  /// If a save is already in progress, the request is queued and
  /// will be executed after the current save completes.
  ///
  /// ```dart
  /// await shard.saveState();
  /// print('State saved!');
  /// ```
  Future<void> saveState() async {
    // Check if disposed before proceeding
    if (isDisposed) {
      return;
    }

    if (!_isPersistenceEnabled || _persistenceConfig == null) {
      return;
    }

    // Prevent concurrent saves - if a save is in progress, mark that we need to save again
    if (_isSaving) {
      _pendingSave = true;
      return;
    }

    _isSaving = true;
    _pendingSave = false;
    final config = _persistenceConfig!;
    final currentState = state;

    try {
      final serialized = config.serializer.serialize(currentState);
      await config.storage.save(config.key, serialized);
    } catch (error, stackTrace) {
      // Call the callback if provided
      if (config.onSaveError != null) {
        config.onSaveError!(error, stackTrace);
      }
    } finally {
      _isSaving = false;
      // If a save was requested while we were saving, save again now
      // But only if not disposed
      if (_pendingSave && !isDisposed) {
        _pendingSave = false;
        // Use a microtask to avoid recursion and allow the current save to fully complete
        Future.microtask(() => saveState());
      }
    }
  }

  /// Manually loads state from storage.
  ///
  /// Returns `true` if state was successfully loaded, `false` otherwise.
  /// This method is automatically called on initialization if [autoLoad]
  /// is true.
  ///
  /// ```dart
  /// final loaded = await shard.loadState();
  /// if (loaded) {
  ///   print('State restored from storage');
  /// } else {
  ///   print('No saved state found');
  /// }
  /// ```
  Future<bool> loadState() async {
    // Check if disposed before proceeding
    if (isDisposed) {
      return false;
    }

    if (!_isPersistenceEnabled || _persistenceConfig == null || _isLoading) {
      return false;
    }

    _isLoading = true;
    final config = _persistenceConfig!;

    try {
      final data = await config.storage.load(config.key);

      // Check again after async operation - might have been disposed during load
      if (isDisposed) {
        return false;
      }

      if (data != null && data.isNotEmpty) {
        final deserialized = config.serializer.deserialize(data);
        // Use type-safe setStateInternal method for state updates
        // setStateInternal already has dispose check, but double-check here for safety
        if (!isDisposed) {
          setStateInternal(deserialized);
          return true;
        }
      }
    } catch (error, stackTrace) {
      // Only call error handler if not disposed
      if (!isDisposed) {
        // Always call onLoadError if provided
        // This ensures errors are properly handled
        if (config.onLoadError != null) {
          config.onLoadError!(error, stackTrace);
        }
      }
    } finally {
      _isLoading = false;
    }

    return false;
  }

  // ignore: unused_element
  void _triggerAutoSaveIfEnabled() {
    // Check if disposed before triggering auto-save
    if (isDisposed) {
      return;
    }

    if (!_isPersistenceEnabled ||
        _persistenceConfig == null ||
        !_persistenceConfig!.autoSave) {
      return;
    }

    final config = _persistenceConfig!;

    // Cancel existing timer
    _saveTimer?.cancel();

    // Create new timer
    _saveTimer = Timer(config.debounceDuration, () {
      _saveTimer = null;
      // Check dispose again in timer callback
      if (!isDisposed) {
        saveState();
      }
    });
  }

  // ignore: unused_element
  void _disposePersistenceIfEnabled() {
    // Cancel the timer
    _saveTimer?.cancel();
    _saveTimer = null;

    // Clear pending operations flags
    _pendingSave = false;
    _isLoading = false;

    // If persistence is enabled, save immediately to ensure data is persisted
    // Only if not already saving (to avoid race conditions)
    if (_isPersistenceEnabled && _persistenceConfig != null && !_isSaving) {
      // Save asynchronously (fire and forget) to ensure data is persisted
      // Note: saveState() will check isDisposed internally, so it's safe to call
      saveState().catchError((error, stackTrace) {
        // Call the callback if provided (only if config still exists)
        if (_persistenceConfig?.onSaveError != null) {
          _persistenceConfig!.onSaveError!(error, stackTrace);
        }
      });
    }
  }
}
