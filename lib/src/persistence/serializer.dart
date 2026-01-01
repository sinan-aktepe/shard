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
/// class MyShard extends PersistentShard<MyState> {
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
