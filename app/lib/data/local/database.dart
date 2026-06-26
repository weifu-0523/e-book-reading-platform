import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'connections/database_connection.dart';
import 'daos/annotations_dao.dart';
import 'daos/book_notes_dao.dart';
import 'daos/book_tags_dao.dart';
import 'daos/books_dao.dart';
import 'daos/reading_progress_dao.dart';
import 'daos/settings_dao.dart';
import 'daos/typography_dao.dart';
import 'tables/annotations.dart';
import 'tables/book_notes.dart';
import 'tables/book_tags.dart';
import 'tables/book_typography_overrides.dart';
import 'tables/books.dart';
import 'tables/reading_progress.dart';
import 'tables/settings.dart';
import 'tables/typography_profiles.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Books,
    BookTags,
    BookNotes,
    Annotations,
    ReadingProgressTable,
    TypographyProfiles,
    BookTypographyOverrides,
    Settings,
  ],
  daos: [
    BooksDao,
    BookTagsDao,
    BookNotesDao,
    AnnotationsDao,
    ReadingProgressDao,
    TypographyDao,
    SettingsDao
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(createDatabaseConnection());

  AppDatabase.forTesting() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        // schema v2 起带 file_hash 唯一索引
        await m.database.customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_books_file_hash ON books(file_hash)',
        );
        // schema v3 起带 book_tags 索引
        await m.database.customStatement(
          'CREATE INDEX IF NOT EXISTS idx_book_tags_tag ON book_tags(tag)',
        );
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.database.customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_books_file_hash ON books(file_hash)',
          );
        }
        if (from < 3) {
          // 加列：用 raw SQL ALTER TABLE（比 m.addField 更直观，等价）
          await m.database.customStatement(
            'ALTER TABLE books ADD COLUMN sort_order INTEGER',
          );
          await m.createTable(bookTags);
          await m.database.customStatement(
            'CREATE INDEX IF NOT EXISTS idx_book_tags_tag ON book_tags(tag)',
          );
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON;');
      },
    );
  }
}
