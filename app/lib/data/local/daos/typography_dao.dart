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
