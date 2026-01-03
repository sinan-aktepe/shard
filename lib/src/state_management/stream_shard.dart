import 'dart:async';

import 'package:flutter/material.dart';

import 'async_value.dart';
import 'shard.dart';

/// A [Shard] that manages asynchronous state from a [Stream].
///
/// [StreamShard] automatically subscribes to the [Stream] returned by [build]
/// when initialized and manages the loading, data, and error states through
/// [AsyncValue].
///
/// ## Creating a StreamShard
///
/// ```dart
/// class MessagesStream extends StreamShard<List<Message>> {
///   final ChatRepository repository;
///   final String chatId;
///
///   MessagesStream({required this.repository, required this.chatId});
///
///   @override
///   Stream<List<Message>> build() {
///     return repository.watchMessages(chatId);
///   }
/// }
/// ```
///
/// ## Usage in UI
///
/// ```dart
/// AsyncShardBuilder<MessagesStream, List<Message>>(
///   onLoading: (context) => CircularProgressIndicator(),
///   onData: (context, messages) => MessageList(messages: messages),
///   onError: (context, error, stackTrace) => Text('Error: $error'),
/// )
/// ```
///
/// ## Refreshing Stream
///
/// Call [refresh] to cancel the current subscription and re-subscribe:
///
/// ```dart
/// final messagesStream = context.read<MessagesStream>();
/// messagesStream.refresh();
/// ```
///
/// See also:
/// - [FutureShard] for Future-based async state management
/// - [AsyncValue] for the state representation
/// - [AsyncShardBuilder] for building UI based on async state
abstract class StreamShard<T> extends Shard<AsyncValue<T>> {
  StreamSubscription<T>? _subscription;

  /// Creates a [StreamShard] with an initial loading state.
  StreamShard() : super(AsyncLoading<T>());

  /// Builds and returns the [Stream] that produces the data.
  ///
  /// This method is called automatically when the shard is initialized
  /// and when [refresh] is called.
  ///
  /// Override this method to define the stream source:
  ///
  /// ```dart
  /// @override
  /// Stream<List<Message>> build() {
  ///   return firestore.collection('messages').snapshots();
  /// }
  /// ```
  @protected
  Stream<T> build();

  /// Cancels the current subscription and re-subscribes to [build].
  ///
  /// The state transitions to [AsyncLoading] (retaining previous data)
  /// before subscribing again.
  ///
  /// ```dart
  /// void onRefreshPressed() {
  ///   myShard.refresh();
  /// }
  /// ```
  void refresh() {
    if (isDisposed) return;
    _subscription?.cancel();
    emit(AsyncLoading<T>(previousData: state.dataOrNull));
    _subscribe();
  }

  /// Called when the shard is initialized.
  ///
  /// Automatically subscribes to the stream by calling [build].
  @override
  @mustCallSuper
  void onInit() {
    super.onInit();
    _subscribe();
  }

  void _subscribe() {
    _subscription = build().listen(
      (data) {
        if (isDisposed) return;
        emit(AsyncData<T>(data));
      },
      onError: (Object e, StackTrace st) {
        if (isDisposed) return;
        addError(e, st);
        emit(AsyncError<T>(e, st, state.dataOrNull));
      },
    );
  }

  /// Disposes the shard and cancels the stream subscription.
  @override
  @mustCallSuper
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
