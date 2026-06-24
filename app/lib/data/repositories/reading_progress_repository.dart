import '../models/reading_progress.dart';

abstract class ReadingProgressRepository {
  Future<ReadingProgress?> get(String bookId);
  Future<void> save(ReadingProgress progress);
}
