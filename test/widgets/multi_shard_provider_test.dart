import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

class _A extends Shard<int> {
  _A() : super(1);
}

class _B extends Shard<String> {
  _B() : super('hello');
}

void main() {
  testWidgets('provides multiple shards accessible from child', (tester) async {
    late _A a;
    late _B b;
    await tester.pumpWidget(
      MaterialApp(
        home: MultiShardProvider(
          providers: [
            ShardProvider<_A>(create: () => _A()),
            ShardProvider<_B>(create: () => _B()),
          ],
          child: Builder(builder: (context) {
            a = ShardProvider.of<_A>(context, listen: false);
            b = ShardProvider.of<_B>(context, listen: false);
            return const SizedBox();
          }),
        ),
      ),
    );
    expect(a.state, 1);
    expect(b.state, 'hello');
  });

  testWidgets('empty providers list returns child unchanged', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MultiShardProvider(
          providers: [],
          child: Text('OK', textDirection: TextDirection.ltr),
        ),
      ),
    );
    expect(find.text('OK'), findsOneWidget);
  });

  testWidgets('mixes create and value constructors', (tester) async {
    final external = _B();
    addTearDown(external.dispose);
    late _A a;
    late _B b;
    await tester.pumpWidget(
      MaterialApp(
        home: MultiShardProvider(
          providers: [
            ShardProvider<_A>(create: () => _A()),
            ShardProvider<_B>.value(value: external),
          ],
          child: Builder(builder: (context) {
            a = ShardProvider.of<_A>(context, listen: false);
            b = ShardProvider.of<_B>(context, listen: false);
            return const SizedBox();
          }),
        ),
      ),
    );
    expect(a.state, 1);
    expect(identical(b, external), isTrue);
  });
}
