import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart' as db;
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/repositories/local_book_repository.dart';

import '../../helpers/drift_test_helper.dart';

void main() {
  late db.AppDatabase database;
  late LocalBookRepository repo;

  setUp(() {
    database = createTestDatabase();
    repo = LocalBookRepository(database);
  });

  tearDown(() async => database.close());

  test('getAll returns empty initially', () async {
    expect(await repo.getAll(), isEmpty);
  });

  test('save and getById', () async {
    final book = Book(
      id: 'b1',
      title: '与天为敌',
      author: '伯恩斯坦',
      format: BookFormat.epub,
      filePath: '/lib/abc.epub',
      fileHash: 'abc',
      fileSizeBytes: 1024,
      coverPath: null,
      addedAt: DateTime(2026, 6, 24),
      lastReadAt: null,
    );
    await repo.save(book);
    final found = await repo.getById('b1');
    expect(found?.title, '与天为敌');
    expect(found?.format, BookFormat.epub);
  });

  test('findByHash returns book', () async {
    final book = Book(
      id: 'b1',
      title: 't',
      author: null,
      format: BookFormat.pdf,
      filePath: 'p',
      fileHash: 'h1',
      fileSizeBytes: 0,
      coverPath: null,
      addedAt: DateTime(2026, 6, 24),
      lastReadAt: null,
    );
    await repo.save(book);
    expect((await repo.findByHash('h1'))?.id, 'b1');
  });

  test('delete removes book', () async {
    final book = Book(
      id: 'b1',
      title: 't',
      author: null,
      format: BookFormat.epub,
      filePath: 'p',
      fileHash: 'h',
      fileSizeBytes: 0,
      coverPath: null,
      addedAt: DateTime(2026, 6, 24),
      lastReadAt: null,
    );
    await repo.save(book);
    await repo.delete('b1');
    expect(await repo.getAll(), isEmpty);
  });

  test('save updates existing book fields', () async {
    final book = Book(
      id: 'b1',
      title: '旧标题',
      author: null,
      format: BookFormat.epub,
      filePath: '/lib/old.epub',
      fileHash: 'h1',
      fileSizeBytes: 100,
      coverPath: null,
      addedAt: DateTime(2026, 6, 24),
      lastReadAt: null,
    );
    await repo.save(book);

    // 再次 save 同 id，更新 title 与 coverPath
    await repo.save(book.copyWith(
      title: '新标题',
      coverPath: '/covers/x.png',
    ));

    final found = await repo.getById('b1');
    expect(found?.title, '新标题');
    expect(found?.coverPath, '/covers/x.png');
  });
}
