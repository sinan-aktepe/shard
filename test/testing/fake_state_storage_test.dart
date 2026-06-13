import 'package:flutter_test/flutter_test.dart';
import 'package:shard/src/testing/fake_state_storage.dart';

void main() {
  group('FakeStateStorage', () {
    test('save and load roundtrip', () async {
      final storage = FakeStateStorage();
      await storage.save('k', 'v');
      expect(await storage.load('k'), 'v');
    });

    test('load returns null for missing key', () async {
      final storage = FakeStateStorage();
      expect(await storage.load('missing'), isNull);
    });

    test('constructor seeds initial data', () async {
      final storage = FakeStateStorage(initialData: {'k': 'v'});
      expect(await storage.load('k'), 'v');
      expect(storage.rawValue('k'), 'v');
    });

    test('seed adds data after construction', () async {
      final storage = FakeStateStorage();
      storage.seed('k', 'v');
      expect(await storage.load('k'), 'v');
    });

    test('saveCount increments per save', () async {
      final storage = FakeStateStorage();
      await storage.save('a', '1');
      await storage.save('b', '2');
      await storage.save('a', '3');
      expect(storage.saveCount, 3);
      expect(storage.savedKeys, ['a', 'b', 'a']);
    });

    test('loadCount increments per load', () async {
      final storage = FakeStateStorage();
      await storage.load('a');
      await storage.load('a');
      expect(storage.loadCount, 2);
    });

    test('loadError throws on load', () async {
      final storage = FakeStateStorage()..loadError = StateError('boom');
      await expectLater(storage.load('k'), throwsA(isA<StateError>()));
    });

    test('saveError throws on save', () async {
      final storage = FakeStateStorage()..saveError = StateError('boom');
      await expectLater(storage.save('k', 'v'), throwsA(isA<StateError>()));
    });

    test('loadDelay delays load completion', () async {
      final storage = FakeStateStorage()..loadDelay = const Duration(milliseconds: 50);
      final sw = Stopwatch()..start();
      await storage.load('k');
      sw.stop();
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(40));
    });

    test('hasKey reflects current state', () async {
      final storage = FakeStateStorage();
      expect(storage.hasKey('k'), isFalse);
      await storage.save('k', 'v');
      expect(storage.hasKey('k'), isTrue);
    });

    test('data returns unmodifiable map', () async {
      final storage = FakeStateStorage();
      await storage.save('k', 'v');
      final view = storage.data;
      expect(() => view['x'] = 'y', throwsUnsupportedError);
    });

    test('clear wipes data, keeps counters and savedKeys', () async {
      final storage = FakeStateStorage();
      await storage.save('k', 'v');
      storage.clear();
      expect(await storage.load('k'), isNull);
      expect(storage.saveCount, 1);
      expect(storage.savedKeys, ['k']);
    });

    test('reset wipes data, counters, errors, delays', () async {
      final storage = FakeStateStorage()
        ..loadError = StateError('x')
        ..saveDelay = const Duration(seconds: 1);
      await storage.save('k', 'v');
      storage.reset();
      expect(storage.saveCount, 0);
      expect(storage.savedKeys, isEmpty);
      expect(storage.loadError, isNull);
      expect(storage.saveDelay, isNull);
      expect(await storage.load('k'), isNull);
    });

    test('delete removes the key and a subsequent load returns null', () async {
      final storage = FakeStateStorage(initialData: {'k': 'v'});
      await storage.delete('k');
      expect(await storage.load('k'), isNull);
      expect(storage.hasKey('k'), isFalse);
      expect(storage.deleteCount, 1);
      expect(storage.deletedKeys, ['k']);
    });

    test('delete of a missing key is a no-op (still counted)', () async {
      final storage = FakeStateStorage();
      await storage.delete('absent');
      expect(storage.deleteCount, 1);
    });

    test('delete throws when deleteError is set and leaves data intact', () async {
      final storage = FakeStateStorage(initialData: {'k': 'v'})
        ..deleteError = Exception('boom');
      await expectLater(storage.delete('k'), throwsException);
      expect(storage.rawValue('k'), 'v');
    });

    test('reset clears delete counters', () async {
      final storage = FakeStateStorage(initialData: {'k': 'v'});
      await storage.delete('k');
      storage.reset();
      expect(storage.deleteCount, 0);
      expect(storage.deletedKeys, isEmpty);
    });
  });
}
