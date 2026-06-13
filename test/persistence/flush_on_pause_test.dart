import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/shard_test.dart';

class _MyShard extends Shard<int> with StatePersistenceMixin<int, int> {
  _MyShard() : super(0);
  void setTo(int v) => emit(v);
}

String? _payload(String? raw) =>
    raw == null ? null : (jsonDecode(raw) as Map)['__shard_p'] as String?;

/// Drives the binding from resumed to paused via the valid intermediate state.
void _pause(TestWidgetsFlutterBinding binding) {
  binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test('flushOnPause:true saves on pause within the debounce window', () async {
    final storage = FakeStateStorage();
    final shard = _MyShard();
    shard.enablePersistence(
      key: 'k',
      storage: storage,
      serializer: const IntSerializer(),
      toPersistence: (s) => s,
      autoLoad: false,
      debounceDuration: const Duration(seconds: 10), // long; won't fire
      flushOnPause: true,
    );

    shard.setTo(42); // schedules a 10s debounced save that won't fire
    _pause(binding);
    await pumpEventQueue();

    expect(storage.saveCount, 1); // the flush saved despite the long debounce
    expect(_payload(storage.rawValue('k')), '42');

    shard.disablePersistence();
    shard.dispose();
  });

  test('flushOnPause:false ignores lifecycle changes', () async {
    final storage = FakeStateStorage();
    final shard = _MyShard();
    shard.enablePersistence(
      key: 'k',
      storage: storage,
      serializer: const IntSerializer(),
      toPersistence: (s) => s,
      autoLoad: false,
      debounceDuration: const Duration(seconds: 10),
    );

    shard.setTo(7);
    _pause(binding);
    await pumpEventQueue();

    expect(storage.saveCount, 0); // no observer registered → no flush

    shard.disablePersistence();
    shard.dispose();
  });

  test('lifecycle observer is removed on dispose (no save afterwards)',
      () async {
    final storage = FakeStateStorage();
    final shard = _MyShard();
    shard.enablePersistence(
      key: 'k',
      storage: storage,
      serializer: const IntSerializer(),
      toPersistence: (s) => s,
      autoLoad: false,
      debounceDuration: const Duration(seconds: 10),
      flushOnPause: true,
    );

    shard.setTo(5);
    shard.dispose(); // flushes once and removes the observer
    await pumpEventQueue();
    final savesAfterDispose = storage.saveCount;

    _pause(binding);
    await pumpEventQueue();

    expect(storage.saveCount, savesAfterDispose); // observer gone → no extra save
  });
}
