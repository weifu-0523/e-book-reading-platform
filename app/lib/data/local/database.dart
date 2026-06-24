import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'connections/database_connection.dart';
import 'daos/book_notes_dao.dart';
import 'daos/books_dao.dart';
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
  daos: [BooksDao, BookNotesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(createDatabaseConnection());

  AppDatabase.forTesting() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON;');
      },
    );
  }
}
