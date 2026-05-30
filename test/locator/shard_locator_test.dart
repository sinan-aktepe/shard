import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

class _ApiClient {}
class _Repo {
  _Repo(this.api);
  final _ApiClient api;
}

void main() {
  setUp(ShardLocator.reset);

  test('registerSingleton returns the same instance via get', () {
    final api = _ApiClient();
    ShardLocator.registerSingleton<_ApiClient>(api);
    expect(ShardLocator.get<_ApiClient>(), same(api));
  });

  test('registerLazySingleton invokes factory on first get and caches', () {
    var count = 0;
    ShardLocator.registerLazySingleton<_ApiClient>(() {
      count++;
      return _ApiClient();
    });
    final a = ShardLocator.get<_ApiClient>();
    final b = ShardLocator.get<_ApiClient>();
    expect(count, 1);
    expect(identical(a, b), isTrue);
  });

  test('lazy factory can use other registrations', () {
    ShardLocator.registerSingleton<_ApiClient>(_ApiClient());
    ShardLocator.registerLazySingleton<_Repo>(
      () => _Repo(ShardLocator.get<_ApiClient>()),
    );
    final repo = ShardLocator.get<_Repo>();
    expect(repo.api, same(ShardLocator.get<_ApiClient>()));
  });

  test('isRegistered reflects eager and lazy registrations', () {
    expect(ShardLocator.isRegistered<_ApiClient>(), isFalse);
    ShardLocator.registerSingleton<_ApiClient>(_ApiClient());
    expect(ShardLocator.isRegistered<_ApiClient>(), isTrue);
    ShardLocator.reset();
    ShardLocator.registerLazySingleton<_ApiClient>(_ApiClient.new);
    expect(ShardLocator.isRegistered<_ApiClient>(), isTrue);
  });

  test('reset clears all registrations', () {
    ShardLocator.registerSingleton<_ApiClient>(_ApiClient());
    ShardLocator.reset();
    expect(ShardLocator.isRegistered<_ApiClient>(), isFalse);
    expect(() => ShardLocator.get<_ApiClient>(), throwsStateError);
  });

  test('get throws StateError when nothing is registered', () {
    expect(() => ShardLocator.get<_ApiClient>(), throwsStateError);
  });

  test('eager registration replaces lazy', () {
    ShardLocator.registerLazySingleton<_ApiClient>(_ApiClient.new);
    final replacement = _ApiClient();
    ShardLocator.registerSingleton<_ApiClient>(replacement);
    expect(ShardLocator.get<_ApiClient>(), same(replacement));
  });

  test('lazy registration replaces eager', () {
    final original = _ApiClient();
    ShardLocator.registerSingleton<_ApiClient>(original);
    final replacement = _ApiClient();
    ShardLocator.registerLazySingleton<_ApiClient>(() => replacement);
    expect(ShardLocator.get<_ApiClient>(), same(replacement));
  });
}
