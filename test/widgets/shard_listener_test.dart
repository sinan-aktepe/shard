import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

class _Counter extends Shard<int> {
  _Counter() : super(0);
  void inc() => emit(state + 1);
}

void main() {
  testWidgets('listener fires with (prev, curr) and does not rebuild child',
      (tester) async {
    final shard = _Counter();
    addTearDown(shard.dispose);
    final calls = <(int, int)>[];
    var childBuilds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ShardListener<_Counter, int>(
          shard: shard,
          listener: (context, prev, curr) => calls.add((prev, curr)),
          child: Builder(
            builder: (_) {
              childBuilds++;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(childBuilds, 1);
    shard.inc();
    await tester.pump();
    expect(calls, [(0, 1)]);
    expect(childBuilds, 1); // listener did not rebuild the child
  });

  testWidgets('listenWhen returning false suppresses the listener',
      (tester) async {
    final shard = _Counter();
    addTearDown(shard.dispose);
    var fired = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ShardListener<_Counter, int>(
          shard: shard,
          listenWhen: (p, c) => false,
          listener: (context, p, c) => fired++,
          child: const SizedBox(),
        ),
      ),
    );

    shard.inc();
    await tester.pump();
    expect(fired, 0);
  });

  testWidgets('rebinds when a different shard instance is supplied',
      (tester) async {
    final a = _Counter();
    final b = _Counter();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    final observed = <int>[];

    Widget build(_Counter s) => MaterialApp(
          home: ShardListener<_Counter, int>(
            shard: s,
            listener: (context, p, c) => observed.add(c),
            child: const SizedBox(),
          ),
        );

    await tester.pumpWidget(build(a));
    await tester.pumpWidget(build(b)); // swap shard instance

    b.inc();
    await tester.pump();
    expect(observed, [1]); // b's change observed

    a.inc();
    await tester.pump();
    expect(observed, [1]); // a is no longer listened to
  });

  testWidgets('MultiShardListener fires every nested listener', (tester) async {
    final a = _Counter();
    final b = _Counter();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    var aFired = 0;
    var bFired = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MultiShardListener(
          listeners: [
            ShardListener<_Counter, int>(
              shard: a,
              listener: (c, p, n) => aFired++,
            ),
            ShardListener<_Counter, int>(
              shard: b,
              listener: (c, p, n) => bFired++,
            ),
          ],
          child: const SizedBox(),
        ),
      ),
    );

    a.inc();
    b.inc();
    await tester.pump();
    expect(aFired, 1);
    expect(bFired, 1);
  });
}
