import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

class _CounterShard extends Shard<int> {
  _CounterShard() : super(0);
  void increment() => emit(state + 1);
  void fail() => addError(Exception('boom'), StackTrace.current);
}

void main() {
  setUp(() {
    Shard.observer = null;
  });

  group('LoggingObserver', () {
    test('logs onChange to custom printer', () {
      final lines = <String>[];
      Shard.observer = LoggingObserver(
        enabled: true,
        printer: lines.add,
      );

      final shard = _CounterShard();
      shard.increment();

      expect(lines, hasLength(1));
      expect(lines.first, contains('_CounterShard'));
      expect(lines.first, contains('0'));
      expect(lines.first, contains('1'));

      shard.dispose();
    });

    test('logs onError to custom printer', () {
      final lines = <String>[];
      Shard.observer = LoggingObserver(
        enabled: true,
        printer: lines.add,
      );

      final shard = _CounterShard();
      shard.fail();

      expect(lines, hasLength(1));
      expect(lines.first, contains('ERROR'));
      expect(lines.first, contains('boom'));

      shard.dispose();
    });

    test('disabled observer logs nothing', () {
      final lines = <String>[];
      Shard.observer = LoggingObserver(
        enabled: false,
        printer: lines.add,
      );

      final shard = _CounterShard();
      shard.increment();
      shard.fail();

      expect(lines, isEmpty);
      shard.dispose();
    });

    test('logChanges: false suppresses change logs only', () {
      final lines = <String>[];
      Shard.observer = LoggingObserver(
        enabled: true,
        logChanges: false,
        printer: lines.add,
      );

      final shard = _CounterShard();
      shard.increment();
      shard.fail();

      expect(lines, hasLength(1));
      expect(lines.first, contains('ERROR'));
      shard.dispose();
    });

    test('logErrors: false suppresses error logs only', () {
      final lines = <String>[];
      Shard.observer = LoggingObserver(
        enabled: true,
        logErrors: false,
        printer: lines.add,
      );

      final shard = _CounterShard();
      shard.increment();
      shard.fail();

      expect(lines, hasLength(1));
      expect(lines.first, isNot(contains('ERROR')));
      shard.dispose();
    });

    test('shouldLog predicate filters shards', () {
      final lines = <String>[];
      Shard.observer = LoggingObserver(
        enabled: true,
        shouldLog: (s) => false,
        printer: lines.add,
      );

      final shard = _CounterShard();
      shard.increment();
      shard.fail();

      expect(lines, isEmpty);
      shard.dispose();
    });

    test('includeStackTrace appends trace to error logs', () {
      final lines = <String>[];
      Shard.observer = LoggingObserver(
        enabled: true,
        includeStackTrace: true,
        printer: lines.add,
      );

      final shard = _CounterShard();
      shard.fail();

      expect(lines, hasLength(1));
      expect(lines.first.split('\n').length, greaterThan(1));
      shard.dispose();
    });
  });
}
