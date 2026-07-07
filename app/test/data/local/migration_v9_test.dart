import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';

import '../../helpers/drift_test_helper.dart';

void main() {
  group('schema v9 migration', () {
    late AppDatabase db;

    setUp(() {
      db = createTestDatabase();
    });

    tearDown(() async => db.close());

    test('schemaVersion is current (≥9)', () {
      // v10 起表仍存在；只校验 v9 引入的内容，不锁定 schemaVersion。
      expect(db.schemaVersion, greaterThanOrEqualTo(9));
    });

    test('book_passages table exists with correct columns', () async {
      final cols = await db.customSelect(
        "PRAGMA table_info('book_passages')",
      ).get();
      final names = cols.map((r) => r.read<String>('name')).toSet();
      expect(names, containsAll(<String>[
        'id',
        'book_id',
        'chapter_index',
        'char_offset',
        'char_length',
        'content_text',
        'token_estimate',
        'created_at',
      ]));
    });

    test('qa_history table is dropped at schema v12 (regression)', () async {
      // v9 引入 qa_history；v12 (M2.7) 用 chat_sessions + chat_messages 替代并 drop 旧表。
      // 详见 database_migration_v12_test.dart 的同名断言。
      final rows = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='qa_history'",
      ).get();
      expect(rows, isEmpty);
    });

    test('book_passages_fts virtual table exists', () async {
      final rows = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='book_passages_fts'",
      ).get();
      expect(rows, hasLength(1));
    });

    test('book_passages_fts sync triggers exist', () async {
      final rows = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='trigger' AND name IN "
        "('book_passages_ai','book_passages_ad','book_passages_au')",
      ).get();
      final names = rows.map((r) => r.read<String>('name')).toSet();
      expect(names, containsAll(<String>[
        'book_passages_ai',
        'book_passages_ad',
        'book_passages_au',
      ]));
    });
  });
}
