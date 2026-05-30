import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../state_management/shard.dart';
import '../state_management/shard_observer.dart';

/// A [ShardObserver] that logs state changes and errors during debug builds.
///
/// By default, [enabled] is set to [kDebugMode], so the observer is inert in
/// release builds — no formatting cost and no risk of leaking PII-containing
/// state values through logs. Pass `enabled: true` to force logging on.
///
/// The default sink is `dart:developer.log(name: 'shard')`, which integrates
/// with the Flutter DevTools Logging tab. Provide a [printer] to route messages
/// to a custom sink (Crashlytics, Sentry, file logger, etc.).
///
/// ## Usage
///
/// ```dart
/// void main() {
///   Shard.observer = LoggingObserver();
///   runApp(MyApp());
/// }
/// ```
///
/// Filter specific shards:
///
/// ```dart
/// Shard.observer = LoggingObserver(
///   shouldLog: (shard) => shard is! NoisyShard,
/// );
/// ```
class LoggingObserver extends ShardObserver {
  /// Creates a [LoggingObserver].
  ///
  /// - [enabled] - If null, defaults to [kDebugMode] (release builds: inert).
  ///   Pass `true` to force on; pass `false` to silence in every environment.
  /// - [logChanges] - Whether to log `onChange` events. Default `true`.
  /// - [logErrors] - Whether to log `onError` events. Default `true`.
  /// - [includeStackTrace] - Append stack trace to error logs. Default `false`.
  /// - [printer] - Optional custom sink. Default uses `dart:developer.log`.
  /// - [shouldLog] - Optional predicate; return false to skip a shard.
  LoggingObserver({
    bool? enabled,
    this.logChanges = true,
    this.logErrors = true,
    this.includeStackTrace = false,
    this.printer,
    this.shouldLog,
  }) : enabled = enabled ?? kDebugMode;

  /// Whether this observer emits any log lines.
  final bool enabled;

  /// Whether `onChange` events are logged.
  final bool logChanges;

  /// Whether `onError` events are logged.
  final bool logErrors;

  /// Whether to append the stack trace to error log lines.
  final bool includeStackTrace;

  /// Custom log sink. When null, uses `dart:developer.log(name: 'shard')`.
  final void Function(String message)? printer;

  /// Optional filter; return false to skip logging a specific shard.
  final bool Function(Shard shard)? shouldLog;

  @override
  void onChange<T>(Shard<T> shard, T previousState, T currentState) {
    if (!enabled || !logChanges) return;
    if (shouldLog != null && !shouldLog!(shard)) return;
    _write('[${shard.runtimeType}] $previousState → $currentState');
  }

  @override
  void onError<T>(Shard<T> shard, Object error, StackTrace? stackTrace) {
    if (!enabled || !logErrors) return;
    if (shouldLog != null && !shouldLog!(shard)) return;
    final trace = includeStackTrace && stackTrace != null ? '\n$stackTrace' : '';
    _write('[${shard.runtimeType}] ERROR: $error$trace');
  }

  void _write(String message) {
    if (printer != null) {
      printer!(message);
    } else {
      developer.log(message, name: 'shard');
    }
  }
}
