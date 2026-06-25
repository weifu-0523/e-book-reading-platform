import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'connections/database_connection.dart';
import 'daos/annotations_dao.dart';
import 'daos/book_notes_dao.dart';
import 'daos/books_dao.dart';
import 'daos/reading_progress_dao.dart';
import 'daos/settings_dao.dart';
import 'daos/typography_dao.dart';
import 'tables/annotations.dart';
import 'tables/book_notes.dart';
import 'tables/book_typography_overrides.dart';
import 'tables/books.dart';
import 'tables/reading_progress.dart';
import 'tables/settings.dart';
import 'tables/typography_profiles.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Books,
    BookNotes,
    Annotations,
    ReadingProgressTable,
    TypographyProfiles,
    BookTypographyOverrides,
    Settings,
  ],
  daos: [
    BooksDao,
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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        // schema v2 起带 file_hash 唯一索引
        await m.database.customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_books_file_hash ON books(file_hash)',
        );
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.database.customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_books_file_hash ON books(file_hash)',
          );
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON;');
      },
    );
  }
}
