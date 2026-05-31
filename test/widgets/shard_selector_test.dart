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
}
