import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/shard_test.dart';

String? _envPayload(String? raw) =>
    raw == null ? null : (jsonDecode(raw) as Map)['__shard_p'] as String?;
int? _envVersion(String? raw) =>
    raw == null ? null : (jsonDecode(raw) as Map)['__shard_v'] as int?;

class _SimpleCounter extends SimplePersistentShard<int> {
  _SimpleCounter({required FakeStateStorage storage})
    : super(0, storage: storage, serializer: const IntSerializer());

  @override
  String get persistenceKey => 'counter';

  void inc() => emit(state + 1);
}

class _FactoryCounter extends SimplePersistentShard<int> {
  _FactoryCounter({required Future<StateStorage> Function() factory})
    : super(0, storageFactory: factory, serializer: const IntSerializer());

  @override
  String get persistenceKey => 'counter';
}

class _MigratingCounter extends SimplePersistentShard<int> {
  _MigratingCounter({required FakeStateStorage storage})
    : super(
        0,
        storage: storage,
        serializer: const IntSerializer(),
        version: 2,
        migrate: (from, payload) => (int.parse(payload) * 10).toString(),
      );

  @override
  String get persistenceKey => 'counter';
}

class _TodoState {
  _TodoState({required this.status, required this.todos});
  final String status;
  final List<String> todos;

  _TodoState copyWith({String? status, List<String>? todos}) =>
      _TodoState(status: status ?? this.status, todos: todos ?? this.todos);
}

class _TodoShard extends PersistentShard<_TodoState, List<String>> {
  _TodoShard({required FakeStateStorage storage})
    : super(
        _TodoState(status: 'loading', todos: const []),
        storage: storage,
        serializer: stateSerializer<List<String>>(
          fromJson: (j) => (j as List).cast<String>(),
          toJson: (xs) => xs,
        ),
      );

  @override
  String get persistenceKey => 'todos';

  @override
  List<String> toPersistence(_TodoState s) => s.todos;

  @override
  void onLoadComplete(List<String>? data) {
    emit(state.copyWith(status: 'loaded', todos: data ?? []));
  }

  void add(String t) => emit(state.copyWith(todos: [...state.todos, t]));
}

void main() {
  test('SimplePersistentShard restores prior value', () {
    fakeAsync((async) {
      final storage = FakeStateStorage(initialData: {'counter': '5'});
      final s = _SimpleCounter(storage: storage);
      s.onInit();
      async.flushMicrotasks();
      expect(s.state, 5);
      s.dispose();
    });
  });

  test('SimplePersistentShard persists value on emit', () {
    fakeAsync((async) {
      final storage = FakeStateStorage();
      final s = _SimpleCounter(storage: storage);
      s.onInit();
      async.flushMicrotasks();
      s.inc();
      s.inc();
      async.elapse(const Duration(milliseconds: 600));
      expect(_envVersion(storage.rawValue('counter')), 1);
      expect(_envPayload(storage.rawValue('counter')), '2');
      s.dispose();
    });
  });

  test('SimplePersistentShard forwards version/migrate to persistence', () {
    fakeAsync((async) {
      // Legacy bare data; version 2 + migrate should run migrate(1, '5').
      final storage = FakeStateStorage(initialData: {'counter': '5'});
      final s = _MigratingCounter(storage: storage);
      s.onInit();
      async.flushMicrotasks();
      expect(s.state, 50);
      s.disablePersistence();
      s.dispose();
    });
  });

  test('PersistentShard with T != K persists only the slice', () {
    fakeAsync((async) {
      final storage = FakeStateStorage();
      final s = _TodoShard(storage: storage);
      s.onInit();
      async.flushMicrotasks();
      s.add('a');
      s.add('b');
      async.elapse(const Duration(milliseconds: 600));
      // The persisted JSON is the list, not the full state.
      expect(_envVersion(storage.rawValue('todos')), 1);
      expect(_envPayload(storage.rawValue('todos')), '["a","b"]');
      s.dispose();
    });
  });

  test('onLoadComplete merges loaded slice into full state', () {
    fakeAsync((async) {
      final storage = FakeStateStorage(initialData: {'todos': '["x","y"]'});
      final s = _TodoShard(storage: storage);
      s.onInit();
      async.flushMicrotasks();
      expect(s.state.status, 'loaded');
      expect(s.state.todos, ['x', 'y']);
      s.dispose();
    });
  });

  test('retry() re-runs initialization after failure', () {
    fakeAsync((async) {
      final storage = FakeStateStorage()
        ..loadError = StateError('disk read failed');
      final s = _SimpleCounter(storage: storage);
      s.onInit();
      async.flushMicrotasks();
      // First load failed — state remains at initial value.
      expect(s.state, 0);

      // Fix storage, then retry.
      storage
        ..loadError = null
        ..seed('counter', '99');
      s.retry();
      async.flushMicrotasks();

      expect(s.state, 99);
      s.dispose();
    });
  });

  test('storageFactory async path resolves and loads', () {
    fakeAsync((async) {
      final realStorage = FakeStateStorage(initialData: {'counter': '7'});
      final s = _FactoryCounter(factory: () async => realStorage);
      s.onInit();
      async.flushMicrotasks();
      expect(s.state, 7);
      s.dispose();
    });
  });
}
