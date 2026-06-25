import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/books_dao.dart';
import 'package:zhiyue/data/local/daos/typography_dao.dart';
import 'package:zhiyue/data/local/database.dart';

import '../../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late TypographyDao dao;

  setUp(() async {
    db = createTestDatabase();
    dao = TypographyDao(db);
    // Create a book for foreign key constraint
    await BooksDao(db).insertOne(
      id: 'b1',
      title: 'Test Book',
      format: 'epub',
      filePath: '/path/to/book.epub',
      fileHash: 'hash123',
      fileSizeBytes: 1024,
    );
  });

  tearDown(() async => db.close());

  test('insert profile and getAll', () async {
    await dao.insertProfile(
      id: 'p1',
      name: '默认',
      settingsJson: '{}',
      isDefault: true,
    );
    final all = await dao.getAllProfiles();
    expect(all, hasLength(1));
    expect(all.first.name, '默认');
  });

  test('getProfile returns null when missing', () async {
    expect(await dao.getProfile('nonexistent'), isNull);
  });

  test('override upsert', () async {
    await dao.upsertOverride(
        bookId: 'b1', customSettingsJson: '{"fontSize":18}');
    final override = await dao.getOverride('b1');
    expect(override?.customSettings, '{"fontSize":18}');
  });
}
