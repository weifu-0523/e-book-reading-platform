import 'package:zhiyue/data/repositories/settings_repository.dart';

class FakeSettingsRepository implements SettingsRepository {
  final Map<String, dynamic> _map = {};

  @override
  Future<T> get<T>(String key, T defaultValue) async =>
      _map[key] as T? ?? defaultValue;

  @override
  Future<void> set<T>(String key, T value) async => _map[key] = value;

  /// Synchronous variant for test setup. Sets [key] to [value] in the
  /// in-memory map without awaiting — useful when seeding defaults before
  /// a widget is pumped (e.g. pinning a locale before [ZhiYueApp] boots).
  void setSync<T>(String key, T value) => _map[key] = value;
}
