import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

class _Person {
  _Person(this.name, this.age);
  String name;
  int age;
}

class _PersonShard extends Shard<_Person> {
  _PersonShard() : super(_Person('Alice', 30));
  void rename(String n) => emit(_Person(n, state.age));
  void age() => emit(_Person(state.name, state.age + 1));
}

class _NicknameShard extends Shard<String?> {
  _NicknameShard() : super(null);
  void set(String? value) => emit(value);
}

void main() {
  testWidgets('rebuilds only when selected value changes', (tester) async {
    final shard = _PersonShard();
    addTearDown(shard.dispose);
    var builds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ShardSelector<_PersonShard, _Person, String>(
          shard: shard,
          selector: (p) => p.name,
          builder: (_, name) {
            builds++;
            return Text(name, textDirection: TextDirection.ltr);
          },
        ),
      ),
    );
    final initialBuilds = builds;
    expect(find.text('Alice'), findsOneWidget);

    shard.age(); // selected value (name) unchanged
    await tester.pump();
    expect(builds, initialBuilds);

    shard.rename('Bob');
    await tester.pump();
    expect(builds, initialBuilds + 1);
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('recomputes when the selector changes on rebuild', (
    tester,
  ) async {
    final shard = _PersonShard(); // Alice, 30
    addTearDown(shard.dispose);

    late StateSetter setOuter;
    var selectName = true;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setOuter = setState;
            return ShardSelector<_PersonShard, _Person, String>(
              shard: shard,
              selector: (p) => selectName ? p.name : '${p.age}',
              builder: (_, value) =>
                  Text(value, textDirection: TextDirection.ltr),
            );
          },
        ),
      ),
    );
    expect(find.text('Alice'), findsOneWidget);

    // Same shard, new selector closure: the shown value must reflect the
    // new selector without waiting for the next emit.
    setOuter(() => selectName = false);
    await tester.pump();
    expect(find.text('30'), findsOneWidget);
  });

  testWidgets('swapping the shard prop rebinds the selector', (tester) async {
    final a = _PersonShard(); // Alice
    final b = _PersonShard()..rename('Bob');
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    late StateSetter setOuter;
    var useA = true;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setOuter = setState;
            return ShardSelector<_PersonShard, _Person, String>(
              shard: useA ? a : b,
              selector: (p) => p.name,
              builder: (_, name) =>
                  Text(name, textDirection: TextDirection.ltr),
            );
          },
        ),
      ),
    );
    expect(find.text('Alice'), findsOneWidget);

    setOuter(() => useA = false);
    await tester.pump();
    expect(find.text('Bob'), findsOneWidget);

    // The old shard must no longer drive rebuilds.
    a.rename('Zed');
    await tester.pump();
    expect(find.text('Bob'), findsOneWidget);

    // The new shard must.
    b.rename('Cy');
    await tester.pump();
    expect(find.text('Cy'), findsOneWidget);
  });

  testWidgets('builds even when the selected value is null', (tester) async {
    final shard = _NicknameShard();
    addTearDown(shard.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ShardSelector<_NicknameShard, String?, String?>(
          shard: shard,
          selector: (nickname) => nickname,
          builder: (_, nickname) =>
              Text(nickname ?? 'none', textDirection: TextDirection.ltr),
        ),
      ),
    );

    // Initial selected value is null — the builder must still run.
    expect(find.text('none'), findsOneWidget);

    shard.set('Ace');
    await tester.pump();
    expect(find.text('Ace'), findsOneWidget);

    // Transition back to null must rebuild with the null value, not blank out.
    shard.set(null);
    await tester.pump();
    expect(find.text('none'), findsOneWidget);
  });
}
