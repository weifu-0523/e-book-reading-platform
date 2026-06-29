import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';

import '../../helpers/drift_test_helper.dart';

void main() {
  test('database can be created and closed', () async {
    final db = createTestDatabase();
    expect(db, isNotNull);
    await db.close();
  });

  test('database version is 8', () {
    final db = createTestDatabase();
    expect(db.schemaVersion, 8);
    db.close();
  });

  test('books.file_hash has unique constraint', () async {
    final db = createTestDatabase();
    await db.into(db.books).insert(
          BooksCompanion.insert(
            id: 'b1',
            title: 'a',
            format: 'epub',
            filePath: 'p',
            fileHash: 'HASH_X',
            fileSizeBytes: 1,
          ),
        );
    // 同 fileHash 再次插入应抛异常
    await expectLater(
      db.into(db.books).insert(
            BooksCompanion.insert(
              id: 'b2',
              title: 'b',
              format: 'pdf',
              filePath: 'p2',
              fileHash: 'HASH_X',
              fileSizeBytes: 2,
            ),
          ),
      throwsA(anything),
    );
    await db.close();
  });
}
