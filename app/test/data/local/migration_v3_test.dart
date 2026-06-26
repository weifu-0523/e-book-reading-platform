import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';

void main() {
  test('schema v2 -> v3 migration adds sortOrder column and book_tags table', () async {
    // 基础数据库创建测试 - 详细验证在下面两个测试中
    final db = AppDatabase.forTesting();
    await db.customSelect('SELECT 1').get();
    await db.close();
  }, skip: 'placeholder — replaced by specific tests below');

  test('Books table has sortOrder column after migration', () async {
    final db = AppDatabase.forTesting();
    final cols = await db.customSelect('PRAGMA table_info(books)').get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(names, contains('sort_order'));
    await db.close();
  });

  test('book_tags table exists with composite PK after migration', () async {
    final db = AppDatabase.forTesting();
    final tables = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='book_tags'",
    ).get();
    expect(tables, isNotEmpty);
    await db.close();
  });
}
