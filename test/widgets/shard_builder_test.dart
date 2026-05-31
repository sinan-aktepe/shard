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
          builder: (context, count) => Text('$count', textDirection: TextDirection.ltr),
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
