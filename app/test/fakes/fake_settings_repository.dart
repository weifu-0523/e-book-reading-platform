import 'package:zhiyue/data/repositories/settings_repository.dart';

class FakeSettingsRepository implements SettingsRepository {
  final Map<String, dynamic> _map = {};

  @override
  Future<T> get<T>(String key, T defaultValue) async =>
      _map[key] as T? ?? defaultValue;

  @override
  Future<void> set<T>(String key, T value) async => _map[key] = value;
}
