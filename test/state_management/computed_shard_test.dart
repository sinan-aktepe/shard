import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

class _Source extends Shard<int> {
  _Source(super.initial);
  void set(int v) => emit(v);
}

class _SumShard extends ComputedShard<int> {
  _SumShard(this.a, this.b) : super([a, b], 0);
  final _Source a;
  final _Source b;

  @override
  int compute() => a.state + b.state;
}

void main() {
  group('computedShard (function form)', () {
    test('computes the initial value from its sources', () {
      final a = _Source(2);
      final b = _Source(3);
      final c = computedShard([a, b], () => a.state + b.state);
      addTearDown(() {
        c.dispose();
        a.dispose();
        b.dispose();
      });
      expect(c.state, 5);
    });

    test('recomputes when any source notifies', () {
      final a = _Source(2);
      final b = _Source(3);
      final c = computedShard([a, b], () => a.state + b.state);
      addTearDown(() {
        c.dispose();
        a.dispose();
        b.dispose();
      });
      a.set(10);
      expect(c.state, 13);
      b.set(0);
      expect(c.state, 10);
    });

    test('does not notify when the computed value is unchanged', () {
      final a = _Source(1);
      final c = computedShard([a], () => a.state.isEven ? 'even' : 'odd');
      addTearDown(() {
        c.dispose();
        a.dispose();
      });
      var notifications = 0;
      c.addListener(() => notifications++);
      a.set(3); // still odd → unchanged → no notify
      expect(notifications, 0);
      a.set(4); // even → changes
      expect(notifications, 1);
    });

    test('dispose detaches source listeners (no recompute afterward)', () {
      final a = _Source(1);
      var computeCount = 0;
      final c = computedShard([a], () {
        computeCount++;
        return a.state;
      });
      final afterInit = computeCount;
      c.dispose();
      a.set(99);
      expect(computeCount, afterInit); // compute not invoked after dispose
      a.dispose();
    });
  });

  group('ComputedShard (subclass form)', () {
    test('computes from multiple sources and recomputes', () {
      final a = _Source(1);
      final b = _Source(2);
      final c = _SumShard(a, b);
      addTearDown(() {
        c.dispose();
        a.dispose();
        b.dispose();
      });
      expect(c.state, 3);
      a.set(10);
      expect(c.state, 12);
    });
  });
}
