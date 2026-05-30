import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/src/testing/mock_shard_observer.dart';

class _CounterShard extends Shard<int> {
  _CounterShard() : super(0);
  void inc() => emit(state + 1);
  void fail() => addError(Exception('boom'), StackTrace.current);
}

class _StringShard extends Shard<String> {
  _StringShard() : super('');
  void set(String v) => emit(v);
}

void main() {
  setUp(() {
    Shard.observer = null;
  });

  group('MockShardObserver', () {
    test('records onChange events', () {
      final observer = MockShardObserver();
      Shard.observer = observer;

      final shard = _CounterShard();
      shard.inc();
      shard.inc();

      expect(observer.recordedChanges, hasLength(2));
      expect(observer.recordedChanges[0].previousState, 0);
      expect(observer.recordedChanges[0].currentState, 1);
      expect(observer.recordedChanges[1].previousState, 1);
      expect(observer.recordedChanges[1].currentState, 2);

      shard.dispose();
    });

    test('records onError events', () {
      final observer = MockShardObserver();
      Shard.observer = observer;

      final shard = _CounterShard();
      shard.fail();

      expect(observer.recordedErrors, hasLength(1));
      expect(observer.recordedErrors.first.error, isA<Exception>());

      shard.dispose();
    });

    test('changesFor filters by shard identity', () {
      final observer = MockShardObserver();
      Shard.observer = observer;

      final a = _CounterShard();
      final b = _CounterShard();
      a.inc();
      b.inc();
      a.inc();

      expect(observer.changesFor(a), hasLength(2));
      expect(observer.changesFor(b), hasLength(1));

      a.dispose();
      b.dispose();
    });

    test('changesOfType filters by generic state type', () {
      final observer = MockShardObserver();
      Shard.observer = observer;

      final counter = _CounterShard();
      final text = _StringShard();
      counter.inc();
      text.set('hi');

      expect(observer.changesOfType<int>(), hasLength(1));
      expect(observer.changesOfType<String>(), hasLength(1));

      counter.dispose();
      text.dispose();
    });

    test('errorsFor filters by shard identity', () {
      final observer = MockShardObserver();
      Shard.observer = observer;

      final a = _CounterShard();
      final b = _CounterShard();
      a.fail();
      b.fail();
      a.fail();

      expect(observer.errorsFor(a), hasLength(2));
      expect(observer.errorsFor(b), hasLength(1));

      a.dispose();
      b.dispose();
    });

    test('errorsOfType filters by shard runtime type', () {
      final observer = MockShardObserver();
      Shard.observer = observer;

      final counter = _CounterShard();
      final text = _StringShard()..set('seed');
      counter.fail();

      expect(observer.errorsOfType<_CounterShard>(), hasLength(1));
      expect(observer.errorsOfType<_StringShard>(), isEmpty);

      counter.dispose();
      text.dispose();
    });

    test('clear empties recorded lists', () {
      final observer = MockShardObserver();
      Shard.observer = observer;

      final shard = _CounterShard();
      shard.inc();
      shard.fail();
      observer.clear();

      expect(observer.recordedChanges, isEmpty);
      expect(observer.recordedErrors, isEmpty);

      shard.dispose();
    });

    test('scope installs and restores observer', () async {
      final previous = _SilentObserver();
      Shard.observer = previous;

      final result = await MockShardObserver.scope((mock) async {
        expect(Shard.observer, same(mock));
        final shard = _CounterShard();
        shard.inc();
        addTearDown(shard.dispose);
        return mock.recordedChanges.length;
      });

      expect(result, 1);
      expect(Shard.observer, same(previous));
    });

    test('scope restores observer even when body throws', () async {
      final previous = _SilentObserver();
      Shard.observer = previous;

      await expectLater(
        MockShardObserver.scope<void>((_) async => throw StateError('boom')),
        throwsA(isA<StateError>()),
      );
      expect(Shard.observer, same(previous));
    });
  });
}

class _SilentObserver extends ShardObserver {}
