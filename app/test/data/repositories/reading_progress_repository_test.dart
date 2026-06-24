import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/local/daos/books_dao.dart';
import 'package:zhiyue/data/models/reading_progress.dart';
import 'package:zhiyue/data/repositories/local_reading_progress_repository.dart';

import '../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late LocalReadingProgressRepository repo;

  setUp(() async {
    db = createTestDatabase();
    repo = LocalReadingProgressRepository(db);
    await BooksDao(db).insertOne(
      id: 'b1',
      title: 't',
      format: 'epub',
      filePath: 'p',
      fileHash: 'h',
      fileSizeBytes: 0,
    );
  });

  tearDown(() async => db.close());

  test('save and get', () async {
    final p = ReadingProgress(
      bookId: 'b1',
      locator: EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0),
      percent: 0.3,
      updatedAt: DateTime(2026, 6, 24),
    );
    await repo.save(p);
    final found = await repo.get('b1');
    expect(found?.percent, 0.3);
    expect(found?.locator, isA<EpubCfiLocator>());
  });
}
