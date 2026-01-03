/// Represents the state of an asynchronous operation.
///
/// [AsyncValue] is a sealed class that can be one of three states:
/// - [AsyncLoading] - The operation is in progress
/// - [AsyncData] - The operation completed successfully with data
/// - [AsyncError] - The operation failed with an error
///
///
/// See also:
/// - [FutureShard] for Future-based async state management
/// - [StreamShard] for Stream-based async state management
sealed class AsyncValue<T> {
  const AsyncValue();

  /// Whether this value is currently loading.
  bool get isLoading => this is AsyncLoading<T>;

  /// Whether this value has data (successfully loaded).
  bool get hasData => this is AsyncData<T>;

  /// Whether this value has an error.
  bool get hasError => this is AsyncError<T>;

  /// Returns the data if available, otherwise null.
  ///
  /// For [AsyncLoading] and [AsyncError], returns the previous data if available.
  T? get dataOrNull => switch (this) {
    AsyncData<T>(:final data) => data,
    AsyncLoading<T>(:final previousData) => previousData,
    AsyncError<T>(:final previousData) => previousData,
  };

  /// Returns the error if this is an [AsyncError], otherwise null.
  Object? get errorOrNull =>
      this is AsyncError<T> ? (this as AsyncError<T>).error : null;

  /// Returns the stack trace if this is an [AsyncError], otherwise null.
  StackTrace? get stackTraceOrNull =>
      this is AsyncError<T> ? (this as AsyncError<T>).stackTrace : null;
}

/// Represents a loading state for an asynchronous operation.
///
/// Optionally holds [previousData] from a previous successful load,
/// which can be useful for showing stale data while refreshing.
///
/// ```dart
/// final loading = AsyncLoading<int>();
/// final refreshing = AsyncLoading<int>(previousData: 42);
/// ```
final class AsyncLoading<T> extends AsyncValue<T> {
  /// Previous data from a successful load, if available.
  ///
  /// This is useful for showing stale data while refreshing.
  final T? previousData;

  /// Creates a loading state.
  ///
  /// Optionally provide [previousData] to retain the last known value.
  const AsyncLoading({this.previousData});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AsyncLoading<T> && other.previousData == previousData;

  @override
  int get hashCode => previousData.hashCode;

  @override
  String toString() => 'AsyncLoading<$T>(previousData: $previousData)';
}

/// Represents a successful data state for an asynchronous operation.
///
/// ```dart
/// final result = AsyncData<int>(42);
/// print(result.data); // 42
/// ```
final class AsyncData<T> extends AsyncValue<T> {
  /// The successfully loaded data.
  final T data;

  /// Creates a data state with the given [data].
  const AsyncData(this.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AsyncData<T> && other.data == data;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'AsyncData<$T>(data: $data)';
}

/// Represents an error state for an asynchronous operation.
///
/// Holds the [error] and optional [stackTrace], and can optionally
/// retain [previousData] from a previous successful load.
///
/// ```dart
/// final error = AsyncError<int>(
///   Exception('Failed'),
///   StackTrace.current,
///   previousData: 42,
/// );
/// ```
final class AsyncError<T> extends AsyncValue<T> {
  /// The error that occurred.
  final Object error;

  /// The stack trace associated with the error, if available.
  final StackTrace? stackTrace;

  /// Previous data from a successful load, if available.
  ///
  /// This is useful for showing stale data alongside an error message.
  final T? previousData;

  /// Creates an error state with the given [error] and optional [stackTrace].
  ///
  /// Optionally provide [previousData] to retain the last known value.
  const AsyncError(this.error, [this.stackTrace, this.previousData]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AsyncError<T> &&
          other.error == error &&
          other.previousData == previousData;

  @override
  int get hashCode => Object.hash(error, previousData);

  @override
  String toString() =>
      'AsyncError<$T>(error: $error, previousData: $previousData)';
}
