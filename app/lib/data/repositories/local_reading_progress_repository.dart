import 'dart:convert';

import '../../core/locator.dart';
import '../../services/sync/sync_recorder.dart';
import '../local/database.dart' as db;
import '../local/daos/reading_progress_dao.dart';
import '../models/reading_progress.dart';
import 'reading_progress_repository.dart';

class LocalReadingProgressRepository implements ReadingProgressRepository {
  final ReadingProgressDao _dao;
  final SyncRecorder? _syncRecorder;

  LocalReadingProgressRepository(
    db.AppDatabase database, {
    SyncRecorder? syncRecorder,
  })  : _dao = ReadingProgressDao(database),
        _syncRecorder = syncRecorder;

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
  Future<void> save(ReadingProgress progress) async {
    await _dao.upsert(
      bookId: progress.bookId,
      locatorJson: jsonEncode(progress.locator.toJson()),
      percent: progress.percent,
    );
    await _syncRecorder?.recordReadingProgress(
      bookId: progress.bookId,
      locatorJson: jsonEncode(progress.locator.toJson()),
      percent: progress.percent,
      mtime: DateTime.now(),
    );
  }
}
