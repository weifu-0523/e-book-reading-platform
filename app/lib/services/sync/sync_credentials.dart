import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted storage for sync credentials + deviceId.
///
/// Keys are namespaced under `zhiyue.sync.*`. Storage backend:
/// - Windows: DPAPI under user account
/// - Android: Keystore
/// - iOS: Keychain
class SyncCredentials {
  SyncCredentials([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _kUsername = 'zhiyue.sync.username';
  static const _kPassword = 'zhiyue.sync.password';
  static const _kDeviceId = 'zhiyue.sync.deviceId';

  final FlutterSecureStorage _storage;

  Future<void> save({
    required String username,
    required String password,
    required String deviceId,
  }) async {
    await _storage.write(key: _kUsername, value: username);
    await _storage.write(key: _kPassword, value: password);
    await _storage.write(key: _kDeviceId, value: deviceId);
  }

  Future<({String? username, String? password, String? deviceId})> load() async {
    return (
      username: await _storage.read(key: _kUsername),
      password: await _storage.read(key: _kPassword),
      deviceId: await _storage.read(key: _kDeviceId),
    );
  }

  Future<void> clear() async {
    await _storage.delete(key: _kUsername);
    await _storage.delete(key: _kPassword);
    await _storage.delete(key: _kDeviceId);
  }
}
