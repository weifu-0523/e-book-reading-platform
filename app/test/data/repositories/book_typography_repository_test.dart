// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:zhiyue/data/local/daos/books_dao.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/repositories/book_typography_repository.dart';

import '../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late BookTypographyRepository repo;

  setUp(() async {
    db = createTestDatabase();
    repo = BookTypographyRepository(db);
    await BooksDao(db).insertOne(
      id: 'b1',
      title: 'Test',
      format: 'epub',
      filePath: '/tmp/x.epub',
      fileHash: 'h',
      fileSizeBytes: 0,
    );
  });
  tearDown(() async => db.close());

  test('getForBook returns null when no override and no default profile', () async {
    final result = await repo.getForBook('b1');
    expect(result, isNull);
  });

  test('saveForBook persists settings; getForBook returns them', () async {
    final s = TypographySettings.defaults().copyWith(fontSize: 24.0);
    await repo.saveForBook('b1', s);
    final loaded = await repo.getForBook('b1');
    expect(loaded, isNotNull);
    expect(loaded!.fontSize, 24.0);
    expect(loaded, s);
  });

  test('saveForBook twice with same bookId upserts (no duplicate rows)', () async {
    final s1 = TypographySettings.defaults().copyWith(fontSize: 20.0);
    final s2 = TypographySettings.defaults().copyWith(fontSize: 22.0);
    await repo.saveForBook('b1', s1);
    await repo.saveForBook('b1', s2);
    final loaded = await repo.getForBook('b1');
    expect(loaded!.fontSize, 22.0);
    final rows = await db.typographyDao.getOverride('b1');
    expect(rows, isNotNull);
  });

  test('getForBook for different bookId returns independent settings', () async {
    await BooksDao(db).insertOne(
      id: 'b2',
      title: 'Other',
      format: 'epub',
      filePath: '/tmp/y.epub',
      fileHash: 'h2',
      fileSizeBytes: 0,
    );
    await repo.saveForBook('b1',
        TypographySettings.defaults().copyWith(fontSize: 18.0));
    await repo.saveForBook('b2',
        TypographySettings.defaults().copyWith(fontSize: 28.0));
    expect((await repo.getForBook('b1'))!.fontSize, 18.0);
    expect((await repo.getForBook('b2'))!.fontSize, 28.0);
  });

  test('saveForBook survives JSON round-trip for all fields', () async {
    final original = TypographySettings.defaults().copyWith(
      fontSize: 19.5,
      lineHeight: 2.0,
      theme: ReadingTheme.sepia,
      pageMargin: PageMargin.extraWide,
      paragraphIndentEm: 3.0,
      paragraphIndentEnabled: false,
    );
    await repo.saveForBook('b1', original);
    final loaded = await repo.getForBook('b1');
    expect(loaded, original);
  });
}
