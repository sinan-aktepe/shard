import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

class _ListShard extends Shard<List<int>> with DeepEqualityMixin<List<int>> {
  _ListShard() : super(const [1, 2, 3]);
  void replace(List<int> next) => emit(next);
}

void main() {
  group('deepEquals', () {
    test('compares nested lists by value', () {
      expect(
        deepEquals(
          [
            1,
            [2, 3],
          ],
          [
            1,
            [2, 3],
          ],
        ),
        isTrue,
      );
      expect(deepEquals([1, 2], [1, 2, 3]), isFalse);
    });

    test('compares maps by value, including nested collections', () {
      expect(
        deepEquals(
          {
            'a': [1, 2],
          },
          {
            'a': [1, 2],
          },
        ),
        isTrue,
      );
      expect(deepEquals({'a': 1}, {'a': 2}), isFalse);
      expect(deepEquals({'a': 1}, {'b': 1}), isFalse);
    });

    test('compares sets by value irrespective of order', () {
      expect(deepEquals({1, 2, 3}, {3, 2, 1}), isTrue);
      expect(deepEquals({1, 2}, {1, 2, 3}), isFalse);
    });

    test('falls back to == for scalars', () {
      expect(deepEquals(1, 1), isTrue);
      expect(deepEquals('x', 'y'), isFalse);
      expect(deepEquals(null, null), isTrue);
    });
  });

  group('DeepEqualityMixin', () {
    test('skips emit when a collection is rebuilt with equal contents', () {
      final shard = _ListShard();
      addTearDown(shard.dispose);
      var notifications = 0;
      shard.addListener(() => notifications++);

      shard.replace([1, 2, 3]); // new instance, same contents — no notify
      expect(notifications, 0);

      shard.replace([1, 2, 3, 4]); // different contents — notify
      expect(notifications, 1);
    });
  });
}
