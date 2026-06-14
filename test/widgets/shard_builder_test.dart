import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

class _Counter extends Shard<int> {
  _Counter() : super(0);
  void inc() => emit(state + 1);
}

void main() {
  testWidgets('rebuilds on every state change', (tester) async {
    final shard = _Counter();
    addTearDown(shard.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ShardBuilder<_Counter, int>(
          shard: shard,
          builder: (context, count) =>
              Text('$count', textDirection: TextDirection.ltr),
        ),
      ),
    );
    expect(find.text('0'), findsOneWidget);

    shard.inc();
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('buildWhen suppresses unwanted rebuilds', (tester) async {
    final shard = _Counter();
    addTearDown(shard.dispose);
    var builds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ShardBuilder<_Counter, int>(
          shard: shard,
          buildWhen: (prev, curr) => curr.isEven,
          builder: (context, count) {
            builds++;
            return Text('$count', textDirection: TextDirection.ltr);
          },
        ),
      ),
    );
    final initialBuilds = builds;

    shard.inc(); // 1 (odd) — should not rebuild
    await tester.pump();
    expect(builds, initialBuilds);

    shard.inc(); // 2 (even) — should rebuild
    await tester.pump();
    expect(builds, initialBuilds + 1);
  });

  testWidgets('listener fires on state change', (tester) async {
    final shard = _Counter();
    addTearDown(shard.dispose);
    final events = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ShardBuilder<_Counter, int>(
          shard: shard,
          listener: (prev, curr) => events.add(curr),
          builder: (context, _) => const SizedBox(),
        ),
      ),
    );

    shard.inc();
    await tester.pump();
    shard.inc();
    await tester.pump();
    expect(events, [1, 2]);
  });

  testWidgets('swapping the shard prop rebinds the listener', (tester) async {
    final a = _Counter()..inc(); // a.state == 1
    final b = _Counter()
      ..inc()
      ..inc(); // b.state == 2
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    late StateSetter setOuter;
    var useA = true;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setOuter = setState;
            return ShardBuilder<_Counter, int>(
              shard: useA ? a : b,
              builder: (context, count) =>
                  Text('$count', textDirection: TextDirection.ltr),
            );
          },
        ),
      ),
    );
    expect(find.text('1'), findsOneWidget);

    setOuter(() => useA = false);
    await tester.pump();
    expect(find.text('2'), findsOneWidget);

    // The old shard must no longer drive rebuilds.
    a.inc();
    await tester.pump();
    expect(find.text('2'), findsOneWidget);

    // The new shard must.
    b.inc();
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('listenWhen filters listener calls', (tester) async {
    final shard = _Counter();
    addTearDown(shard.dispose);
    final events = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ShardBuilder<_Counter, int>(
          shard: shard,
          listenWhen: (prev, curr) => curr > 1,
          listener: (prev, curr) => events.add(curr),
          builder: (context, _) => const SizedBox(),
        ),
      ),
    );

    shard.inc(); // 1 — filtered
    await tester.pump();
    shard.inc(); // 2 — emitted
    await tester.pump();
    expect(events, [2]);
  });
}
