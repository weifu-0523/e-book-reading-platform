import 'dart:convert';

import '../../core/locator.dart';
import '../local/database.dart' as db;
import '../local/daos/reading_progress_dao.dart';
import '../models/reading_progress.dart';
import 'reading_progress_repository.dart';

class LocalReadingProgressRepository implements ReadingProgressRepository {
  final ReadingProgressDao _dao;

  LocalReadingProgressRepository(db.AppDatabase database)
      : _dao = ReadingProgressDao(database);

  @override
  Future<ReadingProgress?> get(String bookId) async {
    final row = await _dao.getByBookId(bookId);
    if (row == null) return null;
    return ReadingProgress(
      bookId: row.bookId,
      locator: Locator.fromJson(
        jsonDecode(row.locator) as Map<String, dynamic>,
      ),
      percent: row.percent,
      updatedAt: row.updatedAt,
    );
  }

  @override
  Future<void> save(ReadingProgress progress) {
    return _dao.upsert(
      bookId: progress.bookId,
      locatorJson: jsonEncode(progress.locator.toJson()),
      percent: progress.percent,
    );
  }
}
