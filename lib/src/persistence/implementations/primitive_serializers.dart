import '../serializer.dart';

/// A [StateSerializer] for `int` state.
///
/// This serializer converts integers to and from strings for storage.
/// Use this when your shard's state is a simple integer.
///
/// ## Usage
///
/// ```dart
/// class CounterShard extends PersistentShard<int> {
///   CounterShard()
///       : super(
///           0,
///           storage: myStorage,
///           serializer: IntSerializer(),
///         );
///
///   @override
///   String get persistenceKey => 'counter';
///
///   void increment() => emit(state + 1);
/// }
/// ```
///
/// See also:
/// - [DoubleSerializer] for double values
/// - [BoolSerializer] for boolean values
/// - [stateSerializer] for complex objects
class IntSerializer implements StateSerializer<int> {
  /// Creates an [IntSerializer].
  const IntSerializer();

  @override
  String serialize(int state) {
    return state.toString();
  }

  @override
  int deserialize(String data) {
    return int.parse(data);
  }
}

/// A [StateSerializer] for `double` state.
///
/// This serializer converts doubles to and from strings for storage.
/// Use this when your shard's state is a simple double.
///
/// ## Usage
///
/// ```dart
/// class TemperatureShard extends PersistentShard<double> {
///   TemperatureShard()
///       : super(
///           20.0,
///           storage: myStorage,
///           serializer: DoubleSerializer(),
///         );
///
///   @override
///   String get persistenceKey => 'temperature';
///
///   void setTemperature(double value) => emit(value);
/// }
/// ```
///
/// See also:
/// - [IntSerializer] for integer values
/// - [BoolSerializer] for boolean values
/// - [stateSerializer] for complex objects
class DoubleSerializer implements StateSerializer<double> {
  /// Creates a [DoubleSerializer].
  const DoubleSerializer();

  @override
  String serialize(double state) {
    return state.toString();
  }

  @override
  double deserialize(String data) {
    return double.parse(data);
  }
}

/// A [StateSerializer] for `bool` state.
///
/// This serializer converts booleans to and from strings for storage.
/// Use this when your shard's state is a simple boolean.
///
/// ## Usage
///
/// ```dart
/// class DarkModeShard extends PersistentShard<bool> {
///   DarkModeShard()
///       : super(
///           false,
///           storage: myStorage,
///           serializer: BoolSerializer(),
///         );
///
///   @override
///   String get persistenceKey => 'dark_mode';
///
///   void toggle() => emit(!state);
/// }
/// ```
///
/// See also:
/// - [IntSerializer] for integer values
/// - [DoubleSerializer] for double values
/// - [stateSerializer] for complex objects
class BoolSerializer implements StateSerializer<bool> {
  /// Creates a [BoolSerializer].
  const BoolSerializer();

  @override
  String serialize(bool state) {
    return state.toString();
  }

  @override
  bool deserialize(String data) {
    return data == 'true';
  }
}

