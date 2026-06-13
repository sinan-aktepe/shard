import 'shard.dart';

/// A [Shard] mixin that records state transitions and supports undo/redo.
///
/// Each state change (via `emit`/`emitForce`) pushes the previous state onto an
/// undo stack and clears the redo stack. [undo] and [redo] restore states using
/// `setStateInternal`, so restores are NOT re-recorded (no infinite stacks) but
/// still notify listeners and the global observer.
///
/// ```dart
/// class DocumentShard extends Shard<Document> with HistoryMixin<Document> {
///   DocumentShard() : super(Document.empty());
///   void edit(Document next) => emit(next);
/// }
///
/// final doc = DocumentShard()..edit(a)..edit(b);
/// doc.undo(); // back to a
/// doc.redo(); // forward to b
/// ```
///
/// **Ordering note:** if combined with `StatePersistenceMixin`, the two are
/// orthogonal — this mixin overrides `onChange` (to record) while persistence
/// overrides `emit` (to save) — but test the combination if you rely on both.
mixin HistoryMixin<T> on Shard<T> {
  final List<T> _undo = [];
  final List<T> _redo = [];
  bool _restoring = false;

  /// Maximum number of retained undo entries. When exceeded, the oldest entry
  /// is dropped. Defaults to 50.
  int maxHistory = 50;

  /// Whether there is at least one state to [undo] to.
  bool get canUndo => _undo.isNotEmpty;

  /// Whether there is at least one state to [redo] to.
  bool get canRedo => _redo.isNotEmpty;

  @override
  void onChange(T previousState, T currentState) {
    if (!_restoring) {
      _undo.add(previousState);
      if (_undo.length > maxHistory) _undo.removeAt(0);
      _redo.clear();
    }
    super.onChange(previousState, currentState);
  }

  /// Restores the previous state, moving the current state onto the redo stack.
  /// A no-op if there is nothing to undo.
  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(state);
    _restoring = true;
    setStateInternal(_undo.removeLast());
    _restoring = false;
  }

  /// Re-applies the most recently undone state. A no-op if there is nothing to
  /// redo.
  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(state);
    _restoring = true;
    setStateInternal(_redo.removeLast());
    _restoring = false;
  }

  /// Clears both the undo and redo stacks.
  void clearHistory() {
    _undo.clear();
    _redo.clear();
  }
}
