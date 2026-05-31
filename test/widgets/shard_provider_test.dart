import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

class _LifecycleShard extends Shard<int> {
  _LifecycleShard() : super(0);
  int initCount = 0;
  int disposeCount = 0;

  @override
  void onInit() {
    super.onInit();
    initCount++;
  }

  @override
  void dispose() {
    disposeCount++;
    super.dispose();
  }
}

class _CounterShard extends Shard<int> {
  _CounterShard() : super(0);
  void inc() => emit(state + 1);
}

void main() {
  testWidgets('create constructor: onInit called, dispose called on removal',
      (tester) async {
    late _LifecycleShard captured;
    await tester.pumpWidget(
      MaterialApp(
        home: ShardProvider<_LifecycleShard>(
          create: () => _LifecycleShard(),
          child: Builder(builder: (context) {
            captured = ShardProvider.of<_LifecycleShard>(context, listen: false);
            return const SizedBox();
          }),
        ),
      ),
    );

    expect(captured.initCount, 1);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(captured.disposeCount, 1);
  });

  testWidgets('value constructor: dispose NOT called on removal',
      (tester) async {
    final external = _LifecycleShard();
    await tester.pumpWidget(
      MaterialApp(
        home: ShardProvider<_LifecycleShard>.value(
          value: external,
          child: const SizedBox(),
        ),
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(external.disposeCount, 0);
    expect(external.initCount, 0); // value constructor does NOT call onInit
    external.dispose();
  });

  testWidgets('of(listen: true) does NOT rebuild on emit', (tester) async {
    // Shard package intentionally has no implicit context.watch subscription.
    // Rebuilds happen exclusively via ShardBuilder/ShardSelector.
    final shard = _CounterShard();
    int buildCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ShardProvider<_CounterShard>.value(
          value: shard,
          child: Builder(builder: (context) {
            buildCount++;
            final s = ShardProvider.of<_CounterShard>(context, listen: true);
            return Text('${s.state}', textDirection: TextDirection.ltr);
          }),
        ),
      ),
    );

    expect(buildCount, 1);
    expect(find.text('0'), findsOneWidget);

    shard.inc();
    await tester.pump();

    expect(buildCount, 1);
    expect(find.text('0'), findsOneWidget);

    shard.dispose();
  });

  testWidgets('of(listen: false) does NOT rebuild on emit', (tester) async {
    final shard = _CounterShard();
    int buildCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ShardProvider<_CounterShard>.value(
          value: shard,
          child: Builder(builder: (context) {
            buildCount++;
            final s = ShardProvider.of<_CounterShard>(context, listen: false);
            return Text('${s.state}', textDirection: TextDirection.ltr);
          }),
        ),
      ),
    );

    expect(buildCount, 1);
    expect(find.text('0'), findsOneWidget);

    shard.inc();
    await tester.pump();

    expect(buildCount, 1);
    expect(find.text('0'), findsOneWidget);

    shard.dispose();
  });

  testWidgets('of() throws when no provider above', (tester) async {
    Object? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(builder: (context) {
          try {
            ShardProvider.of<_LifecycleShard>(context);
          } catch (e) {
            captured = e;
          }
          return const SizedBox();
        }),
      ),
    );
    expect(captured, isA<AssertionError>());
  });
}
