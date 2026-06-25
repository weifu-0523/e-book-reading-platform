import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/repositories/local_settings_repository.dart';

import '../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late LocalSettingsRepository repo;

  setUp(() {
    db = createTestDatabase();
    repo = LocalSettingsRepository(db);
  });

  tearDown(() async => db.close());

  test('get returns default for missing key', () async {
    expect(await repo.get<String>('missing', 'fallback'), 'fallback');
  });

  test('set then get', () async {
    await repo.set<int>('fontSize', 18);
    expect(await repo.get<int>('fontSize', 0), 18);
  });

  test('set then get bool', () async {
    await repo.set<bool>('isDark', true);
    expect(await repo.get<bool>('isDark', false), isTrue);
  });

  test('set then get double', () async {
    await repo.set<double>('lineHeight', 1.6);
    expect(await repo.get<double>('lineHeight', 1.5), 1.6);
  });
}
