import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/book_typography_overrides.dart';
import '../tables/typography_profiles.dart';

part 'typography_dao.g.dart';

@DriftAccessor(tables: [TypographyProfiles, BookTypographyOverrides])
class TypographyDao extends DatabaseAccessor<AppDatabase>
    with _$TypographyDaoMixin {
  TypographyDao(super.db);

  Future<List<TypographyProfile>> getAllProfiles() =>
      select(typographyProfiles).get();

  Future<TypographyProfile?> getProfile(String id) =>
      (select(typographyProfiles)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<int> insertProfile({
    required String id,
    required String name,
    required String settingsJson,
    required bool isDefault,
  }) {
    return into(typographyProfiles).insert(
      TypographyProfilesCompanion.insert(
        id: id,
        name: name,
        settings: settingsJson,
        isDefault: Value(isDefault),
      ),
    );
  }

  /// 事务包裹两步写：先把当前 default 清零，再把目标 id 设为 true。
  /// 必须在同一事务内，否则中途失败会导致表里没有 default。
  Future<void> setDefault(String profileId) async {
    return transaction(() async {
      await (update(typographyProfiles)..where((t) => t.isDefault.equals(true)))
          .write(const TypographyProfilesCompanion(isDefault: Value(false)));
      await (update(typographyProfiles)..where((t) => t.id.equals(profileId)))
          .write(const TypographyProfilesCompanion(isDefault: Value(true)));
    });
  }

  Future<void> deleteProfile(String id) =>
      (delete(typographyProfiles)..where((t) => t.id.equals(id))).go();

  Future<void> updateProfile({
    required String id,
    String? name,
    String? settingsJson,
    bool? isDefault,
  }) {
    return (update(typographyProfiles)..where((t) => t.id.equals(id))).write(
      TypographyProfilesCompanion(
        name: name == null ? const Value.absent() : Value(name),
        settings:
            settingsJson == null ? const Value.absent() : Value(settingsJson),
        isDefault:
            isDefault == null ? const Value.absent() : Value(isDefault),
      ),
    );
  }

  Future<BookTypographyOverride?> getOverride(String bookId) {
    return (select(bookTypographyOverrides)
          ..where((t) => t.bookId.equals(bookId)))
        .getSingleOrNull();
  }

  Future<void> upsertOverride({
    required String bookId,
    String? profileId,
    String? customSettingsJson,
  }) {
    return into(bookTypographyOverrides).insertOnConflictUpdate(
      BookTypographyOverridesCompanion.insert(
        bookId: bookId,
        profileId: profileId == null ? const Value.absent() : Value(profileId),
        customSettings: customSettingsJson == null
            ? const Value.absent()
            : Value(customSettingsJson),
      ),
    );
  }
}
