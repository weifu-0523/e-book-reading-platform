import 'dart:convert';

import '../local/database.dart';
import '../local/daos/settings_dao.dart';
import 'settings_repository.dart';

class LocalSettingsRepository implements SettingsRepository {
  final SettingsDao _dao;

  LocalSettingsRepository(AppDatabase db) : _dao = SettingsDao(db);

  @override
  Future<T> get<T>(String key, T defaultValue) async {
    final raw = await _dao.get(key);
    if (raw == null) return defaultValue;
    return _decode<T>(raw);
  }

  @override
  Future<void> set<T>(String key, T value) {
    return _dao.upsert(key, jsonEncode(value));
  }

  T _decode<T>(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is T) return decoded;
    // 处理 int 与 double 互换等边界情况
    if (T == double && decoded is int) return decoded.toDouble() as T;
    if (T == int && decoded is double) return decoded.toInt() as T;
    throw StateError('Cannot decode $raw as $T');
  }
}
