import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/repositories/typography_profile_repository.dart';
import 'package:reader_engine/core/typography_settings.dart';

void main() {
  late AppDatabase db;
  late TypographyProfileRepository repo;

  setUp(() {
    db = AppDatabase.forTesting();
    repo = TypographyProfileRepository(db);
  });

  tearDown(() => db.close());

  test('seedDefaultIfEmpty creates exactly one default profile when empty', () async {
    final profile = await repo.seedDefaultIfEmpty();
    expect(profile.isDefault, isTrue);
    expect(profile.settings.fontSize, 16.0);

    final again = await repo.seedDefaultIfEmpty();
    expect(again.id, profile.id); // not duplicated
  });

  test('setDefault toggles isDefault flag', () async {
    final p1 = await repo.seedDefaultIfEmpty();
    final p2 = await repo.insert(name: 'P2', settings: TypographySettings.defaults(), isDefault: false);

    await repo.setDefault(p2.id);
    final after = await repo.getAll();
    expect(after.firstWhere((p) => p.id == p2.id).isDefault, isTrue);
    expect(after.firstWhere((p) => p.id == p1.id).isDefault, isFalse);
  });

  test('findProfilesReferencingFont returns matching profiles', () async {
    final s = TypographySettings.defaults().copyWith(fontFamily: 'MyFont');
    await repo.insert(name: 'WithFont', settings: s, isDefault: false);
    await repo.insert(name: 'NoFont', settings: TypographySettings.defaults(), isDefault: false);

    final refs = await repo.findProfilesReferencingFont('MyFont');
    expect(refs.length, 1);
    expect(refs.first.name, 'WithFont');
  });

  test('CRUD roundtrip preserves settings JSON', () async {
    final original = TypographySettings.defaults().copyWith(fontSize: 20.0, lineHeight: 1.8);
    final p = await repo.insert(name: 'Big', settings: original, isDefault: false);

    final fetched = await repo.getAll();
    expect(fetched.firstWhere((x) => x.id == p.id).settings, original);

    await repo.update(p.id, name: 'BigRenamed');
    final renamed = await repo.getAll();
    expect(renamed.firstWhere((x) => x.id == p.id).name, 'BigRenamed');
  });
}
