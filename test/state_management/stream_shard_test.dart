import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/shard_test.dart';

class _TickerShard extends StreamShard<int> {
  _TickerShard({required this.controller});
  final StreamController<int> controller;

  @override
  Stream<int> build() => controller.stream;
}

void main() {
  test('subscribes on onInit and emits Loading initially', () async {
    final ctrl = StreamController<int>();
    final shard = _TickerShard(controller: ctrl);
    addTearDown(shard.dispose);
    addTearDown(ctrl.close);

    shard.onInit();
    expect(shard.state, isA<AsyncLoading<int>>());
  });

  test('emits AsyncData for each stream value', () async {
    final ctrl = StreamController<int>();
    final shard = _TickerShard(controller: ctrl);
    final tester = ShardTester(shard);
    addTearDown(tester.dispose);
    addTearDown(shard.dispose);
    addTearDown(ctrl.close);

    shard.onInit();
    ctrl.add(1);
    ctrl.add(2);

    await tester.expectStates([
      AsyncData<int>(1),
      AsyncData<int>(2),
    ]);
  });

  test('emits AsyncError when stream errors', () async {
    final ctrl = StreamController<int>();
    final shard = _TickerShard(controller: ctrl);
    final tester = ShardTester(shard);
    addTearDown(tester.dispose);
    addTearDown(shard.dispose);
    addTearDown(ctrl.close);

    shard.onInit();
    ctrl.addError(StateError('boom'));

    await tester.waitFor((s) => s is AsyncError<int>);
    expect(tester.lastState, isA<AsyncError<int>>());
  });

  test('refresh cancels and re-subscribes', () async {
    final ctrl1 = StreamController<int>.broadcast();
    final shard = _TickerShard(controller: ctrl1);
    final tester = ShardTester(shard);
    addTearDown(tester.dispose);
    addTearDown(shard.dispose);
    addTearDown(ctrl1.close);

    shard.onInit();
    ctrl1.add(1);
    await tester.waitFor((s) => s is AsyncData<int>);

    tester.clear();
    shard.refresh();
    ctrl1.add(2);
    await tester.waitFor((s) => s is AsyncData<int> && (s).data == 2);
    expect((tester.lastState as AsyncData<int>).data, 2);
  });

  test('dispose cancels subscription', () async {
    final ctrl = StreamController<int>();
    final shard = _TickerShard(controller: ctrl);
    final tester = ShardTester(shard);
    addTearDown(tester.dispose);
    addTearDown(ctrl.close);

    shard.onInit();
    shard.dispose();

    ctrl.add(1);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(tester.recordedStates, isEmpty);
  });
}
