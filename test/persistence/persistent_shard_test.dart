import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';
import 'package:shard/shard_test.dart';

class _SimpleCounter extends SimplePersistentShard<int> {
  _SimpleCounter({required FakeStateStorage storage})
      : super(0, storage: storage, serializer: const IntSerializer());

  @override
  String get persistenceKey => 'counter';

  void inc() => emit(state + 1);
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
  test('SimplePersistentShard restores prior value', () async {
    final storage = FakeStateStorage(initialData: {'counter': '5'});
    final s = _SimpleCounter(storage: storage);
    s.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(s.state, 5);
    s.dispose();
  });

  test('SimplePersistentShard persists value on emit', () async {
    final storage = FakeStateStorage();
    final s = _SimpleCounter(storage: storage);
    s.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    s.inc();
    s.inc();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(storage.rawValue('counter'), '2');
    s.dispose();
  });

  test('PersistentShard with T != K persists only the slice', () async {
    final storage = FakeStateStorage();
    final s = _TodoShard(storage: storage);
    s.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    s.add('a');
    s.add('b');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    // The persisted JSON is the list, not the full state.
    expect(storage.rawValue('todos'), '["a","b"]');
    s.dispose();
  });

  test('onLoadComplete merges loaded slice into full state', () async {
    final storage = FakeStateStorage(initialData: {'todos': '["x","y"]'});
    final s = _TodoShard(storage: storage);
    s.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(s.state.status, 'loaded');
    expect(s.state.todos, ['x', 'y']);
    s.dispose();
  });
}
