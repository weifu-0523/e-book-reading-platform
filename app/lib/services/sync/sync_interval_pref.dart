import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Test-facing interface. SyncIntervalPref implements this implicitly.
abstract class SyncIntervalPrefLike {
  Future<Duration> load();
  Future<void> save(Duration interval);
  Future<void> clear();
}

/// Persisted background-sync interval (Duration).
///
/// Stored under `zhiyue.sync.intervalMinutes` as integer minutes.
/// Duration.zero means "off" (manual sync only). Default on first load
/// is 5 minutes.
class SyncIntervalPref implements SyncIntervalPrefLike {
  SyncIntervalPref([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'zhiyue.sync.intervalMinutes';
  static const _defaultMinutes = 5;

  final FlutterSecureStorage _storage;

  @override
  Future<Duration> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return const Duration(minutes: _defaultMinutes);
    final minutes = int.tryParse(raw);
    if (minutes == null || minutes < 0) {
      return const Duration(minutes: _defaultMinutes);
    }
    return Duration(minutes: minutes);
  }

  @override
  Future<void> save(Duration interval) async {
    final minutes = interval.inMinutes;
    await _storage.write(key: _key, value: minutes.toString());
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _key);
  }
}
