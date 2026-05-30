import '../persistence/storage.dart';

/// An in-memory [StateStorage] implementation for use in tests.
///
/// Supports seeded initial data, failure injection, latency simulation,
/// and call inspection (counts and recorded keys).
///
/// ```dart
/// final storage = FakeStateStorage()
///   ..seed('user', '{"id":1}')
///   ..loadError = Exception('disk read failed');
/// ```
class FakeStateStorage implements StateStorage {
  /// Creates a [FakeStateStorage], optionally pre-populated with [initialData].
  FakeStateStorage({Map<String, String>? initialData}) {
    if (initialData != null) _data.addAll(initialData);
  }

  final Map<String, String> _data = {};
  final List<String> _savedKeys = [];

  /// If non-null, [load] throws this object instead of returning a value.
  Object? loadError;

  /// If non-null, [save] throws this object instead of recording the write.
  ///
  /// Note: the failed save still increments [saveCount] and appends to
  /// [savedKeys] (the call attempt is observable), but [data] / [rawValue]
  /// are NOT updated.
  Object? saveError;

  /// If non-null, [load] awaits this duration before completing.
  Duration? loadDelay;

  /// If non-null, [save] awaits this duration before completing.
  Duration? saveDelay;

  /// Total number of [load] calls since construction (or last [reset]).
  int loadCount = 0;

  /// Total number of [save] calls since construction (or last [reset]).
  int saveCount = 0;

  /// All keys passed to [save], in order, including duplicates.
  List<String> get savedKeys => List.unmodifiable(_savedKeys);

  /// An unmodifiable view of the underlying key→value map.
  Map<String, String> get data => Map.unmodifiable(_data);

  /// Whether [key] is currently present in storage.
  bool hasKey(String key) => _data.containsKey(key);

  /// The raw serialized value for [key], or null if missing.
  String? rawValue(String key) => _data[key];

  /// Writes [value] into the in-memory map without counting as a [save] call.
  void seed(String key, String value) {
    _data[key] = value;
  }

  /// Wipes stored data only.
  ///
  /// Preserves [loadCount], [saveCount], [savedKeys], [loadError],
  /// [saveError], [loadDelay], and [saveDelay]. Use [reset] to wipe
  /// every internal field.
  void clear() {
    _data.clear();
  }

  /// Wipes all internal state — data, counters, errors, and delays.
  void reset() {
    _data.clear();
    _savedKeys.clear();
    loadCount = 0;
    saveCount = 0;
    loadError = null;
    saveError = null;
    loadDelay = null;
    saveDelay = null;
  }

  @override
  Future<void> save(String key, String value) async {
    saveCount++;
    _savedKeys.add(key);
    if (saveDelay != null) await Future<void>.delayed(saveDelay!);
    if (saveError != null) throw saveError!;
    _data[key] = value;
  }

  @override
  Future<String?> load(String key) async {
    loadCount++;
    if (loadDelay != null) await Future<void>.delayed(loadDelay!);
    if (loadError != null) throw loadError!;
    return _data[key];
  }
}
