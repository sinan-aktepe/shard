import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

class _Todo {
  _Todo({required this.id, required this.title});
  factory _Todo.fromJson(Map<String, dynamic> json) =>
      _Todo(id: json['id'] as int, title: json['title'] as String);

  final int id;
  final String title;

  Map<String, dynamic> toJson() => {'id': id, 'title': title};

  @override
  bool operator ==(Object other) =>
      other is _Todo && other.id == id && other.title == title;

  @override
  int get hashCode => Object.hash(id, title);
}

void main() {
  test('roundtrips a single object', () {
    final s = stateSerializer<_Todo>(
      fromJson: (j) => _Todo.fromJson(j as Map<String, dynamic>),
      toJson: (t) => t.toJson(),
    );
    final todo = _Todo(id: 1, title: 'Buy milk');
    expect(s.deserialize(s.serialize(todo)), todo);
  });

  test('roundtrips a list of objects', () {
    final s = stateSerializer<List<_Todo>>(
      fromJson: (j) => (j as List)
          .map((e) => _Todo.fromJson(e as Map<String, dynamic>))
          .toList(),
      toJson: (xs) => xs.map((t) => t.toJson()).toList(),
    );
    final todos = [_Todo(id: 1, title: 'a'), _Todo(id: 2, title: 'b')];
    expect(s.deserialize(s.serialize(todos)), todos);
  });

  test('roundtrips nested structures', () {
    final s = stateSerializer<Map<String, _Todo>>(
      fromJson: (j) => (j as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, _Todo.fromJson(v as Map<String, dynamic>)),
      ),
      toJson: (m) => m.map((k, v) => MapEntry(k, v.toJson())),
    );
    final input = {'a': _Todo(id: 1, title: 'a')};
    expect(s.deserialize(s.serialize(input)), input);
  });

  test('malformed JSON throws on deserialize', () {
    final s = stateSerializer<_Todo>(
      fromJson: (j) => _Todo.fromJson(j as Map<String, dynamic>),
      toJson: (t) => t.toJson(),
    );
    expect(() => s.deserialize('not-json'), throwsFormatException);
  });
}
