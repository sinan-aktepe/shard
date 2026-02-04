/// Global service locator for registering and resolving singletons.
///
/// Use [ShardLocator] to register API clients, repositories, or other
/// singletons without a separate package. Register in [main] and resolve
/// anywhere with [get].
///
/// ## Registration
///
/// ```dart
/// void main() {
///   ShardLocator.registerSingleton<ApiClient>(ApiClient());
///   ShardLocator.registerLazySingleton<Repository>(
///     () => Repository(ShardLocator.get<ApiClient>()),
///   );
///   runApp(MyApp());
/// }
/// ```
///
/// ## Resolution
///
/// ```dart
/// final repo = ShardLocator.get<Repository>();
/// ```
///
/// ## Testing
///
/// Call [reset] in setUp to clear all registrations between tests:
///
/// ```dart
/// setUp(() => ShardLocator.reset());
/// ```
class ShardLocator {
  ShardLocator._();

  static final Map<Type, Object> _singletons = {};
  static final Map<Type, Object Function()> _lazyFactories = {};

  /// Registers an existing [instance] as the singleton for type `T`.
  ///
  /// Subsequent calls to [get] will return this same instance.
  static void registerSingleton<T extends Object>(T instance) {
    _singletons[T] = instance;
    _lazyFactories.remove(T);
  }

  /// Registers a [factory] that will be called once on the first [get] call.
  ///
  /// The result is cached; later [get] calls return the same instance.
  static void registerLazySingleton<T extends Object>(T Function() factory) {
    _lazyFactories[T] = factory as Object Function();
    _singletons.remove(T);
  }

  /// Returns the registered singleton for type `T`.
  ///
  /// Throws [StateError] if no singleton is registered for type `T`.
  /// For lazy singletons, the factory is invoked on the first call.
  static T get<T extends Object>() {
    final existing = _singletons[T];
    if (existing != null) {
      return existing as T;
    }
    final factory = _lazyFactories[T];
    if (factory != null) {
      final instance = factory() as T;
      _singletons[T] = instance;
      _lazyFactories.remove(T);
      return instance;
    }
    throw StateError(
      'No singleton registered for type $T. '
      'Call registerSingleton<$T>(...) or registerLazySingleton<$T>(...) first.',
    );
  }

  /// Whether a singleton (eager or lazy) is registered for type `T`.
  static bool isRegistered<T extends Object>() {
    return _singletons.containsKey(T) || _lazyFactories.containsKey(T);
  }

  /// Clears all registrations.
  ///
  /// Use in tests to reset state between runs.
  static void reset() {
    _singletons.clear();
    _lazyFactories.clear();
  }
}
