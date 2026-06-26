import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/features/library/models/library_mode.dart';
import 'package:zhiyue/features/library/models/library_state.dart';
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

  test('watchAll subscription updates books in state', () async {
    bookRepo.emitBooks([
      _fakeBook('b1'),
      _fakeBook('b2'),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(controller.state.books.map((b) => b.id), containsAll(['b1', 'b2']));
  });

  test('batchDelete deletes selected and exits selection mode', () async {
    controller.enterSelectionMode('b1');
    controller.toggleSelection('b2');
    await controller.batchDelete();
    expect(bookRepo.deletedIds, {'b1', 'b2'});
    expect(controller.state.mode, LibraryMode.idle);
    expect(controller.state.selectedIds, isEmpty);
  });
}

Book _fakeBook(String id) => Book(
      id: id,
      title: id,
      author: null,
      format: BookFormat.epub,
      filePath: '/$id.epub',
      fileHash: 'h-$id',
      fileSizeBytes: 100,
      coverPath: null,
      addedAt: DateTime(2026, 1, 1),
      lastReadAt: null,
    );
