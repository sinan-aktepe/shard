/// Abstract interface for state storage backends.
///
/// Implement this interface to create custom storage backends for
/// persisting shard state. The storage is responsible for saving and
/// loading serialized state strings.
///
/// ## Built-in Implementations
///
/// The package doesn't include storage implementations to avoid dependencies.
/// Common implementations include:
///
/// - SharedPreferences-based storage
/// - Hive-based storage
/// - SQLite-based storage
/// - File-based storage
///
/// ## Example Implementation
///
/// ```dart
/// import 'package:shared_preferences/shared_preferences.dart';
///
/// class SharedPreferencesStorage implements StateStorage {
///   final SharedPreferences _prefs;
///
///   SharedPreferencesStorage._(this._prefs);
///
///   static Future<SharedPreferencesStorage> getInstance() async {
///     final prefs = await SharedPreferences.getInstance();
///     return SharedPreferencesStorage._(prefs);
///   }
///
///   @override
///   Future<void> save(String key, String value) async {
///     await _prefs.setString(key, value);
///   }
///
///   @override
///   Future<String?> load(String key) async {
///     return _prefs.getString(key);
///   }
///
///   @override
///   Future<void> delete(String key) async {
///     await _prefs.remove(key);
///   }
/// }
/// ```
///
/// ## Usage with PersistentShard
///
/// ```dart
/// class MyShard extends PersistentShard<MyState> {
///   MyShard()
///       : super(
///           MyState.initial(),
///           storageFactory: () => SharedPreferencesStorage.getInstance(),
///           serializer: mySerializer,
///         );
///
///   @override
///   String get persistenceKey => 'my_state';
/// }
/// ```
///
/// See also:
/// - [StateSerializer] for serializing state
/// - [PersistentShard] for shards with persistence
/// - [StatePersistenceMixin] for adding persistence to existing shards
abstract class StateStorage {
  /// Saves a [value] associated with the given [key].
  ///
  /// The [value] is a serialized string representation of the state.
  /// Implementations should handle overwriting existing values.
  ///
  /// Throws an exception if the save operation fails.
  Future<void> save(String key, String value);

  /// Loads the value associated with the given [key].
  ///
  /// Returns `null` if no value exists for the key.
  /// Returns the serialized string if a value exists.
  ///
  /// Throws an exception if the load operation fails.
  Future<String?> load(String key);

  /// Removes any value stored under [key].
  ///
  /// A no-op if the key is absent. After this completes, a subsequent [load]
  /// for the same [key] must return `null`.
  ///
  /// Throws an exception if the delete operation fails.
  Future<void> delete(String key);
}
