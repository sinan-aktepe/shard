import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/shard_test.dart';

class _CounterShard extends Shard<int> {
  _CounterShard([super.initial = 0]);
  void inc() => emit(state + 1);
  void setTo(int v) => emit(v);
  void force(int v) => emitForce(v);
  void boom() => addError(Exception('boom'), StackTrace.current);
}

void main() {
  setUp(() {
    Shard.observer = null;
  });

  group('Shard base behavior', () {
    test('initial state is set from constructor', () {
      final s = _CounterShard(7);
      expect(s.state, 7);
      s.dispose();
    });

    test('emit triggers notifyListeners', () {
      final s = _CounterShard();
      var notifications = 0;
      s.addListener(() => notifications++);
      s.inc();
      s.inc();
      expect(notifications, 2);
      s.dispose();
    });

    test('emit skips no-op when state equals current', () async {
      await shardTest<_CounterShard, int>(
        build: () => _CounterShard(5),
        act: (shard) async => shard.setTo(5),
        expect: [],
      );
    });

    test('emitForce bypasses equality and notifies', () async {
      await shardTest<_CounterShard, int>(
        build: () => _CounterShard(5),
        act: (shard) async => shard.force(5),
        expect: [5],
      );
    });

    test('dispose flips isDisposed', () {
      final s = _CounterShard();
      expect(s.isDisposed, isFalse);
      s.dispose();
      expect(s.isDisposed, isTrue);
    });

    test('post-dispose emit is a no-op', () async {
      final s = _CounterShard();
      final tester = ShardTester(s);
      s.dispose();
      // Calling inc() will hit ChangeNotifier's disposed check; wrap in
      // try to ignore the assertion error and verify no state recorded.
      try {
        s.inc();
      } catch (_) {}
      expect(tester.recordedStates, isEmpty);
      await tester.dispose();
    });

    test('addError calls onError', () async {
      await MockShardObserver.scope((observer) async {
        final s = _CounterShard();
        addTearDown(s.dispose);
        s.boom();
        expect(observer.errorsFor(s), hasLength(1));
        expect(observer.errorsFor(s).first.error, isA<Exception>());
      });
    });

    test('observer receives onChange events', () async {
      await MockShardObserver.scope((observer) async {
        final s = _CounterShard();
        addTearDown(s.dispose);
        s.inc();
        s.inc();
        expect(observer.changesFor(s), hasLength(2));
        expect(observer.changesFor(s).first.previousState, 0);
        expect(observer.changesFor(s).first.currentState, 1);
      });
    });
  });

  group('stream', () {
    test('emits each post-subscription state in order', () async {
      final shard = _CounterShard();
      addTearDown(shard.dispose);
      final expectation = expectLater(shard.stream, emitsInOrder([1, 2, 3]));
      shard.setTo(1);
      shard.setTo(2);
      shard.setTo(3);
      await expectation;
    });

    test('does not replay the current state to a new listener', () async {
      final shard = _CounterShard();
      addTearDown(shard.dispose);
      shard.setTo(5); // before any subscription
      final expectation = expectLater(shard.stream, emitsInOrder([6]));
      shard.setTo(6);
      await expectation;
    });

    test('closes on dispose', () async {
      final shard = _CounterShard();
      final expectation = expectLater(shard.stream, emitsDone);
      shard.dispose();
      await expectation;
    });

    test('is broadcast: multiple listeners receive events', () async {
      final shard = _CounterShard();
      addTearDown(shard.dispose);
      final a = expectLater(shard.stream, emits(1));
      final b = expectLater(shard.stream, emits(1));
      shard.setTo(1);
      await Future.wait([a, b]);
    });
  });
}
