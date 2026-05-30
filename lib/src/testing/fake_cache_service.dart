import '../caching/cache_entry.dart';
import '../caching/cache_service.dart';

/// An in-memory [CacheService] implementation for use in tests.
///
/// Supports seeded initial entries (fresh or expired), failure injection
/// for read/write/delete/clearAll, latency simulation, and call inspection.
///
/// ```dart
/// final cache = FakeCacheService()
///   ..seed('user_1', User(id: 1, name: 'Alice'))
///   ..readError = Exception('cache offline');
/// ```
class FakeCacheService implements CacheService {
  /// Creates a [FakeCacheService], optionally pre-populated with [initialData].
  FakeCacheService({Map<String, CacheEntry>? initialData}) {
    if (initialData != null) _data.addAll(initialData);
  }

  final Map<String, CacheEntry> _data = {};
  final List<String> _readKeys = [];
  final List<String> _writeKeys = [];

  /// If non-null, [read] throws this object instead of returning.
  ///
  /// Note: the failed read still increments [readCount] and appends to
  /// [readKeys] (the attempt is observable).
  Object? readError;

  /// If non-null, [write] throws.
  ///
  /// Note: the failed write still increments [writeCount] and appends to
  /// [writeKeys], but [entries] is NOT updated.
  Object? writeError;

  /// If non-null, [delete] throws.
  ///
  /// Note: the failed delete still increments [deleteCount], but the entry
  /// is NOT removed.
  Object? deleteError;

  /// If non-null, [clearAll] throws and entries are NOT cleared.
  Object? clearError;

  /// If non-null, [read] awaits this duration before completing.
  Duration? readDelay;

  /// If non-null, [write] awaits this duration before completing.
  Duration? writeDelay;

  /// Number of [read] calls since construction (or last [reset]).
  int readCount = 0;

  /// Number of [write] calls.
  int writeCount = 0;

  /// Number of [delete] calls.
  int deleteCount = 0;

  /// Keys passed to [read], in order, duplicates included.
  List<String> get readKeys => List.unmodifiable(_readKeys);

  /// Keys passed to [write], in order, duplicates included.
  List<String> get writeKeys => List.unmodifiable(_writeKeys);

  /// Unmodifiable view of stored entries.
  Map<String, CacheEntry> get entries => Map.unmodifiable(_data);

  /// Whether [key] is currently present in the cache.
  bool hasKey(String key) => _data.containsKey(key);

  /// Pre-populates a fresh entry that expires in [ttl] (default 1 hour).
  void seed(String key, Object? data, {Duration ttl = const Duration(hours: 1)}) {
    _data[key] = CacheEntry(data: data, expiryDate: DateTime.now().add(ttl));
  }

  /// Pre-populates an entry already expired (expiry at epoch 0).
  void seedExpired(String key, Object? data) {
    _data[key] = CacheEntry(
      data: data,
      expiryDate: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  /// Wipes stored entries only.
  ///
  /// Preserves [readCount], [writeCount], [deleteCount], [readKeys],
  /// [writeKeys], all injected errors, and all delays. Use [reset] to wipe
  /// every internal field.
  void clear() {
    _data.clear();
  }

  /// Wipes everything — data, counters, key lists, errors, delays.
  void reset() {
    _data.clear();
    _readKeys.clear();
    _writeKeys.clear();
    readCount = 0;
    writeCount = 0;
    deleteCount = 0;
    readError = null;
    writeError = null;
    deleteError = null;
    clearError = null;
    readDelay = null;
    writeDelay = null;
  }

  @override
  Future<void> write(String key, CacheEntry entry) async {
    writeCount++;
    _writeKeys.add(key);
    if (writeDelay != null) await Future<void>.delayed(writeDelay!);
    if (writeError != null) throw writeError!;
    _data[key] = entry;
  }

  @override
  Future<CacheEntry?> read(String key) async {
    readCount++;
    _readKeys.add(key);
    if (readDelay != null) await Future<void>.delayed(readDelay!);
    if (readError != null) throw readError!;
    return _data[key];
  }

  @override
  Future<void> delete(String key) async {
    deleteCount++;
    if (deleteError != null) throw deleteError!;
    _data.remove(key);
  }

  @override
  Future<void> clearAll() async {
    if (clearError != null) throw clearError!;
    _data.clear();
  }
}
