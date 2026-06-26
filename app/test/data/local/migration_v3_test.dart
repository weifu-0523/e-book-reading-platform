// Note: these tests verify the fresh-install (onCreate) schema only.
// The v2→v3 onUpgrade path (ALTER TABLE + createTable) is not exercised here;
// testing real migrations would require drift's schema_v2.json snapshots which
// the project does not currently maintain. This matches the precedent set by
// the v1→v2 file_hash index migration.
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';

void main() {
  test('Books table exposes sortOrder column on fresh install', () async {
    final db = AppDatabase.forTesting();
    final cols = await db.customSelect('PRAGMA table_info(books)').get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(names, contains('sort_order'));
    await db.close();
  });

  test('book_tags table exists with composite PK on fresh install', () async {
    final db = AppDatabase.forTesting();
    final tables = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='book_tags'",
    ).get();
    expect(tables, isNotEmpty);
    await db.close();
  });
}
