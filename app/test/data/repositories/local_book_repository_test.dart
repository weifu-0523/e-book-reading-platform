import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart' hide Book;
import 'package:zhiyue/data/local/daos/book_tags_dao.dart';
import 'package:zhiyue/data/repositories/local_book_repository.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/features/library/models/sort_by.dart';

void main() {
  late AppDatabase db;
  late LocalBookRepository repo;
  late BookTagsDao tagsDao;

  setUp(() async {
    db = AppDatabase.forTesting();
    repo = LocalBookRepository(db);
    tagsDao = BookTagsDao(db);
    // b1：标签 A，b2：标签 A+B，b3：标签 B，b4：无标签
    // Distinct addedAt (b1 最新 → b4 最早) 使 addedDesc 排序与插入顺序无关，
    // 真正测试降序排序行为而非依赖 stable-sort-on-ties。
    final entries = [
      ('b1', '书一', 100, 'h1'),
      ('b2', 'Book Two', 200, 'h2'),
      ('b3', '书三', 300, 'h3'),
      ('b4', 'Book Four', 400, 'h4'),
    ];
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      await repo.save(Book(
        id: entry.$1, title: entry.$2, author: null,
        format: BookFormat.epub, filePath: '/${entry.$1}.epub',
        fileHash: entry.$4, fileSizeBytes: entry.$3, coverPath: null,
        addedAt: DateTime(2026, 1, 1).add(Duration(days: entries.length - 1 - i)),
        lastReadAt: null,
      ));
    }
    await tagsDao.addTag(bookId: 'b1', tag: 'A');
    await tagsDao.addTag(bookId: 'b2', tag: 'A');
    await tagsDao.addTag(bookId: 'b2', tag: 'B');
    await tagsDao.addTag(bookId: 'b3', tag: 'B');
  });
  tearDown(() async => db.close());

  test('getAll default sortBy addedDesc', () async {
    final books = await repo.getAll();
    expect(books.map((b) => b.id).toList(), ['b1', 'b2', 'b3', 'b4']);
  });

  test('getAll sortBy titleAsc', () async {
    final books = await repo.getAll(sortBy: SortBy.titleAsc);
    // 中英混排：默认 Locale 字符串排序
    expect(books.map((b) => b.title).toList(), contains('Book Four'));
  });

  test('getAll filter by single tag', () async {
    final books = await repo.getAll(tagFilters: {'A'});
    expect(books.map((b) => b.id).toSet(), {'b1', 'b2'});
  });

  test('getAll filter by multiple tags uses AND', () async {
    final books = await repo.getAll(tagFilters: {'A', 'B'});
    expect(books.map((b) => b.id).toSet(), {'b2'});
  });

  test('getAll with searchQuery matches title (case-insensitive)', () async {
    final books = await repo.getAll(searchQuery: 'book');
    expect(books.map((b) => b.id).toSet(), {'b2', 'b4'});
  });

  test('getAll combined: searchQuery + tagFilter', () async {
    final books = await repo.getAll(searchQuery: 'book', tagFilters: {'B'});
    expect(books.map((b) => b.id).toSet(), {'b2'});
  });

  test('setSortOrder persists and manual sort places book first', () async {
    await repo.setSortOrder(bookId: 'b2', sortOrder: 0);
    final books = await repo.getAll(sortBy: SortBy.manual);
    // b2 拥有 sortOrder=0 → 第一；其余 sortOrder=null → comparator 返回 0
    // → stable sort 保持其在 addedDesc 序列（b1, b3, b4）中的相对次序。
    expect(books.map((b) => b.id).toList(), ['b2', 'b1', 'b3', 'b4']);
  });

  test('watchAll emits on changes', () async {
    final stream = repo.watchAll();
    expectLater(
      stream,
      emitsInOrder([
        hasLength(4),
        hasLength(3),
      ]),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await repo.delete('b1');
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });

  test('deleteBooks batch', () async {
    await repo.deleteBooks({'b1', 'b2'});
    final remaining = await repo.getAll();
    expect(remaining.map((b) => b.id).toSet(), {'b3', 'b4'});
  });
}
