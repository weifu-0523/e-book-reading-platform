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

    // 集合类型：Dart 泛型擦除导致 `decoded is T`（T=List<String>）返回 false
    // （jsonDecode 实际返回 List<dynamic>）。用 `<String>[] is T` 这种"实例判断 T"
    // 的 trick 绕过擦除——只对 List<String> 与 Map<String, dynamic> 这两个明确场景
    // 提供支持，避免误把任意 List 当成 List<String>。
    if (decoded is List && <String>[] is T) {
      return decoded.whereType<String>().toList() as T;
    }
    if (decoded is Map && <String, dynamic>{} is T) {
      return Map<String, dynamic>.from(decoded) as T;
    }

    throw StateError('Cannot decode $raw as $T');
  }
}
