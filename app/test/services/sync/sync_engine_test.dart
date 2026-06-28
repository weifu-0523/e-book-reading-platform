import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/sync/sync_engine.dart';

void main() {
  test('SyncResult factories', () {
    const success = SyncResult.success(pushedCount: 3, pulledCount: 2);
    expect(success.success, isTrue);
    expect(success.pushedCount, 3);
    expect(success.pulledCount, 2);
    expect(success.error, isNull);

    const failure = SyncResult.failure('rate limited');
    expect(failure.success, isFalse);
    expect(failure.error, 'rate limited');
  });

  test('SyncException carries message', () {
    const exc = SyncException('not authenticated');
    expect(exc.message, 'not authenticated');
    expect(exc.toString(), contains('not authenticated'));
  });
}
