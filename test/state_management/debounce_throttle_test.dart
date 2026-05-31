import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shard/shard.dart';

class _DebounceShard extends Shard<int> {
  _DebounceShard() : super(0);

  int callCount = 0;
  void run(String key, {Duration duration = const Duration(milliseconds: 100)}) {
    debounce(key, () => callCount++, duration: duration);
  }

  void cancel(String key) => cancelDebounce(key);
  void cancelAll() => cancelAllDebounce();
}

class _ThrottleShard extends Shard<int> {
  _ThrottleShard() : super(0);

  int callCount = 0;
  bool run(String key, {Duration duration = const Duration(milliseconds: 100)}) {
    return throttle(key, () => callCount++, duration: duration);
  }

  void cancel(String key) => cancelThrottle(key);
  void cancelAll() => cancelAllThrottle();
}

void main() {
  group('DebounceMixin', () {
    test('delays callback until duration elapses', () {
      fakeAsync((async) {
        final s = _DebounceShard();
        s.run('k');
        async.elapse(const Duration(milliseconds: 50));
        expect(s.callCount, 0);
        async.elapse(const Duration(milliseconds: 60));
        expect(s.callCount, 1);
        s.dispose();
      });
    });

    test('consecutive calls reset the timer', () {
      fakeAsync((async) {
        final s = _DebounceShard();
        s.run('k');
        async.elapse(const Duration(milliseconds: 80));
        s.run('k');
        async.elapse(const Duration(milliseconds: 80));
        expect(s.callCount, 0);
        async.elapse(const Duration(milliseconds: 30));
        expect(s.callCount, 1);
        s.dispose();
      });
    });

    test('different keys are independent', () {
      fakeAsync((async) {
        final s = _DebounceShard();
        s.run('a');
        s.run('b');
        async.elapse(const Duration(milliseconds: 110));
        expect(s.callCount, 2);
        s.dispose();
      });
    });

    test('cancelDebounce cancels a specific key', () {
      fakeAsync((async) {
        final s = _DebounceShard();
        s.run('a');
        s.run('b');
        s.cancel('a');
        async.elapse(const Duration(milliseconds: 110));
        expect(s.callCount, 1);
        s.dispose();
      });
    });

    test('cancelAllDebounce cancels all pending keys', () {
      fakeAsync((async) {
        final s = _DebounceShard();
        s.run('a');
        s.run('b');
        s.run('c');
        s.cancelAll();
        async.elapse(const Duration(milliseconds: 200));
        expect(s.callCount, 0);
        s.dispose();
      });
    });

    test('dispose cancels all pending debounces', () {
      fakeAsync((async) {
        final s = _DebounceShard();
        s.run('a');
        s.run('b');
        s.dispose();
        async.elapse(const Duration(milliseconds: 200));
        expect(s.callCount, 0);
      });
    });
  });

  group('ThrottleMixin', () {
    test('first call executes immediately', () {
      fakeAsync((async) {
        final s = _ThrottleShard();
        final executed = s.run('k');
        expect(executed, isTrue);
        expect(s.callCount, 1);
        s.dispose();
      });
    });

    test('subsequent calls within window are ignored', () {
      fakeAsync((async) {
        final s = _ThrottleShard();
        s.run('k');
        final second = s.run('k');
        expect(second, isFalse);
        expect(s.callCount, 1);
        s.dispose();
      });
    });

    test('calls after window execute again', () {
      fakeAsync((async) {
        final s = _ThrottleShard();
        s.run('k');
        async.elapse(const Duration(milliseconds: 150));
        s.run('k');
        expect(s.callCount, 2);
        s.dispose();
      });
    });

    test('different keys are independent', () {
      fakeAsync((async) {
        final s = _ThrottleShard();
        s.run('a');
        s.run('b');
        expect(s.callCount, 2);
        s.dispose();
      });
    });

    test('cancelThrottle resets the window', () {
      fakeAsync((async) {
        final s = _ThrottleShard();
        s.run('k');
        s.cancel('k');
        s.run('k');
        expect(s.callCount, 2);
        s.dispose();
      });
    });

    test('cancelAllThrottle resets all windows', () {
      fakeAsync((async) {
        final s = _ThrottleShard();
        s.run('a');
        s.run('b');
        expect(s.callCount, 2);
        // Within window — these would be ignored.
        expect(s.run('a'), isFalse);
        expect(s.run('b'), isFalse);
        s.cancelAll();
        // After cancelAll, windows are reset, so these execute again.
        expect(s.run('a'), isTrue);
        expect(s.run('b'), isTrue);
        expect(s.callCount, 4);
        s.dispose();
      });
    });

    test('dispose cancels all pending throttles', () {
      fakeAsync((async) {
        final s = _ThrottleShard();
        s.run('a');
        s.run('b');
        s.dispose();
        expect(async.pendingTimers, isEmpty);
      });
    });
  });
}
