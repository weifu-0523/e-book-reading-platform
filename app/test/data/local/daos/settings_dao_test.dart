import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/settings_dao.dart';
import 'package:zhiyue/data/local/database.dart';

import '../../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late SettingsDao dao;

  setUp(() {
    db = createTestDatabase();
    dao = SettingsDao(db);
  });

  tearDown(() async => db.close());

  test('get returns null for unknown key', () async {
    expect(await dao.get('missing'), isNull);
  });

  test('upsert then get', () async {
    await dao.upsert('theme', 'dark');
    expect(await dao.get('theme'), 'dark');

    await dao.upsert('theme', 'light');
    expect(await dao.get('theme'), 'light');
  });
}
