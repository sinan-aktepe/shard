import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/shard_test.dart';

class _CounterShard extends Shard<int> {
  _CounterShard() : super(0);
  void inc() => emit(state + 1);
  void boom() => addError(Exception('x'), StackTrace.current);
}

void main() {
  setUp(() {
    Shard.observer = null;
  });

  test('default observer is null; no exceptions on change/error', () {
    final s = _CounterShard();
    s.inc();
    s.boom();
    s.dispose();
  });

  test('onChange fires on emit', () async {
    await MockShardObserver.scope((observer) async {
      final s = _CounterShard();
      addTearDown(s.dispose);
      s.inc();
      expect(observer.recordedChanges, hasLength(1));
    });
  });

  test('onError fires on addError', () async {
    await MockShardObserver.scope((observer) async {
      final s = _CounterShard();
      addTearDown(s.dispose);
      s.boom();
      expect(observer.recordedErrors, hasLength(1));
    });
  });

  test('multiple shards share the same observer', () async {
    await MockShardObserver.scope((observer) async {
      final a = _CounterShard();
      final b = _CounterShard();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      a.inc();
      b.inc();
      expect(observer.changesOfType<int>(), hasLength(2));
    });
  });

  test('swapping observers takes effect immediately', () {
    final firstChanges = <int>[];
    final secondChanges = <int>[];
    Shard.observer = _RecordingObserver(firstChanges);

    final s = _CounterShard();
    addTearDown(s.dispose);
    s.inc(); // recorded to first
    Shard.observer = _RecordingObserver(secondChanges);
    s.inc(); // recorded to second

    expect(firstChanges, [1]);
    expect(secondChanges, [2]);
  });
}

class _RecordingObserver extends ShardObserver {
  _RecordingObserver(this.target);
  final List<int> target;

  @override
  void onChange<T>(Shard<T> shard, T previousState, T currentState) {
    if (currentState is int) target.add(currentState);
  }
}
