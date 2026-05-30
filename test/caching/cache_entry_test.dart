import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

void main() {
  group('CacheEntry', () {
    test('isExpired is true when expiryDate is in the past', () {
      final entry = CacheEntry(
        data: 1,
        expiryDate: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      expect(entry.isExpired, isTrue);
    });

    test('isExpired is false when expiryDate is in the future', () {
      final entry = CacheEntry(
        data: 1,
        expiryDate: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(entry.isExpired, isFalse);
    });

    test('stores data unchanged', () {
      final entry = CacheEntry(
        data: {'k': 'v'},
        expiryDate: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(entry.data, {'k': 'v'});
    });
  });
}
