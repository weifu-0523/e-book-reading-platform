import 'dart:async';

/// Serializes calls with a minimum interval between them.
///
/// Used for WebDAV requests to stay under 坚果云's 30 req/min limit (R1).
/// Calls are FIFO — a single underlying queue ensures no two calls overlap.
class RateLimiter {
  RateLimiter({required this.minInterval});

  final Duration minInterval;
  DateTime? _lastCompletedAt;
  Future<void>? _queueTail;

  /// Runs [action] after waiting for the minimum interval since the last
  /// completion. Returns the result of [action].
  Future<T> run<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    final previous = _queueTail ?? Future<void>.value();
    _queueTail = previous.then((_) async {
      final now = DateTime.now();
      final elapsed = _lastCompletedAt == null
          ? minInterval
          : now.difference(_lastCompletedAt!);
      if (elapsed < minInterval) {
        await Future.delayed(minInterval - elapsed);
      }
      try {
        final result = await action();
        _lastCompletedAt = DateTime.now();
        completer.complete(result);
      } catch (e, st) {
        _lastCompletedAt = DateTime.now();
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}
