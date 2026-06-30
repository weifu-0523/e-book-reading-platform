import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/features/library/models/library_mode.dart';
import 'package:zhiyue/features/library/models/sort_by.dart';
import 'package:zhiyue/features/library/models/view_mode.dart';
import 'package:zhiyue/features/library/providers/library_controller.dart';

import '../../../fakes/fake_book_repository.dart';
import '../../../fakes/fake_book_tags_lookup.dart';
import '../../../fakes/fake_settings_repository.dart';

void main() {
  late LibraryController controller;
  late FakeBookRepository bookRepo;
  late FakeBookTagsLookup tagsLookup;
  late FakeSettingsRepository settings;

  setUp(() {
    bookRepo = FakeBookRepository();
    tagsLookup = FakeBookTagsLookup();
    settings = FakeSettingsRepository();
    controller = LibraryController(
      bookRepository: bookRepo,
      bookTagsLookup: tagsLookup,
      settingsRepository: settings,
    );
  });
  tearDown(() => controller.dispose());

  test('initial state is defaults', () {
    expect(controller.state.mode, LibraryMode.idle);
    expect(controller.state.viewMode, ViewMode.grid);
  });

  test('setViewMode updates state and persists', () async {
    await controller.setViewMode(ViewMode.list);
    expect(controller.state.viewMode, ViewMode.list);
  });

  test('setSortBy updates state', () async {
    await controller.setSortBy(SortBy.titleAsc);
    expect(controller.state.sortBy, SortBy.titleAsc);
  });

  test('enterSelectionMode sets mode and selects initial book', () {
    controller.enterSelectionMode('b1');
    expect(controller.state.mode, LibraryMode.selecting);
    expect(controller.state.selectedIds, {'b1'});
  });

  test('toggleSelection toggles id in selectedIds', () {
    controller.enterSelectionMode('b1');
    controller.toggleSelection('b2');
    expect(controller.state.selectedIds, {'b1', 'b2'});
    controller.toggleSelection('b1');
    expect(controller.state.selectedIds, {'b2'});
  });

  test('exitSelectionMode clears selection and returns to idle', () {
    controller.enterSelectionMode('b1');
    controller.exitSelectionMode();
    expect(controller.state.mode, LibraryMode.idle);
    expect(controller.state.selectedIds, isEmpty);
  });

  test('setSearchQuery updates query (debounced)', () async {
    await controller.setSearchQuery('test');
    // 等待 debounce timer
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(controller.state.searchQuery, 'test');
  });

  test('toggleTagFilter adds and removes', () async {
    await controller.toggleTagFilter('A');
    expect(controller.state.activeTagFilters, {'A'});
    await controller.toggleTagFilter('A');
    expect(controller.state.activeTagFilters, isEmpty);
  });

  test('toggleTagFilter filters books end-to-end through state', () async {
    // b1: {fiction}, b2: {history}, b3: {fiction, history}
    bookRepo.emitBooks([
      _fakeBook('b1', title: 'B1'),
      _fakeBook('b2', title: 'B2'),
      _fakeBook('b3', title: 'B3'),
    ]);
    bookRepo.setTagsForBook('b1', {'fiction'});
    bookRepo.setTagsForBook('b2', {'history'});
    bookRepo.setTagsForBook('b3', {'fiction', 'history'});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // 初始：全部三本
    expect(controller.state.books.map((b) => b.id), containsAll(['b1', 'b2', 'b3']));
    expect(controller.state.books.map((b) => b.id).length, 3);

    // 打开 fiction 标签过滤：保留 b1 和 b3（OR 语义），剔除 b2
    await controller.toggleTagFilter('fiction');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(controller.state.activeTagFilters, {'fiction'});
    expect(controller.state.books.map((b) => b.id).toSet(), {'b1', 'b3'});

    // 再次点击关闭 fiction 过滤：恢复全部三本
    await controller.toggleTagFilter('fiction');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(controller.state.activeTagFilters, isEmpty);
    expect(controller.state.books.map((b) => b.id).toSet(),
        {'b1', 'b2', 'b3'});
  });

  test('watchAll subscription updates books in state', () async {
    bookRepo.emitBooks([
      _fakeBook('b1'),
      _fakeBook('b2'),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(controller.state.books.map((b) => b.id), containsAll(['b1', 'b2']));
  });

  test('setSearchQuery filters books end-to-end through state', () async {
    bookRepo.emitBooks([
      _fakeBook('alpha', title: 'Alpha'),
      _fakeBook('beta', title: 'Beta'),
      _fakeBook('gamma', title: 'Gamma'),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // 初始：全部三本
    expect(controller.state.books.map((b) => b.id), containsAll(['alpha', 'beta', 'gamma']));

    await controller.setSearchQuery('ga'); // 仅匹配 Gamma
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(controller.state.searchQuery, 'ga');
    expect(controller.state.books.map((b) => b.id), {'gamma'});

    await controller.setSearchQuery(''); // 清空：恢复全部
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(controller.state.books.map((b) => b.id),
        containsAll(['alpha', 'beta', 'gamma']));
  });

  test('setSortBy re-subscribes and re-orders books', () async {
    // LibraryState 默认 sortBy = recentlyRead；无 lastReadAt 时按 title 升序兜底。
    // 给三本书不同的 addedAt，让 addedDesc 与默认顺序明显不同。
    final earlier = DateTime(2026, 1, 1);
    final middle = DateTime(2026, 2, 1);
    final later = DateTime(2026, 3, 1);
    bookRepo.emitBooks([
      Book(
        id: 'z-added-middle',
        title: 'Zzz',
        author: null,
        format: BookFormat.epub,
        filePath: '/z.epub',
        fileHash: 'hz',
        fileSizeBytes: 1,
        coverPath: null,
        addedAt: middle,
        lastReadAt: null,
      ),
      Book(
        id: 'a-added-later',
        title: 'Aaa',
        author: null,
        format: BookFormat.epub,
        filePath: '/a.epub',
        fileHash: 'ha',
        fileSizeBytes: 1,
        coverPath: null,
        addedAt: later,
        lastReadAt: null,
      ),
      Book(
        id: 'm-added-earlier',
        title: 'Mmm',
        author: null,
        format: BookFormat.epub,
        filePath: '/m.epub',
        fileHash: 'hm',
        fileSizeBytes: 1,
        coverPath: null,
        addedAt: earlier,
        lastReadAt: null,
      ),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // 初始 recentlyRead（无 lastReadAt 时按 title 升序）：A → M → Z
    expect(controller.state.books.map((b) => b.id).toList(),
        ['a-added-later', 'm-added-earlier', 'z-added-middle']);

    await controller.setSortBy(SortBy.addedDesc); // 切到 addedAt 倒序：later → middle → earlier
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(controller.state.sortBy, SortBy.addedDesc);
    expect(controller.state.books.map((b) => b.id).toList(),
        ['a-added-later', 'z-added-middle', 'm-added-earlier']);
  });

  test('batchDelete deletes selected and exits selection mode', () async {
    controller.enterSelectionMode('b1');
    controller.toggleSelection('b2');
    await controller.batchDelete();
    expect(bookRepo.deletedIds, {'b1', 'b2'});
    expect(controller.state.mode, LibraryMode.idle);
    expect(controller.state.selectedIds, isEmpty);
  });

  test('selectAll replaces selectedIds with given ids', () {
    controller.enterSelectionMode('b1');
    controller.selectAll(['b1', 'b2', 'b3']);
    expect(controller.state.selectedIds, {'b1', 'b2', 'b3'});
  });
}

Book _fakeBook(String id, {String? title}) => Book(
      id: id,
      title: title ?? id,
      author: null,
      format: BookFormat.epub,
      filePath: '/$id.epub',
      fileHash: 'h-$id',
      fileSizeBytes: 100,
      coverPath: null,
      addedAt: DateTime(2026, 1, 1),
      lastReadAt: null,
    );
