import 'dart:convert';

/// Abstract interface for state serialization.
///
/// Implement this interface to convert state objects to and from
/// string representations for storage. The serializer is responsible
/// for encoding state to a string and decoding it back.
///
/// ## Built-in Serializers
///
/// The package provides several built-in serializers:
///
/// - [IntSerializer] - For `int` state
/// - [DoubleSerializer] - For `double` state
/// - [BoolSerializer] - For `bool` state
/// - [StringSerializer] - For `String` state
/// - [stateSerializer] - Factory for JSON-based serialization
///
/// ## Using stateSerializer
///
/// For complex state objects, use the [stateSerializer] factory:
///
/// ```dart
/// final serializer = stateSerializer<UserState>(
///   fromJson: UserState.fromJson,
///   toJson: (state) => state.toJson(),
/// );
/// ```
///
/// ## Custom Implementation
///
/// ```dart
/// class MyStateSerializer implements StateSerializer<MyState> {
///   @override
///   String serialize(MyState state) {
///     return jsonEncode(state.toJson());
///   }
///
///   @override
///   MyState deserialize(String data) {
///     return MyState.fromJson(jsonDecode(data));
///   }
/// }
/// ```
///
/// ## Usage with PersistentShard
///
/// ```dart
/// class MyShard extends PersistentShard<MyState, MyState> {
///   MyShard()
///       : super(
///           MyState.initial(),
///           storage: storage,
///           serializer: stateSerializer(
///             fromJson: MyState.fromJson,
///             toJson: (state) => state.toJson(),
///           ),
///         );
///
///   @override
///   String get persistenceKey => 'my_state';
///
///   @override
///   MyState toPersistence(MyState state) => state;
///
///   @override
///   void onLoadComplete(MyState? data) {
///     if (data != null) emit(data);
///   }
/// }
/// ```
///
/// See also:
/// - [StateStorage] for storage interface
/// - [stateSerializer] for JSON serialization
/// - [PersistentShard] for shards with persistence
abstract class StateSerializer<T> {
  /// Converts the [state] object to a string representation.
  ///
  /// The returned string will be stored by [StateStorage].
  /// Must be reversible via [deserialize].
  ///
  /// Throws an exception if serialization fails.
  String serialize(T state);

  /// Converts a string [data] back to a state object.
  ///
  /// The [data] parameter is a string previously created by [serialize].
  /// Must correctly restore the original state.
  ///
  /// Throws an exception if deserialization fails.
  T deserialize(String data);
}

/// Creates a [StateSerializer] for JSON-based serialization.
///
/// This factory simplifies creating serializers for complex objects that have
/// `toJson()` and `fromJson()` methods, eliminating the need to create
/// a separate serializer class for each state type.
///
/// ## Basic Usage
///
/// For a single object with `toJson()` and `fromJson()`:
///
/// ```dart
/// final userSerializer = stateSerializer<User>(
///   fromJson: User.fromJson,
///   toJson: (user) => user.toJson(),
/// );
/// ```
///
/// ## List of Objects
///
/// For a list of objects:
///
/// ```dart
/// final todoListSerializer = stateSerializer<List<Todo>>(
///   fromJson: (json) => (json as List)
///       .map((e) => Todo.fromJson(e as Map<String, dynamic>))
///       .toList(),
///   toJson: (todos) => todos.map((t) => t.toJson()).toList(),
/// );
/// ```
///
/// ## Usage with PersistentShard
///
/// ```dart
/// class TodoShard extends PersistentShard<TodoState, List<Todo>> {
///   TodoShard()
///       : super(
///           TodoState.initial(),
///           storageFactory: () => SharedPreferencesStorage.getInstance(),
///           serializer: stateSerializer<List<Todo>>(
///             fromJson: (json) => (json as List)
///                 .map((e) => Todo.fromJson(e as Map<String, dynamic>))
///                 .toList(),
///             toJson: (todos) => todos.map((t) => t.toJson()).toList(),
///           ),
///         );
///
///   @override
///   String get persistenceKey => 'todos';
///
///   @override
///   List<Todo> toPersistence(TodoState state) => state.todos;
///
///   @override
///   void onLoadComplete(List<Todo>? data) {
///     emit(state.copyWith(status: TodoStatus.loaded, todos: data ?? []));
///   }
/// }
/// ```
///
/// See also:
/// - [StateSerializer] for the base interface
/// - [IntSerializer], [DoubleSerializer], [BoolSerializer], [StringSerializer]
///   for primitive type serializers
/// - [PersistentShard] for shards with persistence
StateSerializer<T> stateSerializer<T>({
  required T Function(dynamic json) fromJson,
  required dynamic Function(T state) toJson,
}) {
  return _JsonStateSerializer<T>(fromJson: fromJson, toJson: toJson);
}

/// Internal implementation of JSON-based state serializer.
class _JsonStateSerializer<T> implements StateSerializer<T> {
  final T Function(dynamic json) _fromJson;
  final dynamic Function(T state) _toJson;

  _JsonStateSerializer({
    required T Function(dynamic json) fromJson,
    required dynamic Function(T state) toJson,
  }) : _fromJson = fromJson,
       _toJson = toJson;

  @override
  String serialize(T state) {
    return jsonEncode(_toJson(state));
  }

  @override
  T deserialize(String data) {
    return _fromJson(jsonDecode(data));
  }
}
