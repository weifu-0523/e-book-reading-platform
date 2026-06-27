import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../local/database.dart';
import 'package:reader_engine/core/typography_settings.dart';
import '../models/typography_profile.dart' as model;

class TypographyProfileRepository {
  TypographyProfileRepository(this._db);

  final AppDatabase _db;

  Future<List<model.TypographyProfile>> getAll() async {
    final rows = await _db.typographyDao.getAllProfiles();
    return rows
        .map((r) => model.TypographyProfile(
              id: r.id,
              name: r.name,
              settings: TypographySettings.fromJson(
                  jsonDecode(r.settings) as Map<String, dynamic>),
              isDefault: r.isDefault,
            ))
        .toList();
  }

  Future<model.TypographyProfile?> getDefault() async {
    final all = await getAll();
    return all.firstWhere(
      (p) => p.isDefault,
      orElse: () => all.first,
    );
  }

  Future<model.TypographyProfile?> getById(String id) async {
    final r = await _db.typographyDao.getProfile(id);
    if (r == null) return null;
    return model.TypographyProfile(
      id: r.id,
      name: r.name,
      settings: TypographySettings.fromJson(
          jsonDecode(r.settings) as Map<String, dynamic>),
      isDefault: r.isDefault,
    );
  }

  Future<model.TypographyProfile> seedDefaultIfEmpty() async {
    final all = await getAll();
    if (all.isNotEmpty) return all.first;
    return insert(
      name: '默认',
      settings: TypographySettings.defaults(),
      isDefault: true,
    );
  }

  Future<model.TypographyProfile> insert({
    required String name,
    required TypographySettings settings,
    required bool isDefault,
  }) async {
    final id = const Uuid().v4();
    await _db.typographyDao.insertProfile(
      id: id,
      name: name,
      settingsJson: jsonEncode(settings.toJson()),
      isDefault: isDefault,
    );
    return model.TypographyProfile(
        id: id, name: name, settings: settings, isDefault: isDefault);
  }

  Future<void> update(String id,
      {String? name, TypographySettings? settings, bool? isDefault}) async {
    await _db.typographyDao.updateProfile(
      id: id,
      name: name,
      settingsJson: settings == null ? null : jsonEncode(settings.toJson()),
      isDefault: isDefault,
    );
  }

  Future<void> setDefault(String id) => _db.typographyDao.setDefault(id);

  Future<void> delete(String id) => _db.typographyDao.deleteProfile(id);

  Future<List<model.TypographyProfile>> findProfilesReferencingFont(
      String familyName) async {
    final all = await getAll();
    return all.where((p) => p.settings.fontFamily == familyName).toList();
  }
}
