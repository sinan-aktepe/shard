import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

void main() {
  group('IntSerializer', () {
    const s = IntSerializer();

    test('roundtrips positive, zero, and negative', () {
      expect(s.deserialize(s.serialize(42)), 42);
      expect(s.deserialize(s.serialize(0)), 0);
      expect(s.deserialize(s.serialize(-7)), -7);
    });

    test('throws FormatException on malformed input', () {
      expect(() => s.deserialize('abc'), throwsFormatException);
    });
  });

  group('DoubleSerializer', () {
    const s = DoubleSerializer();

    test('roundtrips fractional and integral values', () {
      expect(s.deserialize(s.serialize(3.14)), closeTo(3.14, 1e-9));
      expect(s.deserialize(s.serialize(0.0)), 0.0);
      expect(s.deserialize(s.serialize(-1.5)), -1.5);
    });
  });

  group('BoolSerializer', () {
    const s = BoolSerializer();

    test('roundtrips true and false', () {
      expect(s.deserialize(s.serialize(true)), isTrue);
      expect(s.deserialize(s.serialize(false)), isFalse);
    });

    test('non-true strings deserialize to false', () {
      expect(s.deserialize('garbage'), isFalse);
    });
  });

  group('StringSerializer', () {
    const s = StringSerializer();

    test('preserves arbitrary strings including empty and unicode', () {
      expect(s.deserialize(s.serialize('')), '');
      expect(s.deserialize(s.serialize('hello, 世界 👋')), 'hello, 世界 👋');
      expect(s.deserialize(s.serialize('with\nnewlines')), 'with\nnewlines');
    });
  });
}
