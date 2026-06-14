/// Represents a cached data entry with an expiration time.
///
/// [CacheEntry] wraps any data along with an [expiryDate] to determine
/// when the cached data becomes stale.
///
/// ## Example
///
/// ```dart
/// final entry = CacheEntry(
///   data: {'name': 'John', 'age': 30},
///   expiryDate: DateTime.now().add(Duration(hours: 1)),
/// );
///
/// if (entry.isExpired) {
///   // Refresh the cache
/// }
/// ```
class CacheEntry {
  /// The cached data. Can be any JSON-serializable value.
  final dynamic data;

  /// The date and time when this cache entry expires.
  final DateTime expiryDate;

  /// Creates a new cache entry.
  ///
  /// - [data]: The data to cache
  /// - [expiryDate]: When this entry should be considered expired
  CacheEntry({required this.data, required this.expiryDate});

  /// Serializes this entry to a JSON-compatible map.
  ///
  /// The [expiryDate] is encoded as an ISO 8601 string; [data] is included
  /// as-is, so it must itself be JSON-serializable for the result to round-trip
  /// through [CacheEntry.fromJson].
  Map<String, dynamic> toJson() => {
    'data': data,
    'expiryDate': expiryDate.toIso8601String(),
  };

  /// Reconstructs a [CacheEntry] from a JSON map produced by [toJson].
  ///
  /// The `'expiryDate'` field is parsed back into a [DateTime]; `'data'` is
  /// returned unchanged.
  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      data: json['data'],
      expiryDate: DateTime.parse(json['expiryDate']),
    );
  }

  /// Whether this cache entry has passed its [expiryDate].
  bool get isExpired => DateTime.now().isAfter(expiryDate);
}
