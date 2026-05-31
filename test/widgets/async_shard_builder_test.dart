import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

class _ManualAsyncShard extends Shard<AsyncValue<String>> {
  _ManualAsyncShard() : super(const AsyncLoading<String>());
  void setData(String d) => emit(AsyncData<String>(d));
  void setError(Object e) => emit(AsyncError<String>(e));
  void setLoading({String? previousData}) =>
      emit(AsyncLoading<String>(previousData: previousData));
}

void main() {
  testWidgets('shows onLoading widget initially', (tester) async {
    final shard = _ManualAsyncShard();
    addTearDown(shard.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AsyncShardBuilder<_ManualAsyncShard, String>(
          shard: shard,
          onLoading: (_) => const Text('LOADING', textDirection: TextDirection.ltr),
          onData: (_, d) => Text(d, textDirection: TextDirection.ltr),
        ),
      ),
    );
    expect(find.text('LOADING'), findsOneWidget);
  });

  testWidgets('shows onData widget after data', (tester) async {
    final shard = _ManualAsyncShard();
    addTearDown(shard.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AsyncShardBuilder<_ManualAsyncShard, String>(
          shard: shard,
          onData: (_, d) => Text(d, textDirection: TextDirection.ltr),
        ),
      ),
    );
    shard.setData('hello');
    await tester.pump();
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('shows onError widget after error', (tester) async {
    final shard = _ManualAsyncShard();
    addTearDown(shard.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AsyncShardBuilder<_ManualAsyncShard, String>(
          shard: shard,
          onData: (_, d) => Text(d, textDirection: TextDirection.ltr),
          onError: (_, e, st) => Text('ERR: $e', textDirection: TextDirection.ltr),
        ),
      ),
    );
    shard.setError(Exception('boom'));
    await tester.pump();
    expect(find.textContaining('ERR'), findsOneWidget);
  });

  testWidgets('showDataOnLoading: true shows previousData during reload',
      (tester) async {
    final shard = _ManualAsyncShard();
    addTearDown(shard.dispose);
    shard.setData('first');
    await tester.pumpWidget(
      MaterialApp(
        home: AsyncShardBuilder<_ManualAsyncShard, String>(
          shard: shard,
          onLoading: (_) => const Text('LOADING', textDirection: TextDirection.ltr),
          onData: (_, d) => Text(d, textDirection: TextDirection.ltr),
        ),
      ),
    );
    shard.setLoading(previousData: 'first');
    await tester.pump();
    expect(find.text('first'), findsOneWidget);
    expect(find.text('LOADING'), findsNothing);
  });

  testWidgets('default onLoading is CircularProgressIndicator', (tester) async {
    final shard = _ManualAsyncShard();
    addTearDown(shard.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AsyncShardBuilder<_ManualAsyncShard, String>(
          shard: shard,
          onData: (_, d) => Text(d, textDirection: TextDirection.ltr),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
