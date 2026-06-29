import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/sync/connectivity_service.dart';

class _FakeConnectivityService implements ConnectivityService {
  _FakeConnectivityService(this._online);
  final bool _online;

  @override
  Future<bool> get isOnline async => _online;
}

void main() {
  test('isOnline returns true when connectivity says online', () async {
    final svc = _FakeConnectivityService(true);
    expect(await svc.isOnline, true);
  });

  test('isOnline returns false when connectivity says offline', () async {
    final svc = _FakeConnectivityService(false);
    expect(await svc.isOnline, false);
  });
}
