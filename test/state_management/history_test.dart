import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/shard_test.dart';

class _Editor extends Shard<String> with HistoryMixin<String> {
  _Editor() : super('');
  void type(String s) => emit(s);
}

void main() {
  group('HistoryMixin', () {
    test('undo restores the previous state and enables redo', () {
      final e = _Editor();
      addTearDown(e.dispose);
      e.type('a');
      e.type('ab');
      expect(e.canUndo, isTrue);

      e.undo();
      expect(e.state, 'a');
      expect(e.canRedo, isTrue);

      e.undo();
      expect(e.state, '');

      e.redo();
      expect(e.state, 'a');
    });

    test('a new emit after undo clears the redo stack', () {
      final e = _Editor();
      addTearDown(e.dispose);
      e.type('a');
      e.type('b');
      e.undo(); // -> 'a', redo holds 'b'
      expect(e.canRedo, isTrue);

      e.type('c'); // a fresh change clears redo
      expect(e.canRedo, isFalse);
      expect(e.state, 'c');
    });

    test('maxHistory bounds the undo stack, dropping the oldest', () {
      final e = _Editor();
      addTearDown(e.dispose);
      e.maxHistory = 2;
      e.type('1'); // undo: ['']
      e.type('2'); // undo: ['', '1']
      e.type('3'); // undo: ['', '1', '2'] -> bounded -> ['1', '2']

      e.undo(); // -> '2'
      e.undo(); // -> '1'
      expect(e.state, '1');
      expect(e.canUndo, isFalse); // '' was dropped
    });

    test('undo/redo are not recorded as new history entries', () {
      final e = _Editor();
      addTearDown(e.dispose);
      e.type('a');
      e.type('b');
      e.undo(); // 'a'
      e.undo(); // ''
      expect(e.canUndo, isFalse); // exactly two undos, no extra recording
    });

    test('clearHistory empties both stacks', () {
      final e = _Editor();
      addTearDown(e.dispose);
      e.type('a');
      e.undo();
      e.clearHistory();
      expect(e.canUndo, isFalse);
      expect(e.canRedo, isFalse);
    });

    test('observer is notified on undo and redo', () async {
      await MockShardObserver.scope((observer) async {
        final e = _Editor();
        e.type('a');
        e.type('b');
        final before = observer.changesFor(e).length;
        e.undo();
        expect(observer.changesFor(e).length, before + 1);
        e.redo();
        expect(observer.changesFor(e).length, before + 2);
        e.dispose();
      });
    });
  });
}
