import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

class _Counter extends Shard<int> {
  _Counter() : super(0);
  void inc() => emit(state + 1);
}

void main() {
  testWidgets('context.read returns the provided shard', (tester) async {
    late _Counter captured;
    await tester.pumpWidget(
      MaterialApp(
        home: ShardProvider<_Counter>(
          create: () => _Counter(),
          child: Builder(builder: (context) {
            captured = context.read<_Counter>();
            return const SizedBox();
          }),
        ),
      ),
    );
    expect(captured.state, 0);
  });

  testWidgets('context.read does NOT cause rebuilds on emit', (tester) async {
    var builds = 0;
    late _Counter shard;

    await tester.pumpWidget(
      MaterialApp(
        home: ShardProvider<_Counter>(
          create: () => _Counter(),
          child: Builder(builder: (context) {
            builds++;
            shard = context.read<_Counter>();
            return const SizedBox();
          }),
        ),
      ),
    );
    final initial = builds;

    shard.inc();
    await tester.pump();
    expect(builds, initial); // no rebuild
  });
}
