import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../state_management/shard.dart';
import 'storage.dart';
import 'serializer.dart';

/// Configuration for state persistence.
///
/// This class holds all the configuration options for persisting
/// shard state. It is used internally by [StatePersistenceMixin].
///
/// Type parameters:
/// - [T] - The full state type of the shard
/// - [K] - The type of data to persist (can be a subset of T)
///
/// See also:
/// - [StatePersistenceMixin] for using this configuration
/// - [PersistentShard] for a ready-to-use persistent shard
class PersistenceConfig<T, K> {
  /// The key used to identify this state in storage.
  final String key;

  /// The storage backend for persisting state.
  final StateStorage storage;

  /// The serializer for converting persistence data to/from strings.
  final StateSerializer<K> serializer;

  /// Function to extract the data to persist from the state.
  final K Function(T state) toPersistence;

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

  /// Callback called when load operation completes.
  /// Receives the deserialized data of type [K], or null if storage was empty.
  final void Function(K? data)? onLoadComplete;

  /// The current schema version written into the persistence envelope.
  final int version;

  /// Migrates a stored payload from [fromVersion] up to [version].
  ///
  /// Called once on load when the stored version is older than [version];
  /// the function is responsible for chaining intermediate migrations.
  final String Function(int fromVersion, String payload)? migrate;

  /// Whether to flush a save when the app is paused or detached.
  final bool flushOnPause;

  /// Creates a new persistence configuration.
  PersistenceConfig({
    required this.key,
    required this.storage,
    required this.serializer,
    required this.toPersistence,
    this.autoSave = true,
    this.autoLoad = true,
    this.debounceDuration = const Duration(milliseconds: 500),
    this.onSaveError,
    this.onLoadError,
    this.onLoadComplete,
    this.version = 1,
    this.migrate,
    this.flushOnPause = false,
  });
}

/// A mixin that adds state persistence to a [Shard].
///
/// This mixin provides automatic saving and loading of state using
/// a configurable storage backend and serializer.
///
/// Type parameters:
/// - [T] - The full state type of the shard
/// - [K] - The type of data to persist (can be a subset of T)
///
/// ## Features
///
/// - **Auto-save**: Automatically saves state when it changes (debounced)
/// - **Auto-load**: Automatically loads state on initialization
/// - **Manual control**: [saveState] and [loadState] for manual persistence
/// - **Error handling**: Callbacks for handling save/load errors
/// - **Partial persistence**: Only persist the data you need with [toPersistence]
///
/// ## Usage
///
/// Use this mixin when you want to add persistence to an existing [Shard]
/// subclass. For a simpler approach, consider using [PersistentShard] instead.
///
/// ```dart
/// class MyShard extends Shard<MyState> with StatePersistenceMixin<MyState, MyData> {
///   MyShard() : super(MyState.initial());
///
///   @override
///   void onInit() {
///     super.onInit();
///     enablePersistence(
///       key: 'my_state',
///       storage: myStorage,
///       serializer: myDataSerializer,
///       toPersistence: (state) => state.data,
///       onLoadComplete: (data) => emit(state.copyWith(
///         status: LoadStatus.loaded,
///         data: data ?? defaultData,
///       )),
///     );
///   }
/// }
/// ```
///
/// ## Lifecycle
///
/// 1. Call [enablePersistence] to configure and start persistence
/// 2. Data is automatically loaded if [autoLoad] is true
/// 3. Data is automatically saved on state changes if [autoSave] is true
/// 4. Call [disablePersistence] to stop persistence
///
/// See also:
/// - [PersistentShard] for a ready-to-use persistent shard
/// - [StateStorage] for storage interface
/// - [StateSerializer] for serialization interface
mixin StatePersistenceMixin<T, K> on Shard<T> {
  static const String _autoSaveDebounceKey = 'shard_persistence_save';
  static const String _envelopeVersionKey = '__shard_v';
  static const String _envelopePayloadKey = '__shard_p';

  /// Serializes the current persistable slice into a version envelope.
  String _wrapEnvelope(PersistenceConfig<T, K> config) {
    final dataToSave = config.toPersistence(state);
    final serialized = config.serializer.serialize(dataToSave);
    return jsonEncode({
      _envelopeVersionKey: config.version,
      _envelopePayloadKey: serialized,
    });
  }

  PersistenceConfig<T, K>? _persistenceConfig;
  bool _isLoading = false;
  Future<void> _saveQueue = Future.value();
  _ShardLifecycleObserver? _lifecycleObserver;

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
  /// - [serializer] - Serializer for persistence data conversion
  /// - [toPersistence] - Function to extract data to persist from state
  /// - [autoSave] - Whether to auto-save on state changes (default: true)
  /// - [autoLoad] - Whether to auto-load on enable (default: true)
  /// - [debounceDuration] - Debounce duration for auto-save (default: 500ms)
  /// - [onSaveError] - Callback for save errors
  /// - [onLoadError] - Callback for load errors
  /// - [onLoadComplete] - Callback when load completes (data is null if storage was empty)
  /// - [version] - Current schema version stored in the envelope (default: 1)
  /// - [migrate] - Migrates an older stored payload to [version]; called once
  ///   with the stored version when it is older than [version]
  /// - [flushOnPause] - When true, registers a `WidgetsBindingObserver` that
  ///   flushes [saveState] when the app is paused or detached (default: false;
  ///   requires an initialized `WidgetsBinding`)
  ///
  /// ```dart
  /// @override
  /// void onInit() {
  ///   super.onInit();
  ///   enablePersistence(
  ///     key: 'my_state',
  ///     storage: await SharedPreferencesStorage.getInstance(),
  ///     serializer: myDataSerializer,
  ///     toPersistence: (state) => state.items,
  ///     onLoadComplete: (items) => emit(state.copyWith(
  ///       status: LoadStatus.loaded,
  ///       items: items ?? [],
  ///     )),
  ///   );
  /// }
  /// ```
  void enablePersistence({
    required String key,
    required StateStorage storage,
    required StateSerializer<K> serializer,
    required K Function(T state) toPersistence,
    bool autoSave = true,
    bool autoLoad = true,
    Duration debounceDuration = const Duration(milliseconds: 500),
    void Function(Object error, StackTrace? stackTrace)? onSaveError,
    void Function(Object error, StackTrace? stackTrace)? onLoadError,
    void Function(K? data)? onLoadComplete,
    int version = 1,
    String Function(int fromVersion, String payload)? migrate,
    bool flushOnPause = false,
  }) {
    assert(
      migrate == null || version > 1,
      'migrate only runs when the stored version is older than `version`; '
      'with version 1 it is never called. Bump `version` to use migration.',
    );
    // Check if disposed before enabling persistence
    if (isDisposed) {
      return;
    }

    _persistenceConfig = PersistenceConfig<T, K>(
      key: key,
      storage: storage,
      serializer: serializer,
      toPersistence: toPersistence,
      autoSave: autoSave,
      autoLoad: autoLoad,
      debounceDuration: debounceDuration,
      onSaveError: onSaveError,
      onLoadError: onLoadError,
      onLoadComplete: onLoadComplete,
      version: version,
      migrate: migrate,
      flushOnPause: flushOnPause,
    );

    // Register a lifecycle observer to flush on pause/detach, if requested.
    // Remove any observer from a previous enablePersistence call first so a
    // re-configuration cannot leak the old one.
    _removeLifecycleObserver();
    if (flushOnPause) {
      _lifecycleObserver = _ShardLifecycleObserver(() {
        if (!isDisposed) saveState();
      });
      WidgetsBinding.instance.addObserver(_lifecycleObserver!);
    }

    // Auto-load if enabled
    if (autoLoad) {
      // loadState() handles errors internally and calls onLoadError callback
      loadState();
    }
  }

  void _removeLifecycleObserver() {
    if (_lifecycleObserver != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
      _lifecycleObserver = null;
    }
  }

  /// Disables persistence and cleans up resources.
  ///
  /// After calling this method, state changes will no longer be
  /// automatically saved, and [saveState]/[loadState] will do nothing.
  void disablePersistence() {
    _persistenceConfig = null;
    cancelDebounce(_autoSaveDebounceKey);
    _saveQueue = Future.value();
    _removeLifecycleObserver();
  }

  /// Clears this shard's persisted slice from storage (e.g. on logout).
  ///
  /// Cancels any pending debounced auto-save, then deletes the stored value
  /// via [StateStorage.delete], chained onto the save queue so it cannot race
  /// a previously queued write. A subsequent [loadState] calls [onLoadComplete]
  /// with `null` (no data). Delete failures are routed to [onSaveError].
  ///
  /// This does NOT change the in-memory state — pair it with
  /// `emit(initialState)` if you also want to reset the live state.
  ///
  /// If you intend to dispose the shard right after clearing, call
  /// [disablePersistence] first: otherwise the disposal flush re-saves the
  /// current in-memory state and recreates the key you just deleted.
  Future<void> clearPersistence() async {
    final config = _persistenceConfig;
    if (config == null) return;
    cancelDebounce(_autoSaveDebounceKey);
    _saveQueue = _saveQueue.then((_) async {
      try {
        await config.storage.delete(config.key);
      } catch (error, stackTrace) {
        config.onSaveError?.call(error, stackTrace);
      }
    });
    return _saveQueue;
  }

  /// Manually saves the current state to storage.
  ///
  /// This method is automatically called by auto-save, but can also
  /// be called manually for immediate persistence.
  ///
  /// If a save is already in progress, the request is queued and
  /// will be executed after the current save completes.
  ///
  /// The data to save is extracted using the [toPersistence] function.
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

    if (_persistenceConfig == null) {
      return;
    }

    _saveQueue = _saveQueue.then((_) async {
      if (isDisposed) {
        return;
      }

      final config = _persistenceConfig;
      if (config == null) {
        return;
      }

      try {
        await config.storage.save(config.key, _wrapEnvelope(config));
      } catch (error, stackTrace) {
        // Call the callback if provided
        if (config.onSaveError != null) {
          config.onSaveError!(error, stackTrace);
        }
      }
    });

    return _saveQueue;
  }

  /// Manually loads data from storage.
  ///
  /// Returns `true` if load operation completed successfully, `false` otherwise.
  /// This method is automatically called on initialization if [autoLoad]
  /// is true.
  ///
  /// When load completes, the [onLoadComplete] callback is called:
  /// - With the deserialized data if storage had data
  /// - With `null` if storage was empty (first launch)
  ///
  /// The callback is responsible for merging the loaded data into the state.
  ///
  /// ```dart
  /// final loaded = await shard.loadState();
  /// if (loaded) {
  ///   print('Load operation completed');
  /// }
  /// ```
  Future<bool> loadState() async {
    // Check if disposed before proceeding
    if (isDisposed) {
      return false;
    }

    if (_persistenceConfig == null || _isLoading) {
      return false;
    }

    _isLoading = true;
    final config = _persistenceConfig!;

    try {
      final raw = await config.storage.load(config.key);

      // Check again after async operation - might have been disposed during load
      if (isDisposed) {
        return false;
      }

      if (raw == null || raw.isEmpty) {
        if (!isDisposed) {
          config.onLoadComplete?.call(null);
          return true;
        }
        return false;
      }

      // Detect a version envelope; otherwise treat as legacy (version 1) data.
      var storedVersion = 1;
      var payload = raw;
      Object? decoded;
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        decoded = null; // not JSON → legacy bare payload
      }
      if (decoded is Map &&
          decoded.containsKey(_envelopeVersionKey) &&
          decoded.containsKey(_envelopePayloadKey)) {
        storedVersion = decoded[_envelopeVersionKey] as int;
        payload = decoded[_envelopePayloadKey] as String;
      }

      if (storedVersion < config.version && config.migrate != null) {
        payload = config.migrate!(storedVersion, payload);
      }

      final deserialized = config.serializer.deserialize(payload);
      if (!isDisposed) {
        config.onLoadComplete?.call(deserialized);
        return true;
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

  void _triggerAutoSaveIfEnabled() {
    // Check if disposed before triggering auto-save
    if (isDisposed) {
      return;
    }

    if (_persistenceConfig == null || !_persistenceConfig!.autoSave) {
      return;
    }

    final config = _persistenceConfig!;

    debounce(_autoSaveDebounceKey, () {
      if (!isDisposed) {
        saveState();
      }
    }, duration: config.debounceDuration);
  }

  @override
  void disposePersistenceIfEnabled() {
    cancelDebounce(_autoSaveDebounceKey);
    _removeLifecycleObserver();
    _isLoading = false;

    // If persistence is enabled, flush any pending save before teardown.
    // We bypass the isDisposed guard here intentionally — disposal is the
    // one moment where we must save regardless of the disposed flag.
    final config = _persistenceConfig;
    if (config != null) {
      _saveQueue = _saveQueue.then((_) async {
        try {
          await config.storage.save(config.key, _wrapEnvelope(config));
        } catch (error, stackTrace) {
          if (config.onSaveError != null) {
            config.onSaveError!(error, stackTrace);
          }
        }
      });
    }
  }
}

/// Internal [WidgetsBindingObserver] that invokes [_onPauseOrDetach] when the
/// app is paused or detached. Used by [StatePersistenceMixin] when
/// `flushOnPause` is enabled.
class _ShardLifecycleObserver extends WidgetsBindingObserver {
  _ShardLifecycleObserver(this._onPauseOrDetach);

  final void Function() _onPauseOrDetach;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _onPauseOrDetach();
    }
  }
}
