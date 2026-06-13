import 'async_value.dart';
import 'shard.dart';

/// A [Shard] that runs a single asynchronous action and exposes its lifecycle
/// as an [AsyncValue]: [AsyncIdle] (not started) → [AsyncLoading] (running) →
/// [AsyncData] (success) / [AsyncError] (failure).
///
/// Where [FutureShard] models a *read* that runs automatically, [CommandShard]
/// models a *write/action* — a form submit, a create/update/delete, a "send"
/// button — triggered explicitly via [execute]. It provides an idle→running→
/// success/failure lifecycle, a double-submit guard, and error capture, without
/// writing a bespoke [Shard] each time.
///
/// Because its state is an [AsyncValue], it renders with [AsyncShardBuilder]
/// (use the `onIdle:` builder for the not-yet-run state) and plugs into
/// `ShardProvider` / `context.read` like any [Shard].
///
/// ```dart
/// final submit = CommandShard<LoginForm, User>((form) => api.login(form));
///
/// // In a callback:
/// final user = await submit.execute(form);
/// if (user != null) navigator.goHome();
///
/// // In the widget tree:
/// AsyncShardBuilder<CommandShard<LoginForm, User>, User>(
///   shard: submit,
///   onIdle: (_) => const Text('Ready'),
///   onData: (_, user) => Text('Welcome, ${user.name}'),
/// )
/// ```
///
/// For an action that takes no argument, use `CommandShard<void, Res>` and call
/// `execute(null)`.
class CommandShard<Arg, Res> extends Shard<AsyncValue<Res>> {
  /// Creates a command that runs [action] when [execute] is called.
  ///
  /// Starts in the [AsyncIdle] state.
  CommandShard(this._action) : super(AsyncIdle<Res>());

  final Future<Res> Function(Arg arg) _action;

  /// Whether the action is currently running.
  bool get isRunning => state.isLoading;

  /// The current result if the last run succeeded; null when idle, running,
  /// errored, or after [reset].
  Res? get valueOrNull => state.dataOrNull;

  /// Runs the action with [arg].
  ///
  /// Emits [AsyncLoading] (retaining any previous data), then [AsyncData] on
  /// success or [AsyncError] on failure (failures are also routed through
  /// [addError]). Ignored if a run is already in progress (double-submit guard)
  /// or the shard is disposed.
  ///
  /// Returns the result on success, or null on failure / when ignored.
  Future<Res?> execute(Arg arg) async {
    if (state.isLoading || isDisposed) return null;
    emit(AsyncLoading<Res>(previousData: state.dataOrNull));
    try {
      final result = await _action(arg);
      if (isDisposed) return null;
      emit(AsyncData<Res>(result));
      return result;
    } catch (e, st) {
      if (isDisposed) return null;
      addError(e, st);
      // `state` is still AsyncLoading here, so dataOrNull returns the pre-run
      // value — exactly the previousData we want to carry onto the error.
      emit(AsyncError<Res>(e, st, state.dataOrNull));
      return null;
    }
  }

  /// Resets the command back to [AsyncIdle]. After this, [valueOrNull] is null.
  void reset() => emit(AsyncIdle<Res>());
}
