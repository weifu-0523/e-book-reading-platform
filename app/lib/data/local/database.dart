// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'connections/database_connection.dart';
import 'daos/ai_summaries_dao.dart';
import 'daos/annotations_dao.dart';
import 'daos/book_notes_dao.dart';
import 'daos/book_passages_dao.dart';
import 'daos/book_tags_dao.dart';
import 'daos/books_dao.dart';
import 'daos/qa_history_dao.dart';
import 'daos/reading_progress_dao.dart';
import 'daos/settings_dao.dart';
import 'daos/sync_conflicts_dao.dart';
import 'daos/sync_outbox_dao.dart';
import 'daos/typography_dao.dart';
import 'daos/user_fonts_dao.dart';
import 'tables/ai_summaries.dart';
import 'tables/annotations.dart';
import 'tables/book_notes.dart';
import 'tables/book_passages.dart';
import 'tables/book_tags.dart';
import 'tables/bookmarks.dart';
import 'tables/book_typography_overrides.dart';
import 'tables/books.dart';
import 'tables/qa_history.dart';
import 'tables/reading_progress.dart';
import 'tables/settings.dart';
import 'tables/sync_conflicts.dart';
import 'tables/sync_outbox.dart';
import 'tables/typography_profiles.dart';
import 'tables/user_fonts.dart';

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
    UserFonts,
    SyncOutbox,
    AiSummaries,
    SyncConflicts,
    BookPassages,
    QaHistory,
    Bookmarks,
  ],
  daos: [
    BooksDao,
    BookTagsDao,
    BookNotesDao,
    AnnotationsDao,
    ReadingProgressDao,
    TypographyDao,
    SettingsDao,
    UserFontsDao,
    SyncOutboxDao,
    AiSummariesDao,
    SyncConflictsDao,
    BookPassagesDao,
    QaHistoryDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(createDatabaseConnection());

  AppDatabase.forTesting() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 10;

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
        // schema v4 起带 annotations_fts 全文检索虚表 + 同步触发器。
        // fresh install 表为空，无需回填，触发器立即生效。
        await _createFts5(m);
        await m.database.customStatement(
          'CREATE INDEX IF NOT EXISTS idx_sync_outbox_pushed_at ON sync_outbox(pushed_at)',
        );
        // schema v7 起带 ai_summaries 命中索引（缓存查找）
        await m.database.customStatement(
          'CREATE INDEX IF NOT EXISTS idx_ai_summaries_lookup '
          'ON ai_summaries(book_id, mode, source_hash, prompt_version)',
        );
        // schema v8 起带 sync_conflicts 索引（按 detected_at DESC 滚动查询）
        await m.database.customStatement(
          'CREATE INDEX IF NOT EXISTS idx_sync_conflicts_detected_at '
          'ON sync_conflicts(detected_at DESC)',
        );
        // schema v9: book_passages + qa_history + FTS5
        await _createBookPassagesFts5(m);
        await m.database.customStatement(
          'CREATE INDEX IF NOT EXISTS idx_book_passages_lookup '
          'ON book_passages(book_id, chapter_index)',
        );
        await m.database.customStatement(
          'CREATE INDEX IF NOT EXISTS idx_qa_history_book '
          'ON qa_history(book_id, created_at DESC)',
        );
        // schema v10: bookmarks + per-book lookup index
        await m.database.customStatement(
          'CREATE INDEX IF NOT EXISTS idx_bookmarks_book '
          'ON bookmarks(book_id)',
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
        if (from < 4) {
          // schema v4：annotations FTS5 全文检索 + INSERT/DELETE/UPDATE 同步触发器
          // + 已有数据回填（onUpgrade 时 annotations 表可能已有数据）
          await _createFts5(m);
          await m.database.customStatement('''
            INSERT INTO annotations_fts(rowid, quote, note, tags)
            SELECT rowid, quote, note, tags FROM annotations
          ''');
        }
        if (from < 5) {
          // schema v5：用户自定义字体表
          await m.createTable(userFonts);
        }
        if (from < 6) {
          // schema v6：sync outbox
          await m.createTable(syncOutbox);
          await m.database.customStatement(
            'CREATE INDEX IF NOT EXISTS idx_sync_outbox_pushed_at ON sync_outbox(pushed_at)',
          );
        }
        if (from < 7) {
          // schema v7：AI guide summary cache
          await m.createTable(aiSummaries);
          await m.database.customStatement(
            'CREATE INDEX IF NOT EXISTS idx_ai_summaries_lookup '
            'ON ai_summaries(book_id, mode, source_hash, prompt_version)',
          );
        }
        if (from < 8) {
          // schema v8：sync conflicts log
          await m.createTable(syncConflicts);
          await m.database.customStatement(
            'CREATE INDEX IF NOT EXISTS idx_sync_conflicts_detected_at '
            'ON sync_conflicts(detected_at DESC)',
          );
        }
        if (from < 9) {
          // schema v9: AI batch preprocess + Q&A history
          await m.createTable(bookPassages);
          await m.createTable(qaHistory);
          await _createBookPassagesFts5(m);
          await m.database.customStatement(
            'CREATE INDEX IF NOT EXISTS idx_book_passages_lookup '
            'ON book_passages(book_id, chapter_index)',
          );
          await m.database.customStatement(
            'CREATE INDEX IF NOT EXISTS idx_qa_history_book '
            'ON qa_history(book_id, created_at DESC)',
          );
        }
        if (from < 10) {
          // schema v10: bookmarks
          await m.createTable(bookmarks);
          await m.database.customStatement(
            'CREATE INDEX IF NOT EXISTS idx_bookmarks_book '
            'ON bookmarks(book_id)',
          );
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON;');
      },
    );
  }

  /// 创建 annotations 的 FTS5 外部内容虚表 + 3 个同步触发器。
  ///
  /// 虚表通过 content='annotations' + content_rowid='rowid' 关联到原表，
  /// 不重复存储原数据。'delete' 特殊语句是 FTS5 的删除语法（不是 SQL DELETE）。
  /// 回填由调用方在 onUpgrade 时执行；fresh install 表空无需回填。
  Future<void> _createFts5(Migrator m) async {
    await m.database.customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS annotations_fts USING fts5(
        quote, note, tags, content='annotations', content_rowid='rowid'
      )
    ''');
    await m.database.customStatement('''
      CREATE TRIGGER IF NOT EXISTS annotations_ai AFTER INSERT ON annotations BEGIN
        INSERT INTO annotations_fts(rowid, quote, note, tags)
        VALUES (new.rowid, new.quote, new.note, new.tags);
      END
    ''');
    await m.database.customStatement('''
      CREATE TRIGGER IF NOT EXISTS annotations_ad AFTER DELETE ON annotations BEGIN
        INSERT INTO annotations_fts(annotations_fts, rowid, quote, note, tags)
        VALUES ('delete', old.rowid, old.quote, old.note, old.tags);
      END
    ''');
    await m.database.customStatement('''
      CREATE TRIGGER IF NOT EXISTS annotations_au AFTER UPDATE ON annotations BEGIN
        INSERT INTO annotations_fts(annotations_fts, rowid, quote, note, tags)
        VALUES ('delete', old.rowid, old.quote, old.note, old.tags);
        INSERT INTO annotations_fts(rowid, quote, note, tags)
        VALUES (new.rowid, new.quote, new.note, new.tags);
      END
    ''');
  }

  /// Create book_passages FTS5 external-content virtual table + 3 sync
  /// triggers. Same pattern as annotations_fts. Default retrieval path
  /// uses substring LIKE (CJK-friendly); FTS5 table reserved for future
  /// relevance-ranked retrieval.
  Future<void> _createBookPassagesFts5(Migrator m) async {
    await m.database.customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS book_passages_fts USING fts5(
        content_text, content='book_passages', content_rowid='rowid'
      )
    ''');
    await m.database.customStatement('''
      CREATE TRIGGER IF NOT EXISTS book_passages_ai AFTER INSERT ON book_passages BEGIN
        INSERT INTO book_passages_fts(rowid, content_text)
        VALUES (new.rowid, new.content_text);
      END
    ''');
    await m.database.customStatement('''
      CREATE TRIGGER IF NOT EXISTS book_passages_ad AFTER DELETE ON book_passages BEGIN
        INSERT INTO book_passages_fts(book_passages_fts, rowid, content_text)
        VALUES ('delete', old.rowid, old.content_text);
      END
    ''');
    await m.database.customStatement('''
      CREATE TRIGGER IF NOT EXISTS book_passages_au AFTER UPDATE ON book_passages BEGIN
        INSERT INTO book_passages_fts(book_passages_fts, rowid, content_text)
        VALUES ('delete', old.rowid, old.content_text);
        INSERT INTO book_passages_fts(rowid, content_text)
        VALUES (new.rowid, new.content_text);
      END
    ''');
  }
}
