import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/reading_progress.dart';

part 'reading_progress_dao.g.dart';

@DriftAccessor(tables: [ReadingProgressTable])
class ReadingProgressDao extends DatabaseAccessor<AppDatabase>
    with _$ReadingProgressDaoMixin {
  ReadingProgressDao(super.db);

  Future<ReadingProgressTableData?> getByBookId(String bookId) {
    return (select(readingProgressTable)
          ..where((t) => t.bookId.equals(bookId)))
        .getSingleOrNull();
  }

  /// Upsert：主键冲突时更新。
  Future<void> upsert({
    required String bookId,
    required String locatorJson,
    required double percent,
  }) async {
    await into(readingProgressTable).insertOnConflictUpdate(
      ReadingProgressTableCompanion.insert(
        bookId: bookId,
        locator: locatorJson,
        percent: percent,
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
