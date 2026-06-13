import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/shard_test.dart';

class _MyShard extends Shard<int> with StatePersistenceMixin<int, int> {
  _MyShard() : super(0);
  void setTo(int v) => emit(v);
}

void main() {
  test('autoLoad calls onLoadComplete with stored value', () {
    fakeAsync((async) {
      final storage = FakeStateStorage(initialData: {'k': '7'});
      final shard = _MyShard();
      int? loadedValue;
      shard.enablePersistence(
        key: 'k',
        storage: storage,
        serializer: const IntSerializer(),
        toPersistence: (s) => s,
        onLoadComplete: (data) => loadedValue = data,
      );

      async.flushMicrotasks();
      expect(loadedValue, 7);
      shard.dispose();
    });
  });

  test('autoLoad calls onLoadComplete with null on empty storage', () {
    fakeAsync((async) {
      final storage = FakeStateStorage();
      final shard = _MyShard();
      bool called = false;
      int? loaded;
      shard.enablePersistence(
        key: 'k',
        storage: storage,
        serializer: const IntSerializer(),
        toPersistence: (s) => s,
        onLoadComplete: (data) {
          called = true;
          loaded = data;
        },
      );

      async.flushMicrotasks();
      expect(called, isTrue);
      expect(loaded, isNull);
      shard.dispose();
    });
  });

  test('emit triggers debounced save', () {
    fakeAsync((async) {
      final storage = FakeStateStorage();
      final shard = _MyShard();
      shard.enablePersistence(
        key: 'k',
        storage: storage,
        serializer: const IntSerializer(),
        toPersistence: (s) => s,
        debounceDuration: const Duration(milliseconds: 50),
      );

      shard.setTo(1);
      shard.setTo(2);
      shard.setTo(3);

      async.elapse(const Duration(milliseconds: 150));
      expect(storage.saveCount, 1);
      expect(storage.rawValue('k'), '3');
      shard.dispose();
    });
  });

  test('onSaveError fires when storage save fails', () {
    fakeAsync((async) {
      final storage = FakeStateStorage()..saveError = StateError('disk full');
      final shard = _MyShard();
      Object? capturedError;
      shard.enablePersistence(
        key: 'k',
        storage: storage,
        serializer: const IntSerializer(),
        toPersistence: (s) => s,
        autoLoad: false,
        debounceDuration: const Duration(milliseconds: 30),
        onSaveError: (e, st) => capturedError = e,
      );

      shard.setTo(1);
      async.elapse(const Duration(milliseconds: 100));
      expect(capturedError, isA<StateError>());
      shard.dispose();
    });
  });

  test('onLoadError fires when storage load fails', () {
    fakeAsync((async) {
      final storage = FakeStateStorage()..loadError = StateError('disk read failed');
      final shard = _MyShard();
      Object? capturedError;
      shard.enablePersistence(
        key: 'k',
        storage: storage,
        serializer: const IntSerializer(),
        toPersistence: (s) => s,
        onLoadError: (e, st) => capturedError = e,
      );

      async.flushMicrotasks();
      expect(capturedError, isA<StateError>());
      shard.dispose();
    });
  });

  test('disablePersistence stops auto-save', () {
    fakeAsync((async) {
      final storage = FakeStateStorage();
      final shard = _MyShard();
      shard.enablePersistence(
        key: 'k',
        storage: storage,
        serializer: const IntSerializer(),
        toPersistence: (s) => s,
        autoLoad: false,
        debounceDuration: const Duration(milliseconds: 30),
      );

      shard.disablePersistence();
      shard.setTo(1);
      async.elapse(const Duration(milliseconds: 100));
      expect(storage.saveCount, 0);
      shard.dispose();
    });
  });

  test('dispose flushes pending save', () {
    fakeAsync((async) {
      final storage = FakeStateStorage();
      final shard = _MyShard();
      shard.enablePersistence(
        key: 'k',
        storage: storage,
        serializer: const IntSerializer(),
        toPersistence: (s) => s,
        autoLoad: false,
        debounceDuration: const Duration(seconds: 5), // long debounce
      );

      shard.setTo(42);
      shard.dispose();

      // Even though debounce was 5s, dispose should have triggered a save.
      async.flushMicrotasks();
      expect(storage.saveCount, 1);
      expect(storage.rawValue('k'), '42');
    });
  });

  test('clearPersistence deletes the stored value', () {
    fakeAsync((async) {
      final storage = FakeStateStorage(initialData: {'k': '5'});
      final shard = _MyShard();
      shard.enablePersistence(
        key: 'k',
        storage: storage,
        serializer: const IntSerializer(),
        toPersistence: (s) => s,
        autoLoad: false,
      );
      shard.clearPersistence();
      async.flushMicrotasks();
      expect(storage.rawValue('k'), isNull);
      expect(storage.deletedKeys, contains('k'));
      shard.disablePersistence();
      shard.dispose();
    });
  });

  test('loadState after clearPersistence calls onLoadComplete with null', () {
    fakeAsync((async) {
      final storage = FakeStateStorage(initialData: {'k': '5'});
      final shard = _MyShard();
      int? loaded;
      var called = false;
      shard.enablePersistence(
        key: 'k',
        storage: storage,
        serializer: const IntSerializer(),
        toPersistence: (s) => s,
        autoLoad: false,
        onLoadComplete: (d) {
          called = true;
          loaded = d;
        },
      );
      shard.clearPersistence();
      async.flushMicrotasks();
      shard.loadState();
      async.flushMicrotasks();
      expect(called, isTrue);
      expect(loaded, isNull);
      shard.disablePersistence();
      shard.dispose();
    });
  });

  test('clearPersistence cancels a pending debounced save', () {
    fakeAsync((async) {
      final storage = FakeStateStorage(initialData: {'k': '9'});
      final shard = _MyShard();
      shard.enablePersistence(
        key: 'k',
        storage: storage,
        serializer: const IntSerializer(),
        toPersistence: (s) => s,
        autoLoad: false,
        debounceDuration: const Duration(milliseconds: 50),
      );
      shard.setTo(3); // schedules a debounced save of 3
      shard.clearPersistence(); // cancels the debounce, queues the delete
      async.elapse(const Duration(milliseconds: 100));
      async.flushMicrotasks();
      expect(storage.rawValue('k'), isNull); // delete won; no stale '3' written
      shard.disablePersistence();
      shard.dispose();
    });
  });

  test('clearPersistence routes delete errors to onSaveError', () {
    fakeAsync((async) {
      final storage = FakeStateStorage(initialData: {'k': '5'})
        ..deleteError = Exception('delete failed');
      final shard = _MyShard();
      Object? captured;
      shard.enablePersistence(
        key: 'k',
        storage: storage,
        serializer: const IntSerializer(),
        toPersistence: (s) => s,
        autoLoad: false,
        onSaveError: (e, st) => captured = e,
      );
      shard.clearPersistence();
      async.flushMicrotasks();
      expect(captured, isA<Exception>());
      expect(storage.rawValue('k'), '5'); // delete threw; value remains
      shard.disablePersistence();
      shard.dispose();
    });
  });
}
