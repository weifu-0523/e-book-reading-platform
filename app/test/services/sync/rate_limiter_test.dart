import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/sync/rate_limiter.dart';

void main() {
  test('first call executes immediately', () async {
    final limiter = RateLimiter(minInterval: const Duration(seconds: 2));
    final sw = Stopwatch()..start();
    await limiter.run(() async {});
    expect(sw.elapsedMilliseconds, lessThan(500));
  });

  test('subsequent call within interval waits', () async {
    final limiter = RateLimiter(minInterval: const Duration(milliseconds: 200));
    await limiter.run(() async {}); // t=0
    final sw = Stopwatch()..start();
    await limiter.run(() async {}); // should wait ~200ms
    expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(180));
  });

  test('parallel calls are serialized', () async {
    final limiter = RateLimiter(minInterval: const Duration(milliseconds: 100));
    final executionOrder = <int>[];
    final futures = <Future<void>>[];
    for (var i = 0; i < 3; i++) {
      final idx = i;
      futures.add(limiter.run(() async {
        executionOrder.add(idx);
      }));
    }
    await Future.wait(futures);
    expect(executionOrder, [0, 1, 2]); // FIFO
  });
}
